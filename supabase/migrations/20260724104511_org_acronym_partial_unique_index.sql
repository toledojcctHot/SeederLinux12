
-- Drop the global unique constraint on acronym
ALTER TABLE organizations DROP CONSTRAINT IF EXISTS organizations_acronym_key;

-- Create a partial unique index: only enforce uniqueness for active organizations
CREATE UNIQUE INDEX IF NOT EXISTS idx_organizations_acronym_active
  ON organizations (acronym)
  WHERE is_active = TRUE;
