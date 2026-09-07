# MapLess AI — System Architecture

## 1. Executive Summary & Core Philosophy

**MapLess AI** is an infrastructure-free, community-driven indoor mapping and spatial intelligence platform.

### The Fundamental Problem
Most modern indoor navigation systems operate on the assumption that a high-precision digital indoor map already exists. Furthermore, they typically depend on capital-intensive or hardware-heavy technologies:
- Wi-Fi fingerprinting grids
- Bluetooth Low Energy (BLE) beacon networks
- Visual QR markers posted at physical intervals
- Computer vision / LiDAR SLAM
- Proprietary CAD / BIM architectural floor-plan blueprints

MapLess AI solves the root problem:
> **"How can an indoor facility obtain a verified digital indoor map without architectural blueprints or dedicated hardware infrastructure?"**

By leveraging everyday smartphone sensors (accelerometer, gyroscope, magnetometer, and step counter) during a creator's physical walkthrough, MapLess AI constructs topological spatial graphs enriched with semantic context.

---

## 2. Fundamental Architectural Decision: Visitor Positioning in V1

> **V1 INVARIANT:**
> The visitor's live indoor position is **NOT** automatically detected in Version 1.
> Visitors manually choose or confirm their current starting location from the list or canvas of mapped indoor nodes.
> Smartphone sensors are employed **exclusively** for creator-assisted map construction, dead-reckoning displacement estimation, and edge measurement.

---

## 3. High-Level System Data Pipeline

```
          [ Creator Walkthrough ]
                     │
                     ▼
          [ Smartphone Sensors ]
     (Step Counter, Gyro, Compass)
                     │
                     ▼
             [ Mapping Engine ]
         (Nodes, Edges, Bearings)
                     │
         ┌───────────┴───────────┐
         ▼                       ▼
  [ Spatial Graph ]     [ Semantic Knowledge Graph ]
  • Topology (Nodes)    • Entity metadata & tags
  • Physical Edges      • Operating hours & capacity
  • Distances (meters)  • Dept relationships
  • Angles (bearings)   • Accessibility attributes
  • Obstruction state   • Aliases & synonyms
         │                       │
         │         ┌─────────────┘
         │         │ (Context Extraction)
         │         ▼
         │   [ SLM Pipeline ]
         │   • Natural Language Input
         │   • Intent Classification
         │   • Entity/Constraint Extraction
         │   • (NO direct SQL execution)
         │         │
         │         ▼
         │   [ Validated Structured Query ]
         │         │
         └─────────┼─────────────┐
                   ▼             ▼
          [ Graph Engine ]  [ Map Versioning ]
          • A* / Dijkstra   • Immutable Snapshots
          • Multi-floor     • Audit Trail
          • Accessibility   • Rollback & Diffs
          • Turn Guidance
                   │
                   ▼
       [ 2D Indoor Visualization ]
                   │
                   ▼
            [ Flutter UI ]
```

---

## 4. Separation of Concerns: Spatial Graph vs. Semantic Knowledge Graph

To prevent tight coupling and logic corruption, MapLess AI enforces a strict architectural boundary between physical space and contextual semantics:

### A. The Spatial Graph (Owner: Pratik)
- **Role**: Metric geometry and network connectivity.
- **Data Primitives**:
  - `Node`: Unique ID, Floor ID, 2D local Cartesian coordinates $(x, y)$ in meters, barrier-free accessibility flag.
  - `Edge`: Source Node, Target Node, physical distance (meters), compass heading (bearing in degrees $0-360^\circ$), traversal accessibility, active obstruction flag.
- **Consumers**: Pathfinding engines ($A^*$, Dijkstra), multi-floor stair/elevator transitions, turn-by-turn instruction generators.

### B. The Semantic Knowledge Graph (Owner: Surabhi)
- **Role**: Human meaning, contextual relationships, and discovery.
- **Data Primitives**:
  - `SemanticMetadata`: Room aliases, category taxonomy (`laboratory`, `canteen`, `lecture_hall`, `restroom`), responsible departments, amenities (projector, Wi-Fi, air conditioning), operational hours, maximum occupancy.
- **Consumers**: Small Language Model (SLM) query parser, natural-language search, semantic filtering.

---

## 5. Architectural Component Boundaries

| Component | Responsibility | Single Owner |
| :--- | :--- | :--- |
| **MAPPING** | Creator-assisted node/edge capture, smartphone sensor integration, local coordinate estimation, indoor canvas rendering. | **Nishant** |
| **SEMANTICS & KNOWLEDGE GRAPH** | Semantic metadata schema, entity relationships, SLM query parsing, intent/entity extraction, query validation, and fallback handling. | **Surabhi** |
| **SPATIAL GRAPH & NAVIGATION** | Topological graph data structures, $A^*$ and Dijkstra implementations, multi-floor traversal, accessibility pathing, blocked-path rerouting, turn instructions. | **Pratik** |
| **VERSIONING** | Immutable snapshot generation, graph serialization, version numbering, semantic diffs, rollback capabilities, audit metadata. | **Piyush** |
| **PRESENTATION (UI/UX)** | Unified Flutter UI across all feature screens, Riverpod state consumption, navigation/router shell, shared widgets, accessibility compliance. | **Nishant** |

---

## 6. Small Language Model (SLM) Security Boundary

```
User Query: "Take me to the nearest open computer lab with wheelchair access"
   │
   ▼
[ SLM Inference Engine ]
   │ (Extracts structured semantic parameters)
   ▼
[ Validated Structured JSON Contract ]
{
  "intent": "FIND_NEAREST",
  "constraints": {
    "category": "laboratory",
    "accessible": true,
    "tags": ["computers"]
  }
}
   │ (Deterministic Validation)
   ▼
[ Semantic Graph Resolver ] ──> Resolves candidate Node IDs: ["lab-101"]
   │
   ▼
[ Deterministic Graph Engine ] ──> Runs A* from current node to "lab-101"
   │
   ▼
[ Validated Navigation Response ] ──> Displayed on Flutter UI
```

> **SECURITY INVARIANT:**
> The SLM must **NEVER** construct or execute arbitrary SQL, database queries, or graph mutations directly.
> The SLM's sole responsibility is emitting validated, structured intent and constraint schemas (`contracts/ai-response.schema.json`).
> The backend application code deterministically validates and executes all graph lookups.

---

## 7. Modular Monolith Architecture

For V1, MapLess AI deliberately adopts a **modular monolith** rather than premature microservices:
- **Backend**: Single Node.js/Express service partitioned into feature namespaces (`/api/v1/mapping`, `/api/v1/navigation`, `/api/v1/ai`, `/api/v1/versioning`) sharing a common PostgreSQL database.
- **Frontend**: Single Flutter application partitioned into feature modules (`features/mapping`, `features/navigation`, `features/ai`, `features/versioning`), unified under a single UI presentation layer owned by Nishant.
- **Inter-service contracts**: Enforced via shared JSON schemas (`contracts/`).
