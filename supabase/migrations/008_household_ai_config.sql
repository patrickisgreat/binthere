-- 008_household_ai_config.sql
-- Moves the AI provider + API key from per-user UserDefaults to a shared
-- household-scoped config. One key + one provider per household; all
-- members can read (via the existing "Members can view their households"
-- SELECT policy), only owners can write (via the existing "Owners can
-- update their households" UPDATE policy).

ALTER TABLE households ADD COLUMN IF NOT EXISTS ai_provider TEXT NOT NULL DEFAULT 'anthropic';
ALTER TABLE households ADD COLUMN IF NOT EXISTS api_key TEXT;
