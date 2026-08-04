/*
# Add missing variable definitions

These variables are used in scripts but missing from variable_definitions
in the database, causing them to not be resolved during placeholder substitution.

Variables to add:
- DISPLAY_MANAGER (order 91)
- SSH_PORT (order 121)
- INSTALL_ONLYOFFICE (order 110)
- SEEDER_SERVER (order 140)
- AGENT_NO_CHECK_CERT (order 151)
- INSTALL_DESKTOP (order 92)
- DC_IP_LIST (order 93)
- ADMIN_USERNAME (order 94)
- INSTALL_CHROME (order 111)
- INSTALL_CHROMIUM (order 112)
- SSH_GROUPS (order 124)
- JAVA_EXCEPTIONS (order 116)
- CERTIFICATE_BUNDLE (order 130)
- CERTIFICATE_AUTO_INSTALL (order 131)
- DC_SECUNDARIO_IP (order 4)
- INSTALL_PASSWORD_CHANGER (order 115)
- REMOVER_LIBREOFFICE (order 117)
- REMOTE_METHOD (order 120)
*/

INSERT INTO variable_definitions (name, placeholder, description, type, category, is_required, default_value, display_order) VALUES
('DISPLAY_MANAGER', '{{DISPLAY_MANAGER}}', 'Gerenciador de sessao: lightdm, gdm3, sddm (opcional, detectado automaticamente se vazio)', 'select', 'ambiente', FALSE, '', 91),
('SSH_PORT', '{{SSH_PORT}}', 'Porta SSH (padrao: 22)', 'port', 'acesso_remoto', FALSE, '22', 121),
('INSTALL_ONLYOFFICE', '{{INSTALL_ONLYOFFICE}}', 'Instalar OnlyOffice Desktop Editors?', 'boolean', 'aplicacoes', FALSE, 'true', 110),
('SEEDER_SERVER', '{{SEEDER_SERVER}}', 'URL base do servidor SeederLinux para check-in do agente. Configure este FQDN no DNS ou adicione ao /etc/hosts das estacoes.', 'url', 'rede', FALSE, 'https://seederlinux.om.local', 140),
('AGENT_NO_CHECK_CERT', '{{AGENT_NO_CHECK_CERT}}', 'Permitir certificado autoassinado no agente', 'boolean', 'agente', FALSE, 'true', 151),
('INSTALL_DESKTOP', '{{INSTALL_DESKTOP}}', 'Instalar ambiente grafico? Se false, usa o ja instalado na estacao', 'boolean', 'ambiente', FALSE, 'false', 92),
('DC_IP_LIST', '{{DC_IP_LIST}}', 'Lista de IPs dos Controladores de Dominio (separados por virgula ou espaco)', 'string', 'dominio', FALSE, '10.0.0.1,10.0.0.2', 93),
('ADMIN_USERNAME', '{{ADMIN_USERNAME}}', 'Nome do usuario administrador do dominio para ingresso no AD', 'string', 'dominio', FALSE, 'Administrator', 94),
('INSTALL_CHROME', '{{INSTALL_CHROME}}', 'Instalar Google Chrome?', 'boolean', 'aplicacoes', FALSE, 'true', 111),
('INSTALL_CHROMIUM', '{{INSTALL_CHROMIUM}}', 'Instalar Chromium?', 'boolean', 'aplicacoes', FALSE, 'false', 112),
('SSH_GROUPS', '{{SSH_GROUPS}}', 'Grupos do dominio com acesso SSH (um por linha)', 'array', 'seguranca', FALSE, 'linux-admins', 124),
('JAVA_EXCEPTIONS', '{{JAVA_EXCEPTIONS}}', 'Excecoes de seguranca para Java (URLs autorizadas)', 'array', 'seguranca', FALSE, '', 116),
('CERTIFICATE_BUNDLE', '{{CERTIFICATE_BUNDLE}}', 'URL para download do pacote de certificados CA institucionais (formato .tar.gz). Deixe vazio se nao houver certificados personalizados.', 'url', 'oculto', FALSE, '', 130),
('CERTIFICATE_AUTO_INSTALL', '{{CERTIFICATE_AUTO_INSTALL}}', 'Instalar certificados automaticamente', 'boolean', 'certificados', FALSE, 'true', 131),
('DC_SECUNDARIO_IP', '{{DC_SECUNDARIO_IP}}', 'IP do Controlador de Dominio secundario', 'ip', 'dominio', FALSE, '10.0.0.2', 4),
('INSTALL_PASSWORD_CHANGER', '{{INSTALL_PASSWORD_CHANGER}}', 'Instalar aplicativo grafico (Zeny) para troca de senha no AD', 'boolean', 'aplicacoes', FALSE, 'true', 115),
('REMOVER_LIBREOFFICE', '{{REMOVER_LIBREOFFICE}}', 'Remover LibreOffice pre-instalado', 'boolean', 'aplicacoes', FALSE, 'false', 117),
('REMOTE_METHOD', '{{REMOTE_METHOD}}', 'Metodo de acesso remoto (ssh, xrdp, anydesk)', 'select', 'acesso_remoto', FALSE, 'ssh', 120)
ON CONFLICT (name) DO NOTHING;

-- Seed default values for all existing organizations
INSERT INTO organization_variables (organization_id, variable_id, value)
SELECT o.id, vd.id, COALESCE(vd.default_value, '')
FROM organizations o
CROSS JOIN variable_definitions vd
WHERE vd.name IN (
    'DISPLAY_MANAGER', 'SSH_PORT', 'INSTALL_ONLYOFFICE', 'SEEDER_SERVER',
    'AGENT_NO_CHECK_CERT', 'INSTALL_DESKTOP', 'DC_IP_LIST', 'ADMIN_USERNAME',
    'INSTALL_CHROME', 'INSTALL_CHROMIUM', 'SSH_GROUPS', 'JAVA_EXCEPTIONS',
    'CERTIFICATE_BUNDLE', 'CERTIFICATE_AUTO_INSTALL', 'DC_SECUNDARIO_IP',
    'INSTALL_PASSWORD_CHANGER', 'REMOVER_LIBREOFFICE', 'REMOTE_METHOD'
)
ON CONFLICT (organization_id, variable_id) DO NOTHING;
