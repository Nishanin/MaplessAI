# MapLess AI — API Contract Specification

## 1. Overview & Protocol Standards

The MapLess AI backend is built with Node.js/Express and communicates with the Flutter mobile application over HTTP/REST using JSON payloads.

- **Base URL**: `http://localhost:3000`
- **Standard Port**: `3000` (Frozen)
- **API Version**: `v1`
- **Content-Type**: `application/json`

---

## 2. Core Service Communication Flow

```
Flutter (Mobile App)
      │
      │ REST (HTTP JSON)
      ▼
Node.js / Express Backend (Port 3000)
      │
      ▼
PostgreSQL Database
```

### Flow 1: Navigation Computation
```
Flutter UI (Nishant)
      │ (POST /api/v1/navigation/route)
      ▼
Navigation Router (Pratik)
      │ (Validates NavigationRequest against navigation-request.schema.json)
      ▼
Spatial Graph Engine (Pratik)
      │ (Executes A* / Dijkstra over in-memory / DB topology)
      ▼
Navigation Response (Pratik)
      │ (Validates NavigationResponse against navigation-response.schema.json)
      ▼
Flutter Navigation Screen (Rendered by Nishant)
```

### Flow 2: Conversational AI Navigation
```
User Natural Language ("Find nearest quiet study room")
      │ (POST /api/v1/ai/query)
      ▼
AI Service / SLM (Surabhi)
      │ (Extracts intent: "FIND_NEAREST", entities: ["study room"], constraints: {"category": "facility"})
      ▼
Validated Structured Query (Surabhi)
      │ (NO direct SQL allowed)
      ▼
Semantic Knowledge Graph (Surabhi)
      │ (Matches candidate node IDs: ["library"])
      ▼
Spatial Graph Engine (Pratik)
      │ (Calculates route to candidate node)
      ▼
Flutter UI Displays Conversational Response & Route (Nishant)
```

---

## 3. Global Endpoints

### Health Check
- **Method**: `GET`
- **Path**: `/health`
- **Description**: Lightweight liveness and readiness probe for uptime monitors and clients.
- **Success Response (200 OK)**:
```json
{
  "service": "mapless-backend",
  "status": "ok"
}
```

---

## 4. Feature Namespaces & Endpoints

### A. Mapping & Infrastructure (`/api/v1/mapping`) — Owner: Nishant

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/api/v1/mapping/buildings` | List all registered buildings |
| `GET` | `/api/v1/mapping/buildings/:buildingId/floors/:floorId/graph` | Fetch complete node & edge graph for a specific floor |
| `POST` | `/api/v1/mapping/buildings/:buildingId/floors/:floorId/nodes` | Create or update a node (validates against `node.schema.json`) |
| `POST` | `/api/v1/mapping/buildings/:buildingId/floors/:floorId/edges` | Create or update an edge (validates against `edge.schema.json`) |

#### Example: `POST /api/v1/mapping/buildings/vit-ce/floors/floor-1/nodes`
Request Body:
```json
{
  "id": "lab-101",
  "name": "Lab 101",
  "category": "laboratory",
  "floorId": "floor-1",
  "x": 25.0,
  "y": 30.0,
  "accessible": true,
  "metadata": {
    "capacity": 45
  }
}
```

---

### B. Spatial Graph & Navigation (`/api/v1/navigation`) — Owner: Pratik

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `POST` | `/api/v1/navigation/route` | Compute optimal path between start node and destination node |

#### Request Body (`contracts/navigation-request.schema.json`):
```json
{
  "buildingId": "vit-ce",
  "startNodeId": "reception",
  "destinationNodeId": "lab-101",
  "preferences": {
    "accessible": false,
    "avoidStairs": false,
    "avoidBlockedEdges": true
  }
}
```

#### Response Body (`contracts/navigation-response.schema.json`):
```json
{
  "success": true,
  "pathNodeIds": ["reception", "corridor", "lab-101"],
  "edgeIds": ["edge-reception-corridor", "edge-corridor-lab101"],
  "totalDistance": 30.0,
  "estimatedTimeSeconds": 25.0,
  "turnInstructions": [
    {
      "step": 1,
      "instruction": "Walk 15 meters East to Main Corridor",
      "distance": 15.0,
      "bearing": 90.0,
      "nodeId": "corridor"
    },
    {
      "step": 2,
      "instruction": "Turn North and walk 15 meters to Lab 101",
      "distance": 15.0,
      "bearing": 0.0,
      "nodeId": "lab-101"
    }
  ],
  "floorTransitions": []
}
```

---

### C. Semantic AI & Natural Language Query (`/api/v1/ai`) — Owner: Surabhi

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `POST` | `/api/v1/ai/query` | Parse natural-language intent and resolve candidate nodes |

#### Request Body (`contracts/ai-query.schema.json`):
```json
{
  "text": "Find the nearest accessible laboratory",
  "buildingId": "vit-ce",
  "userContext": {
    "currentNodeId": "reception",
    "accessible": true,
    "currentFloorId": "floor-1"
  }
}
```

#### Response Body (`contracts/ai-response.schema.json`):
```json
{
  "intent": "FIND_NEAREST",
  "entities": [
    { "type": "category", "value": "laboratory" }
  ],
  "constraints": {
    "category": "laboratory",
    "accessible": true
  },
  "targetNodeId": "lab-101",
  "confidence": 0.95,
  "responseMessage": "Found Lab 101 on First Floor, which is wheelchair accessible."
}
```

---

### D. Map Versioning & Snapshots (`/api/v1/versioning`) — Owner: Piyush

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `POST` | `/api/v1/versioning/buildings/:buildingId/snapshots` | Create an immutable snapshot version of the building's graph |
| `GET` | `/api/v1/versioning/buildings/:buildingId/history` | Retrieve version history list with audit metadata |
| `POST` | `/api/v1/versioning/buildings/:buildingId/compare` | Compare two version snapshots and generate graph diff |
| `POST` | `/api/v1/versioning/buildings/:buildingId/rollback` | Rollback active graph to a previous snapshot |

---

## 5. Standard Error Handling

All backend APIs return uniform JSON error responses:

```json
{
  "error": {
    "code": "RESOURCE_NOT_FOUND",
    "message": "Node with id 'lab-999' was not found in building 'vit-ce'",
    "timestamp": "2026-09-07T08:15:00.000Z",
    "details": []
  }
}
```

Common status codes:
- `200 OK`: Request succeeded.
- `201 Created`: Resource created successfully.
- `400 Bad Request`: Payload validation failed against JSON schema.
- `404 Not Found`: Building, floor, or node not found.
- `500 Internal Server Error`: Unhandled server exception.
