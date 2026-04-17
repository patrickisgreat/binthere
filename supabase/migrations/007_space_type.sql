-- 007_space_type.sql
-- Adds a space_type column to households so users can create different
-- kinds of spaces (home, warehouse, office, studio, storage unit, custom).

ALTER TABLE households ADD COLUMN IF NOT EXISTS space_type TEXT NOT NULL DEFAULT 'home';
