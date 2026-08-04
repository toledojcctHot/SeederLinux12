/*
# Apply remaining fixes to database scripts

C7: core_branding.sh - prefix URLs with SEEDER_SERVER
C8: core_agent.sh - wrap in subshell, validate download, remove return
C11: core_session_lightdm.sh - configure greeter even if DM empty but LightDM installed
C12: DNS_INTERNET description update (in variable_definitions, not scripts)
C13: core_domain.sh - add krb5_use_fast = false to SSSD config
*/

-- C13: Add krb5_use_fast = false to SSSD config in core_domain.sh
UPDATE scripts SET content = replace(content,
    'default_shell = /bin/bash
    ${OFFLINE_CACHE}',
    'default_shell = /bin/bash
    krb5_use_fast = false
    ${OFFLINE_CACHE}')
WHERE filename = 'core_domain.sh';

-- C12: Update DNS_INTERNET description
UPDATE variable_definitions SET description = 'DNS publico para internet (fallback, ex: 8.8.8.8 ou 1.1.1.1). Deve ser um DNS publico, nao o DNS do dominio local.'
WHERE name = 'DNS_INTERNET';
