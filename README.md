# MAPLESS AI
### *A Graph-Augmented Indoor Mapping and Spatial Intelligence Platform*

[![Status](https://img.shields.io/badge/Status-Initial%20Production%20Setup-blue.svg)](#)
[![Flutter](https://img.shields.io/badge/Flutter-3.41+-02569B.svg?logo=flutter)](https://flutter.dev)
[![Node.js](https://img.shields.io/badge/Node.js-24.x-339933.svg?logo=node.js)](https://nodejs.org)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16+-4169E1.svg?logo=postgresql)](https://www.postgresql.org)

---

## 1. Project Background & The Problem

Most commercial indoor navigation systems operate on the assumption that an accurate digital indoor floor plan already exists and rely on infrastructure such as:
- Bluetooth Low Energy (BLE) beacons
- Wi-Fi fingerprinting matrices
- Physical QR codes pasted on walls
- LiDAR / Visual SLAM equipment
- Proprietary CAD/BIM architectural blueprints

**MapLess AI** addresses the more fundamental and ubiquitous challenge:

> **"How can an indoor environment obtain a validated digital indoor map without architectural blueprints or dedicated physical infrastructure?"**

By leveraging everyday smartphone sensors (accelerometer, gyroscope, magnetometer, step counter), MapLess AI assists a building creator while walking through an indoor environment to establish a topological semantic indoor graph.

### Critical V1 Decision
- **Visitor Positioning**: The visitor's live indoor position is **NOT** automatically detected in V1. Visitors manually select or confirm their current mapped node.
- **Sensor Utilization**: Smartphone sensors are utilized strictly for creator-assisted map construction and edge measurement.

---

## 2. Core Objectives & Capabilities

1. **Infrastructure-Free Community Map Creation**: Build topological indoor maps using smartphone inertial sensors during a physical walkthrough.
2. **Semantic Graph-Based Navigation**: High-performance $A^*$ and Dijkstra routing across nodes and edges, supporting multi-floor traversals (stairs/elevators), accessibility-aware paths, emergency routing, and automated 2D indoor map rendering.
3. **Semantic Knowledge Graph**: Contextual indoor intelligence attaching room categories, operating hours, capacity, amenities, and aliases to physical nodes.
4. **Small Language Model (SLM) Conversational Navigation**: Converts natural language requests into validated, structured graph operations without allowing direct SQL execution.
5. **Map Versioning & Governance**: Immutable point-in-time snapshots, diffing, audit trails, and instant rollback.

---

## 3. Technology Stack

- **Mobile**: Flutter 3.41+, Dart 3.11+, Riverpod (State Management)
- **Backend**: Node.js 24.x, Express.js (Port `3000`)
- **Database**: PostgreSQL with JSONB (PostGIS compatible)
- **Authentication**: Firebase Authentication (initially)
- **API**: RESTful API over HTTP with JSON Schema contract enforcement
- **Algorithms**: $A^*$, Dijkstra, Graph Traversal, Compass Bearing Calculation, Dead Reckoning Coordinate Estimation
- **Sensors**: Accelerometer, Gyroscope, Magnetometer, Hardware Step Counter
- **AI**: Small Language Models (SLM), Intent Recognition, Entity Extraction, Semantic Knowledge Graph Querying

---

## 4. Monorepo Repository Structure

```
mapless-ai/
│
├── apps/
│   └── mobile/             # Flutter + Riverpod mobile application
│       ├── lib/
│       │   ├── core/       # Shared models, networking, constants, utils, widgets
│       │   ├── features/   # Feature modules (mapping, navigation, ai, versioning)
│       │   └── main.dart   # App entry point
│       └── test/           # Flutter unit and widget tests
│
├── backend/                # Node.js + Express backend service (Port 3000)
│   ├── src/
│   │   ├── config/         # Environment & database configuration
│   │   ├── middleware/     # Error handler, request logger
│   │   ├── utils/          # JSON Schema validator (Ajv)
│   │   ├── features/       # Modular routers & controllers
│   │   ├── app.js          # Express app definition
│   │   └── server.js       # Server listener
│   ├── sql/                # PostgreSQL schema & migrations
│   └── test/               # Backend integration and schema tests
│
├── contracts/              # Single source of truth: shared JSON schemas
│   ├── node.schema.json
│   ├── edge.schema.json
│   ├── building.schema.json
│   ├── floor.schema.json
│   ├── semantic-metadata.schema.json
│   ├── navigation-request.schema.json
│   ├── navigation-response.schema.json
│   ├── ai-query.schema.json
│   └── ai-response.schema.json
│
├── test_data/              # Standard development mock dataset
│   └── vit_floor_1.json    # VIT Computer Engineering Floor 1 topological graph
│
├── docs/                   # Architectural and technical documentation
│   ├── ARCHITECTURE.md
│   ├── API_CONTRACT.md
│   ├── DATA_MODEL.md
│   ├── AI_ARCHITECTURE.md
│   └── DEVELOPMENT_WORKFLOW.md
│
├── scripts/                # Setup and verification helper scripts
│   ├── setup.ps1
│   └── test_all.ps1
│
├── .gitignore              # Monorepo gitignore
├── README.md               # Project documentation
└── CONTRIBUTING.md         # Team branching and collaboration rules
```

---

## 5. Team Ownership Matrix

| Member | Primary Domain | Mobile Directory (`apps/mobile/lib/`) | Backend Directory (`backend/src/`) |
| :--- | :--- | :--- | :--- |
| **Nishant** | **Complete UI/UX & Mapping**: Owns all Flutter UI screens (mapping, navigation, AI chat, versioning, creator/visitor flows), router shell, shared widgets, design system, sensor integration, map editor. | `features/mapping/`<br>`core/` | `features/mapping/` |
| **Pratik** | **Spatial Intelligence Domain**: Spatial Graph engine, $A^*$, Dijkstra, route computation, multi-floor routing, accessibility routing, emergency routing, blocked-path handling, turn instruction generation. *(No UI)* | `features/navigation/` | `features/navigation/` |
| **Surabhi** | **Semantic AI Domain**: Semantic metadata, semantic knowledge graph, SLM interface, intent recognition, entity extraction, structured graph-query generation, validation/fallback. *(No UI)* | `features/ai/` | `features/ai/` |
| **Piyush** | **Map Versioning ONLY**: Snapshot generation, version numbering, version history, graph diffing, rollback, audit trail. *(No UI, auth, mapping, or AI)* | `features/versioning/` | `features/versioning/` |

---

## 6. Quick Start & Setup

### 1. Clone & Setup Workspace
```powershell
# Using the automated setup script:
.\scripts\setup.ps1
```

Or manually:

```powershell
# Backend setup
cd backend
npm install
npm test

# Mobile setup
cd ..\apps\mobile
flutter pub get
flutter analyze
flutter test
```

### 2. Run Backend
```powershell
cd backend
npm start
# Server starts on http://localhost:3000
# Verify: curl http://localhost:3000/health
```

### 3. Run Mobile App
```powershell
cd apps\mobile
flutter run
```

---

## 7. Architecture Invariants

- **Spatial Graph vs. Semantic Knowledge Graph**: Spatial Graph handles metric topology for $A^*$/Dijkstra. Semantic Knowledge Graph stores contextual metadata for natural language interpretation.
- **SLM Boundary**: Natural language $\rightarrow$ SLM $\rightarrow$ Validated structured query $\rightarrow$ Semantic Graph $\rightarrow$ Deterministic navigation engine. The SLM **never** executes SQL directly.
- **Single UI Owner**: Nishant owns the complete presentation layer. Pratik, Surabhi, and Piyush provide pure domain/service/state components.
- **Single Source of Truth**: All data models adhere to JSON schemas in `contracts/`.

For in-depth guides, see:
- [System Architecture](docs/ARCHITECTURE.md)
- [API Contract Specification](docs/API_CONTRACT.md)
- [Data Models & DB Schema](docs/DATA_MODEL.md)
- [AI Architecture & SLM Guidelines](docs/AI_ARCHITECTURE.md)
- [Development Workflow & Git Rules](CONTRIBUTING.md)
