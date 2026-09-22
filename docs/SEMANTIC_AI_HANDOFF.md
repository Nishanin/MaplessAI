# Semantic AI to Spatial Engine Integration Handoff Document

This document serves as the official integration contract and handoff specification between the **Semantic AI Subsystem (Surabhi)** and the downstream **Spatial Routing Subsystem (Pratik)** in MapLess AI.

---

## 1. Subsystem Responsibilities & Separation of Concerns

### A. Semantic AI Subsystem (Owner: Surabhi)
- **Natural Language Understanding:** Interprets user text into structured intents, entities, and constraints.
- **Provider Abstraction & Validation:** Executes local SLM or deterministic query extraction, scans for prompt/SQL/script injections, and validates JSON schemas.
- **Candidate Resolution:** Resolves semantic criteria deterministically against the in-memory Semantic Knowledge Graph (SKG).
- **Ambiguity & Fallback Handling:** Defensively detects contradictory constraints or multi-candidate matches without guessing.
- **Handoff Packaging:** Assembles and strictly validates the `NavigationRequest` object for spatial consumption.
- **Explicit Boundary:** **Semantic AI does NOT compute physical routes, distances, turns, waypoints, or graph coordinates.**

### B. Spatial Routing Subsystem (Owner: Pratik)
- **Graph Pathfinding:** Consumes `NavigationRequest` and executes shortest-path algorithms (A*, Dijkstra) on the physical spatial graph.
- **Turn-by-Turn Generation:** Translates edge traversals into human-navigable heading instructions and distances.
- **Positioning & Sensor Fusion:** Correlates real-time visitor coordinates with spatial graph nodes.
- **Rendering:** Paints routes and waypoints onto the Flutter mobile canvas.

---

## 2. NavigationRequest Contract Overview

Schema Location: [`contracts/navigation-request.schema.json`](file:///c:/Users/surab/OneDrive/Documents/SEM%205/EDI/MaplessAI/contracts/navigation-request.schema.json)

The `NavigationRequest` object is the single, frozen handoff data contract passed from the Semantic AI controller to the downstream spatial engine.

### Top-Level Properties

| Field | Type | Description |
| :--- | :--- | :--- |
| `buildingId` | `string` (required) | Building identifier (e.g. `'vit-ce'`) |
| `destinationNodeId` | `string` (required) | Target graph node ID derived exclusively from SKG resolution |
| `startNodeId` | `string \| null` | Visitor origin node ID (from user context if supplied) |
| `intent` | `string` | Recognized navigation intent (`NAVIGATE_TO`, `FIND_NEAREST`, `EMERGENCY_EXIT`) |
| `operation` | `string` | Graph query operation (`RESOLVE_DESTINATION`, `FIND_NEAREST_TARGET`, `RESOLVE_EMERGENCY_EXIT`) |
| `semanticTarget` | `string` | Resolved entity name, alias, or category (e.g. `'Lab 101'`) |
| `resolvedTarget` | `object` | Metadata of destination (`nodeId`, `name`, `category`, `floorNumber`, `floorName`, `accessible`, `department`) |
| `constraints` | `object` | Satisfied semantic constraints (e.g. `{ category: 'laboratory', floor: 1 }`) |
| `preferences` | `object` | Routing flags: `{ accessible: boolean, avoidStairs: boolean, avoidBlockedEdges: boolean, emergencyMode: boolean }` |
| `requiresNearest` | `boolean` | `true` for `FIND_NEAREST` and `EMERGENCY_EXIT`; `false` for direct destination navigation |
| `requiresRoute` | `boolean` | Always `true` when a `NavigationRequest` is present |
| `confidence` | `number` | Confidence score $\in [0.5, 1.0]$ |
| `ambiguity` | `boolean` | Always `false` on emitted `NavigationRequest` |

---

## 3. Resolution States & Handoff Eligibility

| Resolution State | Meaning | `targetNodeId` in API Response | `navigationRequest` Emitted? |
| :--- | :--- | :---: | :---: |
| `RESOLVED` | Exactly 1 matching node resolved in SKG | Candidate Node ID | **YES** (for navigation intents only) |
| `AMBIGUOUS` | $\ge 2$ matching nodes, or missing destination info | `null` | **NEVER (`null`)** |
| `NOT_FOUND` | Valid criteria, but 0 matching nodes in graph | `null` | **NEVER (`null`)** |
| `FALLBACK` | Off-topic, contradictory constraints, or security violation | `null` | **NEVER (`null`)** |

### Intents That Can Produce a `NavigationRequest`:
1. `NAVIGATE_TO`: Direct navigation to an explicit room, alias, or facility.
2. `FIND_NEAREST`: Nearest amenity, elevator, or service search (`requiresNearest: true`).
3. `EMERGENCY_EXIT`: Evacuation to emergency exits (`emergencyMode: true`, `requiresNearest: true`).

### Intents That Must NEVER Produce a `NavigationRequest`:
1. `LOCATE_ROOM`: Location informational lookup without navigation command (returns location info, `navigationRequest: null`).
2. `QUERY_INFO`: Facility hours, WiFi, or amenity inquiry (`navigationRequest: null`).
3. `FALLBACK`: Unrecognized or unhandled query (`navigationRequest: null`).

---

## 4. How `destinationNodeId` Is Obtained

```text
User Text: "Take me to Lab 101"
              │
              ▼
   [SLM Provider / Extractor] ──► Extracted constraints: { name: "Lab 101" }
              │                  (SLM is strictly FORBIDDEN from emitting node IDs)
              ▼
   [Structured Graph Query]  ──► Filters: { name: "Lab 101" }
              │
              ▼
   [Semantic Knowledge Graph] ──► Candidate resolution in test_data/vit_floor_1.json
              │                  Matches node: { id: "lab-101", name: "Lab 101", ... }
              ▼
   [NavigationRequest]       ──► destinationNodeId = "lab-101" (derived purely from SKG)
```

**Security Rule:** `destinationNodeId` originates **exclusively** from the Semantic Knowledge Graph candidate resolution. If an adversarial user or model outputs a `targetNodeId` or `nodeId` in provider extraction, it is rejected by validation and demoted to fallback.

---

## 5. Confidence Propagation & Monotonicity

Confidence values decay monotonically across processing stages:

$$\text{Final Response Confidence} \le \text{Graph Query Confidence} \le \text{Provider Confidence}$$

- **Threshold Gate:** If confidence $< 0.50$, candidate resolution is aborted, `NavigationRequest` is suppressed (`null`), and the API returns a controlled fallback.
- **Ambiguity Cap:** Ambiguous resolutions cap confidence at $\min(\text{conf}, 0.50)$.
- **Zero-Match Floor:** Zero matches immediately force confidence to `0.0`.

---

## 6. Failure & Fallback Behavior

When input, model inference, or graph resolution fails, the system fails safely:
1. **Model Crash / Timeout:** Handled via internal `try/catch`, returning an HTTP 200 `FALLBACK` response (`"AI extraction service temporarily unavailable."`) with `confidence: 0.0`. No internal URLs, stack traces, or credentials leak.
2. **Graph Exception:** Handled via internal `try/catch`, returning HTTP 200 `FALLBACK`.
3. **Contradictory Constraints:** Queries like *"floor 1 and floor 2"* or *"accessible entrance stairs only"* are proactively detected, returning `FALLBACK` with `ambiguity: true`.
4. **No Synthetic Routing:** Under no circumstance does a failure state invent a nearest node or emit a partial `NavigationRequest`.

---

## 7. Concrete Examples

### A. Example Valid `NavigationRequest`
Query: `"Navigate to Lab 101"` (with user at reception)

```json
{
  "buildingId": "vit-ce",
  "startNodeId": "reception",
  "destinationNodeId": "lab-101",
  "intent": "NAVIGATE_TO",
  "operation": "RESOLVE_DESTINATION",
  "semanticTarget": "Lab 101",
  "resolvedTarget": {
    "nodeId": "lab-101",
    "name": "Lab 101",
    "category": "laboratory",
    "floorNumber": 1,
    "floorName": "First Floor",
    "buildingId": "vit-ce",
    "accessible": true,
    "department": "Computer Engineering"
  },
  "constraints": {
    "name": "Lab 101"
  },
  "preferences": {
    "accessible": false,
    "avoidStairs": false,
    "avoidBlockedEdges": true,
    "emergencyMode": false
  },
  "requiresNearest": false,
  "requiresRoute": true,
  "confidence": 0.9,
  "ambiguity": false
}
```

### B. Example Ineligible Request (Lookup Only)
Query: `"Where is Lab 101?"`

API Response payload:
```json
{
  "intent": "LOCATE_ROOM",
  "entities": [
    { "type": "room_name", "value": "Lab 101" }
  ],
  "constraints": {
    "name": "Lab 101"
  },
  "targetNodeId": "lab-101",
  "confidence": 0.9,
  "responseMessage": "Located Lab 101 on First Floor.",
  "navigationRequest": null
}
```
*(Notice `navigationRequest` is strictly `null` because room inquiry does not request navigation handoff).*

---

## 8. Integration Instructions for the Spatial / Navigation Team

To consume the Semantic AI handoff in the spatial engine:

1. **Endpoint Consumption:**
   Call `POST /api/v1/ai/query` with:
   ```json
   {
     "text": "<natural language input>",
     "buildingId": "vit-ce",
     "userContext": {
       "currentNodeId": "<optional visitor location>",
       "accessible": false
     }
   }
   ```

2. **Check for Navigation Handoff:**
   Inspect the response body:
   ```javascript
   if (response.body.navigationRequest) {
     const navRequest = response.body.navigationRequest;
     // Validate against contracts/navigation-request.schema.json
     // Execute spatial routing:
     const route = spatialRouter.findRoute({
       startNodeId: navRequest.startNodeId,
       destinationNodeId: navRequest.destinationNodeId,
       preferences: navRequest.preferences
     });
   } else {
     // Display response.body.responseMessage to the user in the conversational bubble
     // No routing calculation required.
   }
   ```

3. **Invariants to Rely On:**
   - `navRequest.destinationNodeId` is guaranteed to be a valid node ID in the building graph.
   - `navRequest.preferences.emergencyMode` is `true` for emergency evacuations.
   - `navRequest.preferences.accessible` is `true` when step-free/wheelchair routing is required.
   - You do NOT need to sanitize against SQL injection or model prompt injection — the Semantic AI boundary guarantees full sanitization before handoff.
