
-- ============================================================
-- T3: Remove INSTALL_LEGADOS completely
-- ============================================================
DELETE FROM organization_variables
WHERE variable_id = (SELECT id FROM variable_definitions WHERE name = 'INSTALL_LEGADOS');

DELETE FROM variable_definitions WHERE name = 'INSTALL_LEGADOS';

-- Also replace any remaining {{INSTALL_LEGADOS}} in scripts (safety net)
UPDATE scripts
SET content = replace(content, '{{INSTALL_LEGADOS}}', 'false')
WHERE content LIKE '%{{INSTALL_LEGADOS}}%';

-- ============================================================
-- T2: Fix THEME default to DEFAULT
-- ============================================================
UPDATE variable_definitions
SET default_value = 'DEFAULT'
WHERE name = 'THEME';

UPDATE organization_variables
SET value = 'DEFAULT'
WHERE variable_id = (SELECT id FROM variable_definitions WHERE name = 'THEME')
  AND (value = 'Adwaita' OR value = '');

-- ============================================================
-- T4: Improve CERTIFICATE_BUNDLE description and move to advanced category
-- ============================================================
UPDATE variable_definitions
SET description = 'URL para download do pacote de certificados CA institucionais (formato .tar.gz ou .crt). Deixe vazio se nao houver certificados personalizados.',
    category    = 'certificados'
WHERE name = 'CERTIFICATE_BUNDLE';

-- ============================================================
-- T5 safety: ensure no {{VARIAVEL}} remains in DB scripts
-- ============================================================
UPDATE scripts
SET content = replace(content, '{{VARIAVEL}}', 'VARIAVEL')
WHERE content LIKE '%{{VARIAVEL}}%';
