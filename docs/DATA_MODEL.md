# MapLess AI — Data Model Specification

## 1. Domain Entities & Relationships

The MapLess AI spatial intelligence domain is structured around six core domain entities:

```
┌──────────────┐
│   Building   │
└──────┬───────┘
       │ 1
       │ has many
       ▼ *
┌──────────────┐          ┌───────────────────┐
│    Floor     │◄─────────┤    MapVersion     │ (Immutable Graph Snapshots)
└──────┬───────┘ 1        └───────────────────┘
       │ has many
       ▼ *
┌──────────────┐ 1      * ┌───────────────────┐
│     Node     ├─────────►│       Edge        │
└──────┬───────┘          └───────────────────┘
       │ 1
       │ has optional
       ▼ 0..1
┌──────────────┐
│ SemanticMeta │
└──────────────┘
```

---

## 2. Entity Specifications

### A. Building
Represents a distinct physical campus or facility structure anchored to world coordinates.
- `id` (`VARCHAR(64)`): Unique building slug (e.g., `vit-ce`).
- `name` (`VARCHAR(255)`): Official name.
- `address` (`TEXT`): Full physical address.
- `category` (`VARCHAR(64)`): Classification (`college`, `hospital`, `commercial`).
- `latitude` / `longitude` (`DOUBLE PRECISION`): WGS84 GPS coordinate anchor.
- `metadata` (`JSONB`): Optional custom attributes.

### B. Floor
Represents a discrete vertical elevation layer within a building.
- `id` (`VARCHAR(64)`): Unique floor slug (e.g., `floor-1`).
- `building_id` (`VARCHAR(64)`): Foreign key referencing `buildings.id`.
- `floor_number` (`INTEGER`): Integer index (0 = Ground, 1 = First, -1 = Basement).
- `name` (`VARCHAR(100)`): Display name (e.g., "First Floor").
- `elevation` (`DOUBLE PRECISION`): Relative height in meters.
- `metadata` (`JSONB`): Wing or zone designations.

### C. Node (Spatial Graph Vertex)
Represents a point of interest, hallway waypoint, room doorway, or vertical transition.
- `id` (`VARCHAR(64)`): Unique node identifier (e.g., `lab-101`, `reception`).
- `floor_id` (`VARCHAR(64)`): Foreign key referencing `floors.id`.
- `name` (`VARCHAR(255)`): Human-readable name.
- `category` (`VARCHAR(64)`): Type (`entrance`, `service`, `corridor`, `laboratory`, `stairs`, `elevator`, `emergency_exit`).
- `x` (`DOUBLE PRECISION`): Local horizontal Cartesian position in meters.
- `y` (`DOUBLE PRECISION`): Local vertical Cartesian position in meters.
- `accessible` (`BOOLEAN`): True if wheelchair/step-free accessible.
- `metadata` (`JSONB`): Flexible metadata attributes.

### D. Edge (Spatial Graph Connection)
Represents a walkable corridor or physical connection between two nodes.
- `id` (`VARCHAR(64)`): Unique edge identifier (e.g., `edge-reception-corridor`).
- `start_node_id` (`VARCHAR(64)`): Foreign key referencing origin node.
- `end_node_id` (`VARCHAR(64)`): Foreign key referencing destination node.
- `distance` (`DOUBLE PRECISION`): Physical walking distance in meters.
- `bearing` (`DOUBLE PRECISION`): Heading angle from start to end ($0.0^\circ$ to $360.0^\circ$).
- `accessible` (`BOOLEAN`): Step-free path flag.
- `blocked` (`BOOLEAN`): Dynamic temporary obstruction flag.
- `metadata` (`JSONB`): Surface type (`tile`, `carpet`, `concrete`), incline percentage, width.

### E. SemanticMetadata (Knowledge Graph Entity)
Attaches human knowledge, operational details, and search synonyms to spatial entities.
- `id` (`UUID`): Primary key.
- `entity_id` (`VARCHAR(64)`): ID of the node, edge, floor, or building.
- `entity_type` (`VARCHAR(32)`): Enum (`node`, `edge`, `floor`, `building`).
- `tags` (`TEXT[]`): Keyword tags (`["computers", "ai", "study"]`).
- `aliases` (`TEXT[]`): Common synonyms (`["Software Lab 1", "Computer Lab 101"]`).
- `description` (`TEXT`): Human-readable context.
- `department` (`VARCHAR(128)`): Managing administrative unit.
- `operational_hours` (`VARCHAR(64)`): Hours of operation (`"08:00 - 18:00"`).
- `capacity` (`INTEGER`): Maximum seating/occupancy capacity.
- `custom_attributes` (`JSONB`): Extended attributes (e.g., `{"airConditioned": true}`).

### F. MapVersion (Immutable Graph Snapshot)
Stores point-in-time immutable graph snapshots for audit, comparison, and rollback.
- `id` (`UUID`): Primary key.
- `building_id` (`VARCHAR(64)`): Foreign key referencing `buildings.id`.
- `version_number` (`INTEGER`): Monotonically increasing version counter (`1, 2, 3...`).
- `version_tag` (`VARCHAR(32)`): Semantic tag (e.g., `"v1.0.0"`, `"initial-creator-walkthrough"`).
- `graph_snapshot` (`JSONB`): Complete serialized JSON state of all floors, nodes, edges, and semantic metadata at snapshot time.
- `change_summary` (`TEXT`): Creator/contributor notes on what changed.
- `created_by` (`VARCHAR(128)`): User identifier or contributor ID.
- `created_at` (`TIMESTAMPTZ`): Timestamp of creation.

---

## 3. PostgreSQL Database Schema Architecture

The database migration script `backend/sql/001_initial_schema.sql` creates these tables with proper indexes, constraints, and cascading rules.

### Performance Indexing Strategy
- Foreign key indexes: `idx_floors_building_id`, `idx_nodes_floor_id`, `idx_edges_start_node`, `idx_edges_end_node`.
- Spatial coordinate lookup: `idx_nodes_coordinates (x, y)`.
- Semantic search: GIN index on `semantic_metadata.tags` and `semantic_metadata.aliases`.
- Version history: `idx_map_versions_building_version (building_id, version_number)`.
