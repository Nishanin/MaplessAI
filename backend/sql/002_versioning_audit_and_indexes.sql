-- MapLess AI Database Schema Migration
-- Migration 002: Versioning Audit, Parent Version Tracking, and Indexes
-- Owner: Piyush (Map Versioning)

-- Add parent_version_id to link versions (e.g. for rollbacks or branching)
ALTER TABLE map_versions 
    ADD COLUMN IF NOT EXISTS parent_version_id UUID REFERENCES map_versions(id) ON DELETE SET NULL;

-- Add publication and lifecycle status columns
ALTER TABLE map_versions 
    ADD COLUMN IF NOT EXISTS status VARCHAR(32) NOT NULL DEFAULT 'published';

ALTER TABLE map_versions 
    ADD COLUMN IF NOT EXISTS published_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE map_versions 
    ADD COLUMN IF NOT EXISTS published_by VARCHAR(128);

-- Additional query performance indexes for timeline and lineage lookups
CREATE INDEX IF NOT EXISTS idx_map_versions_building_created 
    ON map_versions(building_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_map_versions_building_parent 
    ON map_versions(building_id, parent_version_id);

-- Down Migration (Documentation & Rollback Reference)
-- DROP INDEX IF EXISTS idx_map_versions_building_parent;
-- DROP INDEX IF EXISTS idx_map_versions_building_created;
-- ALTER TABLE map_versions DROP COLUMN IF EXISTS published_by;
-- ALTER TABLE map_versions DROP COLUMN IF EXISTS published_at;
-- ALTER TABLE map_versions DROP COLUMN IF EXISTS status;
-- ALTER TABLE map_versions DROP COLUMN IF EXISTS parent_version_id;
