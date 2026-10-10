# Spatial Navigation Engine Integration Handoff Document

This document serves as the official integration contract and handoff specification for the **Spatial Intelligence & Navigation Subsystem (Owner: Pratik)** in MapLess AI.

It defines how upstream subsystems (such as **Semantic AI / Surabhi** and **Application Controllers / UI**) construct spatial graphs, request routes, handle structured failures, configure accessibility preferences, request emergency routes, inspect alternative routes, and interpret spatial metrics.

---

## 1. Ownership & Architectural Scope

```text
Semantic AI Subsystem (Surabhi)
  Natural language → Intent/Target Resolution → Validated NavigationRequest
                                                        │
                                                        ▼
Spatial Navigation Engine (Pratik)
  NavigationRequest + SpatialGraph → Dijkstra / A* / Yen → NavigationResponseModel / AlternativeRoutesResult
                                                        │
                                                        ▼
Presentation & State Management (App Shell / UI)
  Route visualization, turn instruction prompts, map viewport updates
```

### Provided Responsibilities (Spatial Engine — Pratik)
- **Deterministic Pathfinding:** Dijkstra and coordinate-heuristic A* pathfinding over multi-floor spatial graphs.
- **Alternative Routes:** Yen's K-shortest loopless path algorithm producing deterministic, loopless candidate routes.
- **Dynamic Policy Enforcement:** Real-time filtering of blocked edges, wheelchair-inaccessible edges/nodes, and stairs.
- **Turn Instructions:** Deterministic calculation of relative bearings and human-readable step-by-step guidance.
- **Multi-Floor Transitions:** Detection and generation of structured vertical transitions (stairs, elevator, ramp).
- **Emergency-Exit Routing:** Cost-optimal pathfinding to explicitly designated emergency exits.
- **Graph Diagnostics & Quality Validation:** Structural integrity checks, component analysis, geometric mismatch detection, and reachability validation.

### Excluded Responsibilities (Owned by Other Subsystems)
- **Natural Language & Query Extraction (Surabhi):** Intent classification, entity matching, and semantic query expansion.
- **Sensor Data Collection & SLAM:** PDR, step counting, accelerometer/gyroscope fusion, and live indoor localization.
- **UI Screens & Rendering:** Flutter canvas rendering, path polyline animations, and camera viewport controls.
- **Backend & Cloud Persistence:** Remote graph syncing, user authentication, or persistent database queries.
- **Certified Evacuation Safety:** This engine provides cost-optimal algorithmic pathfinding to designated graph exits; it does **not** provide live fire/smoke hazard simulation or certified life-safety guarantees.

---

## 2. Public API Reference

The primary entry point is [`IPathfindingService`](file:///e:/College/Third%20Year/ERI/Code%20Repository/apps/mobile/lib/features/navigation/services/pathfinding_service.dart#L44-L85), implemented by [`PathfindingService`](file:///e:/College/Third%20Year/ERI/Code%20Repository/apps/mobile/lib/features/navigation/services/pathfinding_service.dart#L87-L835).

```dart
abstract class IPathfindingService {
  /// Computes a point-to-point route or emergency route based on request preferences.
  Future<NavigationResponseModel> computeRoute(
    SpatialGraph graph,
    NavigationRequestModel request, {
    NavigationAlgorithm algorithm = NavigationAlgorithm.dijkstra,
  });

  /// Computes the optimal evacuation route from startNodeId to the lowest-cost reachable emergency exit.
  Future<NavigationResponseModel> computeEmergencyRoute(
    SpatialGraph graph,
    String startNodeId, {
    NavigationPreferencesModel preferences = const NavigationPreferencesModel(
      avoidBlockedEdges: true,
      emergencyMode: true,
    ),
    NavigationAlgorithm algorithm = NavigationAlgorithm.dijkstra,
  });

  /// Computes up to maxRoutes distinct loopless alternative routes ranked by distance.
  Future<AlternativeRoutesResult> computeAlternativeRoutes(
    SpatialGraph graph,
    NavigationRequestModel request, {
    int maxRoutes = 3,
    NavigationAlgorithm algorithm = NavigationAlgorithm.dijkstra,
  });

  /// Convenience overload taking raw node IDs.
  Future<AlternativeRoutesResult> findAlternativeRoutes(
    SpatialGraph graph,
    String startNodeId,
    String destinationNodeId, {
    int maxRoutes = 3,
    NavigationPreferencesModel preferences = const NavigationPreferencesModel(),
    NavigationAlgorithm algorithm = NavigationAlgorithm.dijkstra,
  });
}
```

### Models & Supporting Classes

1. **[`SpatialGraph`](file:///e:/College/Third%20Year/ERI/Code%20Repository/apps/mobile/lib/features/navigation/domain/spatial_graph.dart):**
   - `SpatialGraph.fromNodesAndEdges(Iterable<NodeModel> nodes, Iterable<EdgeModel> edges, {bool validate = false, GraphQualityOptions options})`
   - `GraphValidationResult validate({GraphQualityOptions options})`
   - `void validateOrThrow({GraphQualityOptions options})`
2. **[`NavigationRequestModel`](file:///e:/College/Third%20Year/ERI/Code%20Repository/apps/mobile/lib/core/models/navigation_request_model.dart):**
   - `buildingId` (`String`, required)
   - `startNodeId` (`String`, required)
   - `destinationNodeId` (`String`, required)
   - `preferences` (`NavigationPreferencesModel`, defaults to standard walking)
3. **[`NavigationPreferencesModel`](file:///e:/College/Third%20Year/ERI/Code%20Repository/apps/mobile/lib/core/models/navigation_request_model.dart#L2-L32):**
   - `accessible` (`bool`, default: `false`): Requires wheelchair accessibility across traversed edges and intermediate nodes.
   - `avoidStairs` (`bool`, default: `false`): Prefers elevators or ramps over stairs.
   - `avoidBlockedEdges` (`bool`, default: `true`): Excludes edges marked `blocked: true`.
   - `emergencyMode` (`bool`, default: `false`): Automatically routes to the nearest reachable emergency exit.
4. **[`NavigationResponseModel`](file:///e:/College/Third%20Year/ERI/Code%20Repository/apps/mobile/lib/core/models/navigation_response_model.dart#L98-L199):**
   - Conforms strictly to [`contracts/navigation-response.schema.json`](file:///e:/College/Third%20Year/ERI/Code%20Repository/contracts/navigation-response.schema.json).
5. **[`AlternativeRoutesResult`](file:///e:/College/Third%20Year/ERI/Code%20Repository/apps/mobile/lib/features/navigation/models/alternative_routes_result.dart#L91-L160):**
   - Dedicated envelope containing ranked candidate routes (`routes: List<NavigationResponseModel>`) and structured comparison metrics (`comparisons: List<RouteComparisonModel>`).

---

## 3. Request & Response Examples

### A. Point-to-Point Route (Success)

**Request Object (`NavigationRequestModel`):**
```json
{
  "buildingId": "vit-ce",
  "startNodeId": "entrance",
  "destinationNodeId": "lab-101",
  "preferences": {
    "accessible": false,
    "avoidStairs": false,
    "avoidBlockedEdges": true,
    "emergencyMode": false
  }
}
```

**Response Object (`NavigationResponseModel.toJson()`):**
```json
{
  "success": true,
  "pathNodeIds": ["entrance", "reception", "corridor", "lab-101"],
  "edgeIds": ["edge-entrance-reception", "edge-reception-corridor", "edge-corridor-lab101"],
  "totalDistance": 30.0,
  "estimatedTimeSeconds": 25.0,
  "turnInstructions": [
    {
      "step": 1,
      "instruction": "Head towards Reception",
      "distance": 10.0,
      "bearing": 90.0,
      "nodeId": "entrance"
    },
    {
      "step": 2,
      "instruction": "Turn left towards Central Corridor",
      "distance": 15.0,
      "bearing": 0.0,
      "nodeId": "reception"
    },
    {
      "step": 3,
      "instruction": "Turn right to arrive at AI Lab 101",
      "distance": 5.0,
      "bearing": 90.0,
      "nodeId": "corridor"
    },
    {
      "step": 4,
      "instruction": "You have arrived at AI Lab 101",
      "distance": 0.0,
      "bearing": 0.0,
      "nodeId": "lab-101"
    }
  ],
  "floorTransitions": [],
  "message": "Route calculated via dijkstra",
  "routeStatus": "success",
  "algorithm": "dijkstra",
  "nodesExplored": 4
}
```

### B. Structured Failure (No Route Found)

When no continuous path exists between start and destination under active constraints:

```json
{
  "success": false,
  "pathNodeIds": [],
  "edgeIds": [],
  "totalDistance": 0.0,
  "estimatedTimeSeconds": 0.0,
  "turnInstructions": [],
  "floorTransitions": [],
  "message": "No route found from 'room-101' to 'room-202'",
  "routeStatus": "no_route",
  "algorithm": "dijkstra",
  "nodesExplored": 12
}
```

### C. Multi-Floor Accessibility-Constrained Route

When traversing across floors with `accessible: true, avoidStairs: true`:

```json
{
  "success": true,
  "pathNodeIds": ["entrance", "lift-f1", "lift-f2", "lab-201"],
  "edgeIds": ["edge-entrance-lift1", "edge-lift1-lift2", "edge-lift2-lab201"],
  "totalDistance": 69.0,
  "estimatedTimeSeconds": 57.5,
  "turnInstructions": [
    {
      "step": 1,
      "instruction": "Head towards Ground Floor Lift",
      "distance": 25.0,
      "bearing": 90.0,
      "nodeId": "entrance"
    },
    {
      "step": 2,
      "instruction": "Take the lift to floor-2",
      "distance": 4.0,
      "bearing": 0.0,
      "nodeId": "lift-f1"
    },
    {
      "step": 3,
      "instruction": "Head towards Advanced Robotics Lab",
      "distance": 40.0,
      "bearing": 90.0,
      "nodeId": "lift-f2"
    },
    {
      "step": 4,
      "instruction": "You have arrived at Advanced Robotics Lab",
      "distance": 0.0,
      "bearing": 0.0,
      "nodeId": "lab-201"
    }
  ],
  "floorTransitions": [
    {
      "fromFloorId": "floor-1",
      "toFloorId": "floor-2",
      "viaType": "elevator",
      "nodeId": "lift-f2"
    }
  ],
  "message": "Route calculated via dijkstra",
  "routeStatus": "success",
  "algorithm": "dijkstra",
  "nodesExplored": 18
}
```

### D. Emergency Route Request & Response

In an emergency evacuation workflow, the caller sets `preferences.emergencyMode = true`.

#### 1. Current Working Request Format (Production Contract)
Under the current contract, downstream callers **must** supply:
1. A real, valid `startNodeId` representing an existing node in the spatial graph. **Replacing a missing `startNodeId` with an empty string `""` is NOT a valid resolution**; the spatial engine fundamentally requires a physical origin node to originate an evacuation route.
2. A placeholder string for `destinationNodeId` (such as `"emergency_exit"`). This placeholder is required **solely because the current contract and model enforce `destinationNodeId` as a required non-nullable string**. At runtime, the spatial engine completely bypasses this value and dynamically resolves the lowest-cost reachable emergency exit.

**Current Working Request Object (`NavigationRequestModel.toJson()`):**
```json
{
  "buildingId": "vit-ce",
  "startNodeId": "lab-201",
  "destinationNodeId": "emergency_exit",
  "preferences": {
    "accessible": false,
    "avoidStairs": false,
    "avoidBlockedEdges": true,
    "emergencyMode": true
  }
}
```

> [!IMPORTANT]
> **Current Contract vs. Proposed Future Behavior:**
> - **Current Behavior:** Callers must supply a valid, existing `startNodeId` and pass a placeholder string (e.g., `"emergency_exit"`) for `destinationNodeId` so that both JSON schema validation (`required: ["destinationNodeId"]`) and Dart deserialization (`json['destinationNodeId'] as String`) succeed.
> - **Engine Invariant:** The engine validates that `startNodeId` exists in the graph. It ignores `destinationNodeId` when `emergencyMode == true`.
> - **Proposed Future Contract (Pending Alignment):** Schema updates are proposed to make `destinationNodeId` nullable/optional in emergency mode, eliminating the need for placeholder destinations. Neither proposal is active yet.

**Response Object (`NavigationResponseModel.toJson()`):**
```json
{
  "success": true,
  "pathNodeIds": ["lab-201", "stairs-f2", "stairs-f1", "exit-north"],
  "edgeIds": ["e1", "e2", "e3"],
  "totalDistance": 42.0,
  "estimatedTimeSeconds": 35.0,
  "turnInstructions": [
    {
      "step": 1,
      "instruction": "Proceed towards North Fire Exit via Staircase",
      "distance": 42.0,
      "bearing": 0.0,
      "nodeId": "lab-201"
    }
  ],
  "floorTransitions": [
    {
      "fromFloorId": "floor-2",
      "toFloorId": "floor-1",
      "viaType": "stairs",
      "nodeId": "stairs-f1"
    }
  ],
  "message": "Emergency route calculated to \"North Exit\" via dijkstra",
  "routeStatus": "success",
  "algorithm": "dijkstra",
  "nodesExplored": 22
}
```

### E. Alternative Routes Result (`AlternativeRoutesResult.toJson()`)

```json
{
  "success": true,
  "routes": [
    {
      "success": true,
      "pathNodeIds": ["a", "b", "d"],
      "edgeIds": ["e_ab", "e_bd"],
      "totalDistance": 10.0,
      "estimatedTimeSeconds": 8.33,
      "turnInstructions": [...],
      "floorTransitions": [],
      "routeStatus": "success",
      "algorithm": "dijkstra",
      "nodesExplored": 3
    },
    {
      "success": true,
      "pathNodeIds": ["a", "c", "d"],
      "edgeIds": ["e_ac", "e_cd"],
      "totalDistance": 14.0,
      "estimatedTimeSeconds": 11.67,
      "turnInstructions": [...],
      "floorTransitions": [],
      "routeStatus": "success",
      "algorithm": "dijkstra",
      "nodesExplored": 6
    }
  ],
  "comparisons": [
    {
      "routeIndex": 0,
      "totalDistance": 10.0,
      "estimatedTimeSeconds": 8.33,
      "floorTransitionCount": 0,
      "pathNodeIds": ["a", "b", "d"],
      "edgeIds": ["e_ab", "e_bd"],
      "distanceDeltaFromPrimary": 0.0,
      "timeDeltaFromPrimary": 0.0
    },
    {
      "routeIndex": 1,
      "totalDistance": 14.0,
      "estimatedTimeSeconds": 11.67,
      "floorTransitionCount": 0,
      "pathNodeIds": ["a", "c", "d"],
      "edgeIds": ["e_ac", "e_cd"],
      "distanceDeltaFromPrimary": 4.0,
      "timeDeltaFromPrimary": 3.34
    }
  ],
  "routeStatus": "success",
  "algorithm": "dijkstra",
  "totalNodesExplored": 9
}
```

---

## 4. Routing Engine Invariants & Behaviors

1. **Directed Edge Semantics:** All edges in `SpatialGraph` are strictly directed ($A \to B$ does not permit $B \to A$ unless an explicit reverse edge exists).
2. **Blocked-Edge Exclusion:** When `preferences.avoidBlockedEdges` is `true` (default), edges with `blocked: true` are filtered during neighbor expansion. Blocked edges remain stored in the graph; no graph mutation occurs.
3. **Deterministic Tie-Breaking:** When two candidate paths share the exact same cumulative cost:
   - Dijkstra and A* pick the path whose first branching edge appears earlier in the graph's deterministic insertion-ordered adjacency list.
   - Yen's algorithm tie-breaks candidate paths by node signature comparison (`nodeIds.join('->')`), ensuring byte-identical results across runs.
4. **Endpoint Accessibility Semantics:**
   - When `accessible: true`, all intermediate edges and intermediate nodes must have `accessible: true`.
   - The destination node itself is permitted to have `accessible: false` if the approach edge is valid (e.g. allowing navigation to a desk or landing at the room boundary).
5. **Stair Avoidance:**
   - When `avoidStairs: true`, edges/transitions matching stair tokens (`'stairs'`, `'staircase'`, `'stair'`, `'stairwell'`, `'stairway'`) are filtered.
6. **Floor Transition Normalization:**
   - Multi-floor transitions are detected when `fromNode.floorId != toNode.floorId`.
   - Tokens are matched strictly: `lift`/`elevator` $\to$ `'elevator'`; `ramp` $\to$ `'ramp'`; `stairs` $\to$ `'stairs'`.
   - Unknown values (e.g. `conveyor`, `portal`) strictly fail and throw `GraphException(code: 'UNKNOWN_FLOOR_TRANSITION_TYPE')`. They are **never** silently converted to `'elevator'`.
7. **Emergency-Exit Selection:**
   - Evaluates all nodes matching `category: 'emergency_exit'` or `metadata['isEmergencyExit']: true`.
   - Selects the exit that minimizes **actual graph path traversal cost** (not straight-line Euclidean distance).
   - If the origin is already at an emergency exit, returns an immediate 0-distance arrival route.

---

## 5. Graph Quality Validation & Diagnostic Codes

Before deploying or running routes on a spatial graph, callers can execute:

```dart
final validation = graph.validate(options: GraphQualityOptions());
```

### Diagnostic Severity
- **Errors (`DiagnosticSeverity.error`):** Make `validation.isValid == false`. Prevent reliable routing. Calling `graph.validateOrThrow()` will throw `GraphException(code: 'GRAPH_VALIDATION_FAILED')`.
- **Warnings (`DiagnosticSeverity.warning`):** Advisory findings. Do **not** invalidate the graph (`validation.isValid` remains `true`). Point-to-point routes and emergency routes continue to execute.

### Summary of Diagnostic Codes

| Code | Severity | Description |
| :--- | :---: | :--- |
| `empty_graph` | Error | Graph contains 0 nodes. |
| `missing_start_node` | Error | Edge references a non-existent start node ID. |
| `missing_end_node` | Error | Edge references a non-existent end node ID. |
| `invalid_distance` | Error | Edge distance is negative, infinite, or NaN. |
| `err_malformed_floor_connector` | Error | Cross-floor edge lacks recognized connector metadata (`strictFloorTransitions: true`). |
| `malformed_floor_connector` | Warning | Cross-floor edge lacks recognized connector metadata (`strictFloorTransitions: false`). |
| `conflicting_connector_metadata` | Warning | Cross-floor edge specifies conflicting connector types (e.g. both stairs and elevator). |
| `self_loop` | Warning | Edge has `startNodeId == endNodeId`. Permitted as valid topology, but warned. |
| `isolated_node` | Warning | Node has degree 0 (no incoming or outgoing edges). |
| `dead_end_node` | Warning | Node has incoming edges but zero outgoing edges (when `checkDeadEnds: true`). |
| `disconnected_components` | Warning | Graph has $\ge 2$ weakly connected components. Same-component routes remain valid. |
| `unreachable_emergency_exit` | Warning | Designated emergency exit cannot be reached from any other node in its component. |
| `geometric_mismatch` | Warning | Edge physical distance is shorter than Euclidean coordinate distance, or exceeds ratio. |
| `duplicate_edge` | Warning | Multiple parallel edges connect the same directed node pair. |

---

## 6. Metric Definitions & Formulas

| Metric | Field | Unit / Type | Definition / Standard Assumption |
| :--- | :--- | :--- | :--- |
| **Total Distance** | `totalDistance` | meters (`double`) | Exact sum of traversed physical edge distances $\sum e_i.\text{distance}$. |
| **Estimated Walking Time** | `estimatedTimeSeconds` | seconds (`double`) | $\text{totalDistance} / 1.2\text{ m/s}$. Assumes standard pedestrian walking pace ($1.2\text{ m/s} \approx 4.32\text{ km/h}$). Zero for 0-distance routes. |
| **Nodes Explored** | `nodesExplored` | integer (`int`) | Number of unique graph nodes popped from the priority queue and expanded. Zero for trivial start==destination or missing node requests. |
| **Turn Bearings** | `bearing` | degrees (`double`) | $0^\circ \le \theta < 360^\circ$ absolute or relative compass direction along edge geometry. |
| **Floor Transitions** | `viaType` | string enum | Fixed contract enum: `'stairs'`, `'elevator'`, `'ramp'`. |

---

## 7. Error-Handling Guide for Downstream Callers

Callers should distinguish between **structured domain outcomes** and **thrown exceptions**:

### A. Structured Domain Outcomes (Normal Control Flow)
When user input or graph configuration leads to no reachable path, the service returns a `NavigationResponseModel` with `success: false` and a distinct machine-readable `RouteStatus`:

```dart
final response = await service.computeRoute(graph, request);

if (!response.success) {
  switch (response.routeStatus) {
    case RouteStatus.startNodeNotFound:
      // Show error: "Current location is unrecognized. Please select a valid starting point."
      break;
    case RouteStatus.destinationNodeNotFound:
      // Show error: "Destination node could not be found in building."
      break;
    case RouteStatus.noRoute:
      // Show error: "No accessible path available under current preferences."
      break;
    case RouteStatus.invalidRequest:
      // Malformed request payload.
      break;
    case RouteStatus.success:
      break;
  }
}
```

### B. Thrown Exceptions (`GraphException`)
Exceptions indicate programmer error, corrupt graph topologies, or internal invariant violations. Callers should catch `GraphException` at boundary layers:

```dart
try {
  final graph = SpatialGraph.fromNodesAndEdges(nodes, edges, validate: true);
} on GraphException catch (e) {
  logger.error('Graph construction failed [code: ${e.code}]: ${e.message}');
}
```

Common stable error codes:
- `'DUPLICATE_NODE_ID'`: Attempted to add a node with an ID already in the graph.
- `'MISSING_START_NODE'`, `'MISSING_END_NODE'`: Edge references missing node ID.
- `'INVALID_DISTANCE'`: Edge distance is negative, NaN, or infinite.
- `'GRAPH_VALIDATION_FAILED'`: `validateOrThrow()` encountered hard structural errors.
- `'UNKNOWN_FLOOR_TRANSITION_TYPE'`: Cross-floor edge lacks recognized connector metadata during transition generation.
- `'INCONSISTENT_ROUTE_RESULT'`: Engine produced non-continuous path nodes/edges (internal bug).

---

## 8. Contract Readiness & Known Schema Nuances

### 1. Emergency Request Contract Analysis & End-to-End Tracing

The emergency routing contract spans four stages: authoritative JSON schema, Dart serialization model, input validation, and execution in `PathfindingService.computeRoute`.

```text
1. JSON Payload ──────► 2. NavigationRequestModel.fromJson ──────► 3. computeRoute ──────► 4. computeEmergencyRoute
  - schema validation        - Dart type casts                       - emergencyMode flag      - exit discovery
  - required fields          - Null checks                           - destination bypass      - shortest-path search
```

#### Detailed Behavior Matrix (Current Production Behavior)

| Payload Variant | Schema Valid? (`contracts/navigation-request.schema.json`) | Dart Constructible? (`NavigationRequestModel.fromJson`) | `computeRoute` Behavior | Final Outcome |
| :--- | :--- | :--- | :--- | :--- |
| **`startNodeId: "valid_id"`, `destinationNodeId: "emergency_exit"`, `emergencyMode: true`** | **YES** | **YES** | Delegates to `computeEmergencyRoute`. Ignores placeholder destination. Discovers nearest exit. | **`RouteStatus.success`** (or `noRoute` if no exits reachable) |
| **`startNodeId: ""`, `destinationNodeId: "emergency_exit"`, `emergencyMode: true`** | **YES** | **YES** | Delegates to `computeEmergencyRoute`. `graph.hasNode("")` returns `false`. | **`RouteStatus.startNodeNotFound`** |
| **`startNodeId: "unknown_id"`, `destinationNodeId: "exit"`, `emergencyMode: true`** | **YES** | **YES** | Delegates to `computeEmergencyRoute`. `graph.hasNode(startNodeId)` returns `false`. | **`RouteStatus.startNodeNotFound`** |
| **`startNodeId: null` or omitted, `destinationNodeId: "exit"`, `emergencyMode: true`** | **YES** (`startNodeId` is nullable in schema) | **NO** (`TypeError`: `type 'Null' is not a subtype of type 'String'`) | Cannot reach `computeRoute` via JSON deserialization. | **Runtime crash (`TypeError`)** |
| **`startNodeId: "valid_id"`, `destinationNodeId` omitted, `emergencyMode: true`** | **NO** (`destinationNodeId` is in schema's `required`) | **NO** (`TypeError`: `type 'Null' is not a subtype of type 'String'`) | Cannot reach `computeRoute` via JSON deserialization. | **Runtime crash (`TypeError`)** |

#### Invariants & Current vs. Proposed Future Behavior

1. **A Real `startNodeId` is Strictly Mandatory:**
   Replacing a missing `startNodeId` with an empty string `""` is **not a valid resolution**. Spatial graph pathfinding fundamentally requires a concrete, verified node ID representing the visitor's location in the graph. If `startNodeId` is empty or not in the graph, pathfinding cannot originate anywhere and fails cleanly with `RouteStatus.startNodeNotFound`.
2. **Why a Placeholder Destination is Used Today:**
   Under the current contract (`contracts/navigation-request.schema.json`), `destinationNodeId` is in the `required` array, and `NavigationRequestModel` declares `final String destinationNodeId`. Therefore, callers must supply a non-empty placeholder string (e.g., `"emergency_exit"`) **solely to satisfy the current schema and model constructors**. In `computeRoute`, the engine detects `emergencyMode == true` and bypasses the destination node entirely.
3. **Proposed Future Contract Alignment (Pending Team Review — Do Not Implement Without Approval):**
   To resolve this mismatch between the shared JSON schema and the Dart domain model, the following proposals are submitted for wider team evaluation:
   - **Proposal 1 (Schema-level amendment — Recommended for cross-platform alignment):**
     Update `contracts/navigation-request.schema.json` to allow `destinationNodeId` to be nullable:
     ```json
     "destinationNodeId": {
       "type": ["string", "null"],
       "description": "Target destination node ID. May be null when preferences.emergencyMode is true or intent is EMERGENCY_EXIT."
     }
     ```
     And relax schema `required: ["buildingId"]` when `intent == "EMERGENCY_EXIT"`.
   - **Proposal 2 (Dart model relaxation — Mobile adaptation):**
     Update `NavigationRequestModel.fromJson` in `apps/mobile/lib/core/models/navigation_request_model.dart` to provide null-safe defaults for `destinationNodeId` only (`json['destinationNodeId'] as String? ?? 'emergency_exit'`). Note: `startNodeId` would still require a valid string, as navigation cannot function without an origin.

> [!CAUTION]
> **Action Boundary:** Neither Proposal 1 nor Proposal 2 has been implemented in code. Production callers must adhere to the **Current Production Behavior** (valid `startNodeId`, placeholder `destinationNodeId`).

### 2. Contract-Compliant Response Enums
- `routeStatus` serialized strictly matches `contracts/navigation-response.schema.json`:
  `'success'`, `'no_route'`, `'invalid_request'`, `'start_node_not_found'`, `'destination_node_not_found'`.
- `floorTransitions[].viaType` strictly matches: `'stairs'`, `'elevator'`, `'ramp'`.
- `algorithm` strictly matches: `'dijkstra'`, `'a_star'`.

---

## 9. Testing & Benchmarking Guide

### Running Focused Navigation Tests
```bash
flutter test test/features/navigation/
```

### Running Performance Benchmarks
```bash
flutter test test/features/navigation/navigation_performance_benchmark_test.dart
```

### Running Complete Application Suite & Analyzer
```bash
flutter test
flutter analyze --no-pub
```

### Current Test Baseline (Phase 13)
- Navigation Test Suite: **280 / 280 tests passed** (0 failures).
- Full Application Test Suite: **482 / 482 tests passed** (0 failures).
- Static Analysis: **0 issues** (`No issues found!`).

---

## 10. Known Limitations & Caveats

1. **Yen's Algorithm on Massive Graphs:** On synthetic 5,000-node graphs across 5 floors with path lengths $> 70$ hops, Yen's algorithm for $K=5$ performs $\sim 280$ full Dijkstra traversals, requiring $\sim 1.3\text{ to }2.0\text{ seconds}$. On realistic building graphs (100 to 1,000 nodes), $K=3$ returns in $\le 63\text{ ms}$ and $K=5$ in $\le 126\text{ ms}$. For very large graphs, callers should prefer $K=3$.
2. **A\* Admissibility Checking:** Before search, `AStarEngine` performs a runtime admissibility check over traversable edges. When the admissibility check passes, A* prunes up to $28\%$ of nodes explored. When admissibility is violated by arbitrary physical edge lengths, A* falls back to $h=0$ (identical to Dijkstra).
3. **No Live Localization:** This engine computes topological and spatial routes. Correlating mobile phone sensor step counts or Bluetooth beacons with the graph is handled by upstream sensor fusion and location tracking subsystems.
4. **No Certified Life-Safety Guarantees:** Emergency exit selection chooses the reachable exit with the minimum graph traversal cost under active blocked-edge policies. It does not provide certified dynamic smoke or hazard evacuation guarantees.

---

## 11. Downstream Integration Checklist

Follow these 5 steps to integrate the navigation engine into an application workflow:

1. **Construct Graph:**
   ```dart
   final graph = SpatialGraph.fromNodesAndEdges(buildingNodes, buildingEdges);
   ```
2. **Validate Quality (Optional/Recommended during Building Ingestion):**
   ```dart
   final result = graph.validate(options: const GraphQualityOptions());
   if (!result.isValid) {
     throw Exception('Corrupt building graph: ${result.errors.join("; ")}');
   }
   ```
3. **Assemble Navigation Request:**
   ```dart
   final request = NavigationRequestModel(
     buildingId: 'vit-ce',
     startNodeId: visitorCurrentNodeId,
     destinationNodeId: resolvedTargetNodeId,
     preferences: NavigationPreferencesModel(
       accessible: userRequiresWheelchair,
       avoidStairs: userAvoidsStairs,
       avoidBlockedEdges: true,
     ),
   );
   ```
4. **Compute Route:**
   ```dart
   final service = PathfindingService();
   final response = await service.computeRoute(graph, request);
   ```
5. **Handle Outcome:**
   ```dart
   if (response.success) {
     mapController.displayRoute(response.pathNodeIds, response.turnInstructions);
   } else {
     uiController.showRoutingError(response.routeStatus, response.message);
   }
   ```
6. **Request Emergency Evacuation Route (Current Working Format):**
   ```dart
   final emergencyRequest = NavigationRequestModel(
     buildingId: 'vit-ce',
     startNodeId: visitorCurrentNodeId, // MUST be a real, valid node ID existing in the graph
     destinationNodeId: 'emergency_exit', // Placeholder string required by current contract; bypassed by engine in emergencyMode
     preferences: const NavigationPreferencesModel(
       emergencyMode: true,
       avoidBlockedEdges: true,
     ),
   );
   final emergencyResponse = await service.computeRoute(graph, emergencyRequest);
   ```
