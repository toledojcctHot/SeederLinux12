/*
# Add missing variables + hide CERTIFICATE_BUNDLE

1. New variable_definitions
- REMOVER_LIBREOFFICE (boolean, Aplicacoes, default 'false')
- INSTALL_AGENT (boolean, Agente, default 'true')
- AGENT_NO_CHECK_CERT (boolean, Agente, default 'true')
2. Modified variable_definitions
- CERTIFICATE_BUNDLE moved to category 'oculto' (hidden from UI)
3. Data backfill
- For every active organization, create organization_variables rows
  for the 3 new variables with their default_value, where not already present.
4. Important notes
- The substituir_placeholders() function already uses LEFT JOIN with
  COALESCE(ov.value, vd.default_value, '') fallback, so these variables
  will resolve correctly in bundles even for orgs without explicit rows.
- The organization_variables backfill ensures the variables also appear
  in the # === VARIAVEIS === export section of generated bundles.
*/

INSERT INTO variable_definitions (name, placeholder, description, type, category, is_required, default_value, display_order)
VALUES
    ('REMOVER_LIBREOFFICE', 'REMOVER_LIBREOFFICE', 'Remover LibreOffice pre-instalado', 'boolean', 'aplicacoes', FALSE, 'false', 116),
    ('INSTALL_AGENT', 'INSTALL_AGENT', 'Instalar agente de check-in periodico', 'boolean', 'agente', FALSE, 'true', 150),
    ('AGENT_NO_CHECK_CERT', 'AGENT_NO_CHECK_CERT', 'Permitir certificado autoassinado no agente', 'boolean', 'agente', FALSE, 'true', 151)
ON CONFLICT (name) DO NOTHING;

-- Move CERTIFICATE_BUNDLE to hidden category so it does not clutter the UI
UPDATE variable_definitions
SET category = 'oculto'
WHERE name = 'CERTIFICATE_BUNDLE';

-- Backfill: create organization_variables rows for all active orgs
INSERT INTO organization_variables (organization_id, variable_id, value)
SELECT o.id, vd.id, vd.default_value
FROM organizations o
CROSS JOIN variable_definitions vd
WHERE o.is_active = TRUE
  AND vd.name IN ('REMOVER_LIBREOFFICE', 'INSTALL_AGENT', 'AGENT_NO_CHECK_CERT')
  AND NOT EXISTS (
      SELECT 1 FROM organization_variables ov
      WHERE ov.organization_id = o.id
        AND ov.variable_id = vd.id
  );
