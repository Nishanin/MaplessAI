# Semantic AI to Spatial Engine Integration Boundary

This document defines the architectural ownership and handoff contract between the **Semantic AI layer** (Owner: Surabhi) and the **Spatial Routing Engine** (Owner: Pratik) in MapLess AI.

---

## 1. Architectural Responsibility Overview

```text
Semantic AI layer (Surabhi):
Natural language → semantic interpretation → semantic resolution → NavigationRequest

Spatial layer (Pratik):
NavigationRequest → physical route calculation (A* / Dijkstra) → route output
```

### Semantic AI Layer (Surabhi)
* Translates unstructured natural language into structured extraction (intent, entities, constraints).
* Performs strict JSON schema, prompt-injection, and semantic consistency validation.
* Generates read-only graph queries conforming to the whitelist.
* Resolves semantic constraints against in-memory building metadata in `SemanticGraphService`.
* Determines resolution states (`RESOLVED`, `AMBIGUOUS`, `NOT_FOUND`, `FALLBACK`).
* Assembles and validates the `NavigationRequest` handoff object **only** when a valid single destination is identified for a navigation intent (`NAVIGATE_TO`, `FIND_NEAREST`, `EMERGENCY_EXIT`).
* **Strict Non-Responsibilities**: The semantic AI layer **never** computes physical distances, turns, coordinates, graphs, or routes. It never executes arbitrary SQL or mutates graph data.

### Spatial Layer (Pratik)
* Consumes the validated `NavigationRequest` via `NavigationController` and pathfinding services.
* Accesses physical spatial graph topology (nodes, edges, weights, floor transitions).
* Executes shortest-path and obstacle-avoidance algorithms (A*, Dijkstra).
* Computes turn-by-turn navigation instructions, total distance, and estimated travel time.
* **Strict Non-Responsibilities**: The spatial engine does not perform natural language processing, entity extraction, or direct model interpretation.

---

## 2. Handoff Contract: `NavigationRequest`

Defined in [`contracts/navigation-request.schema.json`](file:///c:/Users/surab/OneDrive/Documents/SEM%205/EDI/MaplessAI/contracts/navigation-request.schema.json):

```json
{
  "buildingId": "vit-ce",
  "startNodeId": "reception",
  "destinationNodeId": "lab-101",
  "intent": "NAVIGATE_TO",
  "operation": "RESOLVE_DESTINATION",
  "semanticTarget": "Artificial Intelligence Lab",
  "resolvedTarget": {
    "nodeId": "lab-101",
    "name": "Artificial Intelligence Lab",
    "category": "laboratory",
    "floorNumber": 1,
    "floorName": "Floor 1",
    "buildingId": "vit-ce",
    "accessible": true,
    "department": "Computer Engineering"
  },
  "constraints": {
    "category": "laboratory",
    "tag": "ai"
  },
  "preferences": {
    "accessible": true,
    "avoidStairs": true,
    "avoidBlockedEdges": true,
    "emergencyMode": false
  },
  "requiresNearest": false,
  "requiresRoute": true,
  "confidence": 0.90,
  "ambiguity": false
}
```

### Rationale for Handoff Fields
1. **`buildingId`**: Scopes the coordinate and spatial graph system for the building.
2. **`startNodeId`**: Origin node ID for route start (provided by visitor context or null if not yet selected).
3. **`destinationNodeId`**: Resolved destination node ID. Derived **only** from `SemanticGraphService`, never the SLM.
4. **`intent`**: Communicates user goal (`NAVIGATE_TO`, `FIND_NEAREST`, `EMERGENCY_EXIT`).
5. **`operation`**: Structured graph query operation identifier.
6. **`semanticTarget`**: Human-readable target noun for turn instructions and UI banners.
7. **`resolvedTarget`**: Full node metadata (floor number, name, category, accessibility) for floor transition calculations.
8. **`constraints`**: Derived semantic constraints (floor, department, capacity).
9. **`preferences`**: Routing flags consumed by A*/Dijkstra (`accessible`, `avoidStairs`, `avoidBlockedEdges`, `emergencyMode`).
10. **`requiresNearest`**: Signals if spatial engine should evaluate closest node when starting position is localized.
11. **`requiresRoute`**: Explicit routing requirement flag.
12. **`confidence`**: Preserved interpretation confidence.
13. **`ambiguity`**: Guaranteed `false` for valid handoff.

---

## 3. Resolution States & Routing Rules

| Resolution State | Description | Produces `NavigationRequest`? | Spatial Routing Invoked? |
|---|---|:---:|:---:|
| **`RESOLVED`** | Exactly one candidate satisfies all semantic constraints | **Yes** (if navigation intent) | **Yes** |
| **`AMBIGUOUS`** | Multiple candidates match constraints | **No** | **No** |
| **`NOT_FOUND`** | Zero candidates match constraints | **No** | **No** |
| **`FALLBACK`** | Query was unsafe, off-topic, or uninterpretable | **No** | **No** |

### Non-Navigation Intents
For informational queries and pure location lookups:
* `LOCATE_ROOM`: Semantic lookup only $\rightarrow$ `navigationRequest: null` $\rightarrow$ no routing.
* `QUERY_INFO`: Facility/amenity lookup only $\rightarrow$ `navigationRequest: null` $\rightarrow$ no routing.
