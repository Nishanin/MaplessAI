-- MapLess AI Initial Database Schema Migration
-- Migration 001: Initial Core Schema

-- 1. Buildings Table
CREATE TABLE IF NOT EXISTS buildings (
    id VARCHAR(64) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    address TEXT NOT NULL,
    category VARCHAR(64) NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 2. Floors Table
CREATE TABLE IF NOT EXISTS floors (
    id VARCHAR(64) PRIMARY KEY,
    building_id VARCHAR(64) NOT NULL REFERENCES buildings(id) ON DELETE CASCADE,
    floor_number INTEGER NOT NULL,
    name VARCHAR(100) NOT NULL,
    elevation DOUBLE PRECISION DEFAULT 0.0,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_building_floor UNIQUE (building_id, floor_number)
);

-- 3. Nodes Table (Spatial Graph Vertices)
CREATE TABLE IF NOT EXISTS nodes (
    id VARCHAR(64) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    category VARCHAR(64) NOT NULL,
    floor_id VARCHAR(64) NOT NULL REFERENCES floors(id) ON DELETE CASCADE,
    x DOUBLE PRECISION NOT NULL,
    y DOUBLE PRECISION NOT NULL,
    accessible BOOLEAN NOT NULL DEFAULT true,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 4. Edges Table (Spatial Graph Connections)
CREATE TABLE IF NOT EXISTS edges (
    id VARCHAR(64) PRIMARY KEY,
    start_node_id VARCHAR(64) NOT NULL REFERENCES nodes(id) ON DELETE CASCADE,
    end_node_id VARCHAR(64) NOT NULL REFERENCES nodes(id) ON DELETE CASCADE,
    distance DOUBLE PRECISION NOT NULL CHECK (distance >= 0),
    bearing DOUBLE PRECISION NOT NULL CHECK (bearing >= 0 AND bearing <= 360),
    accessible BOOLEAN NOT NULL DEFAULT true,
    blocked BOOLEAN NOT NULL DEFAULT false,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_edge_nodes_differ CHECK (start_node_id <> end_node_id)
);

-- 5. Semantic Metadata Table (Knowledge Graph Enrichment)
CREATE TABLE IF NOT EXISTS semantic_metadata (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_id VARCHAR(64) NOT NULL,
    entity_type VARCHAR(32) NOT NULL CHECK (entity_type IN ('node', 'edge', 'floor', 'building')),
    tags TEXT[] DEFAULT '{}',
    aliases TEXT[] DEFAULT '{}',
    description TEXT,
    department VARCHAR(128),
    operational_hours VARCHAR(64),
    capacity INTEGER CHECK (capacity >= 0),
    custom_attributes JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_entity_metadata UNIQUE (entity_id, entity_type)
);

-- 6. Map Versions Table (Piyush: Immutable Graph Snapshots)
CREATE TABLE IF NOT EXISTS map_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    building_id VARCHAR(64) NOT NULL REFERENCES buildings(id) ON DELETE CASCADE,
    version_number INTEGER NOT NULL CHECK (version_number > 0),
    version_tag VARCHAR(64) NOT NULL,
    graph_snapshot JSONB NOT NULL,
    change_summary TEXT NOT NULL,
    created_by VARCHAR(128) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_building_version UNIQUE (building_id, version_number)
);

-- Strategic Query Indexes
CREATE INDEX IF NOT EXISTS idx_floors_building_id ON floors(building_id);
CREATE INDEX IF NOT EXISTS idx_nodes_floor_id ON nodes(floor_id);
CREATE INDEX IF NOT EXISTS idx_edges_start_node ON edges(start_node_id);
CREATE INDEX IF NOT EXISTS idx_edges_end_node ON edges(end_node_id);
CREATE INDEX IF NOT EXISTS idx_semantic_metadata_entity ON semantic_metadata(entity_id, entity_type);
CREATE INDEX IF NOT EXISTS idx_semantic_metadata_tags ON semantic_metadata USING GIN(tags);
CREATE INDEX IF NOT EXISTS idx_semantic_metadata_aliases ON semantic_metadata USING GIN(aliases);
CREATE INDEX IF NOT EXISTS idx_map_versions_building ON map_versions(building_id, version_number DESC);
