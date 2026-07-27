
-- Backfill organization_variables for any variable_definitions rows
-- that existing organizations are missing. Safe to re-run (ON CONFLICT DO NOTHING).
INSERT INTO organization_variables (organization_id, variable_id, value)
SELECT o.id, vd.id, COALESCE(vd.default_value, '')
FROM organizations o
CROSS JOIN variable_definitions vd
WHERE o.is_active = TRUE
ON CONFLICT (organization_id, variable_id) DO NOTHING;
