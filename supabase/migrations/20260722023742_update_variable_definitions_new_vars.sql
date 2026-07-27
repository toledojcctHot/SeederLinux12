-- ============================================================================
-- Update variable_definitions for REMOVER_LIBREOFFICE, INSTALL_AGENT, AGENT_NO_CHECK_CERT
-- ============================================================================

-- REMOVER_LIBREOFFICE: update description, keep category 'aplicacoes', set display_order 57
UPDATE variable_definitions
SET description = 'Remover LibreOffice pre-instalado',
    category = 'aplicacoes',
    display_order = 57,
    default_value = 'false',
    is_required = false
WHERE name = 'REMOVER_LIBREOFFICE';

-- INSTALL_AGENT: move to new category 'agente', set display_order 58
UPDATE variable_definitions
SET description = 'Instalar agente de check-in periodico',
    category = 'agente',
    display_order = 58,
    default_value = 'true',
    is_required = false
WHERE name = 'INSTALL_AGENT';

-- AGENT_NO_CHECK_CERT: move to new category 'agente', set display_order 59, default true
UPDATE variable_definitions
SET description = 'Permitir certificado autoassinado no agente',
    category = 'agente',
    display_order = 59,
    default_value = 'true',
    is_required = false
WHERE name = 'AGENT_NO_CHECK_CERT';