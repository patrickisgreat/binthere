-- 006_zone_locations.sql
-- Adds a locations array to zones for sub-locations (shelves, areas, spots).
-- Bins within a zone can select from these predefined locations.

ALTER TABLE zones ADD COLUMN IF NOT EXISTS locations TEXT[] NOT NULL DEFAULT '{}';
