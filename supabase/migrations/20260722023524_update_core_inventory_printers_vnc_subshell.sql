INSERT INTO scripts (name, filename, description, content, is_core, is_active, execution_order, version, organization_id)
VALUES (
    'Agente de Inventario OCS',
    'core_inventory.sh',
    'Configura OCS Inventory Agent (sem apt-get; pacote instalado em core_packages.sh).',
    $SeederScript$#!/bin/bash
# ============================================================================
# Core Script: core_inventory.sh
# SeederLinux Lite - OCS Inventory Agent (configuracao apenas)
# ============================================================================
# Configura o agente do OCS Inventory para coleta de inventario
# automatica da estacao. A instalacao de pacotes e feita no core_packages.sh.
# Os placeholders {{VARIAVEL}} sao substituidos automaticamente
# pelo sistema na geracao do bundle.
# ============================================================================

(
set -e

echo "============================================================"
echo "06 - Configurar OCS Inventory Agent"
echo "============================================================"

# ============================================================
# Variaveis
# ============================================================
INVENTORY_ENABLED="{{INVENTORY_ENABLED}}"
OCS_SERVER="{{OCS_SERVER}}"
OCS_TAG="{{OCS_TAG}}"
GLPI_SERVER="{{GLPI_SERVER}}"

echo ">>> Inventario habilitado: $INVENTORY_ENABLED"

# ============================================================
# Verificar se o inventario esta habilitado
# ============================================================
if [ "$INVENTORY_ENABLED" != "true" ]; then
    echo ">>> Inventario desativado. Pulando configuracao."
    echo ">>> [06] OCS Inventory desativado."
    echo "============================================================"
    exit 0
fi

if [ -z "$OCS_SERVER" ] || [ "$OCS_SERVER" = "" ]; then
    echo ">>> AVISO: OCS_SERVER nao definido. Pulando configuracao."
    echo ">>> [06] OCS Inventory nao configurado (servidor ausente)."
    echo "============================================================"
    exit 0
fi

echo ">>> Servidor OCS: $OCS_SERVER"
echo ">>> Tag OCS: $OCS_TAG"

# ============================================================
# Verificar se o pacote foi instalado (no core_packages.sh)
# ============================================================
if ! command -v ocsinventory-agent &>/dev/null; then
    echo ">>> AVISO: ocsinventory-agent nao instalado. Pulando configuracao."
    echo ">>> [06] OCS Inventory nao configurado (pacote ausente)."
    echo "============================================================"
    exit 0
fi

# ============================================================
# Configurar agente OCS
# ============================================================
echo ">>> Configurando agente OCS..."
mkdir -p /etc/ocsinventory-agent

cat > /etc/ocsinventory-agent/ocsinventory-agent.cfg <<EOF
# Configuracao do OCS Inventory Agent - SeederLinux
server = ${OCS_SERVER}
tag = ${OCS_TAG}
basepath = /var/lib/ocsinventory-agent
debug = 0
local = no
nosoftware = 0
verbose = 0
EOF

# Arquivo de configuracao para o modulo Perl
OCS_URL="http://${OCS_SERVER}/ocsinventory"
cat > /etc/ocsinventory-agent/modules.conf 2>/dev/null <<EOF
# Modulos do OCS Inventory Agent
OCS_MODE = HTTP
OCS_SERVER = ${OCS_SERVER}
OCS_TAG = ${OCS_TAG}
EOF

# Configurar cron para execucao periodica
echo ">>> Configurando cron do OCS..."
cat > /etc/cron.d/ocsinventory-agent <<EOF
# OCS Inventory Agent - SeederLinux
# Executa a cada 4 horas
0 */4 * * * root /usr/bin/ocsinventory-agent --server=${OCS_SERVER} --tag="${OCS_TAG}" --lazy 2>/dev/null
EOF
chmod 644 /etc/cron.d/ocsinventory-agent

# ============================================================
# Configurar GLPI (se disponivel)
# ============================================================
if [ -n "$GLPI_SERVER" ] && [ "$GLPI_SERVER" != "" ]; then
    echo ">>> Configurando integracao GLPI..."
    mkdir -p /etc/glpi-agent

    cat > /etc/glpi-agent/agent.cfg <<EOF
# Configuracao do GLPI Agent - SeederLinux
server = ${GLPI_SERVER}
tag = ${OCS_TAG}
EOF
fi

# ============================================================
# Execucao inicial do inventario
# ============================================================
echo ">>> Executando coleta inicial de inventario..."
ocsinventory-agent --server="$OCS_SERVER" --tag="$OCS_TAG" --lazy 2>/dev/null || {
    echo ">>> AVISO: Falha na coleta inicial. Sera refeito via cron."
}

echo ">>> [06] OCS Inventory configurado!"
echo "============================================================"
)
$SeederScript$,
    TRUE,
    TRUE,
    9,
    1,
    NULL
) ON CONFLICT (filename) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    content = EXCLUDED.content,
    execution_order = EXCLUDED.execution_order,
    version = EXCLUDED.version,
    is_active = EXCLUDED.is_active,
    updated_at = CURRENT_TIMESTAMP;

INSERT INTO scripts (name, filename, description, content, is_core, is_active, execution_order, version, organization_id)
VALUES (
    'Configuracao de Impressoras',
    'core_printers.sh',
    'Configura CUPS e impressoras via servidor remoto.',
    $SeederScript$#!/bin/bash
# ============================================================================
# Core Script: core_printers.sh
# SeederLinux Lite - CUPS e impressoras (configuracao apenas)
# ============================================================================
# Configura o CUPS e instala as impressoras compartilhadas via servidor
# de impressao. A instalacao de pacotes e feita no core_packages.sh.
# Os placeholders {{VARIAVEL}} sao substituidos automaticamente
# pelo sistema na geracao do bundle.
# ============================================================================

(
set -e

echo "============================================================"
echo "07 - Configurar CUPS e impressoras"
echo "============================================================"

# ============================================================
# Variaveis
# ============================================================
PRINT_SERVER="{{PRINT_SERVER}}"
DEFAULT_PRINTER="{{DEFAULT_PRINTER}}"
PRINTERS="{{PRINTERS}}"
DOMINIO="{{DOMINIO}}"

echo ">>> Servidor de impressao: $PRINT_SERVER"
echo ">>> Impressora padrao: $DEFAULT_PRINTER"

# ============================================================
# Verificar se ha servidor de impressao
# ============================================================
if [ -z "$PRINT_SERVER" ] || [ "$PRINT_SERVER" = "" ]; then
    echo ">>> AVISO: PRINT_SERVER nao definido. Pulando configuracao."
    echo ">>> [07] Impressoras nao configuradas (servidor ausente)."
    echo "============================================================"
    exit 0
fi

# ============================================================
# Verificar se o CUPS foi instalado (no core_packages.sh)
# ============================================================
if ! command -v cupsctl &>/dev/null; then
    echo ">>> AVISO: CUPS nao instalado. Pulando configuracao."
    echo ">>> [07] Impressoras nao configuradas (CUPS ausente)."
    echo "============================================================"
    exit 0
fi

# ============================================================
# Configurar CUPS
# ============================================================
echo ">>> Configurando CUPS..."

# Habilitar e iniciar CUPS
systemctl enable cups
systemctl start cups

# Permitir administracao remota e compartilhamento
cupsctl --remote-admin --remote-any --share-printers 2>/dev/null || true

# Configurar cupsd.conf
cat > /etc/cups/cupsd.conf <<EOF
# Configuracao CUPS - SeederLinux
Browsing On
BrowseLocalProtocols dnssd
DefaultAuthType Basic
WebInterface Yes

Listen localhost:631
Listen /run/cups/cups.sock

<Location />
    Order allow,deny
    Allow all
</Location>

<Location /admin>
    Order allow,deny
    Allow all
</Location>

<Location /admin/conf>
    AuthType Default
    Require user @SYSTEM
    Order allow,deny
    Allow all
</Location>
EOF

systemctl restart cups

# ============================================================
# Configurar impressoras via servidor CUPS remoto
# ============================================================
echo ">>> Configurando impressoras via servidor remoto..."

# Criar arquivo de configuracao client.conf do CUPS
cat > /etc/cups/client.conf <<EOF
# Cliente CUPS - SeederLinux
ServerName ${PRINT_SERVER}
EOF

# ============================================================
# Instalar cada impressora listada
# ============================================================
if [ -n "$PRINTERS" ] && [ "$PRINTERS" != "" ]; then
    echo ">>> Instalando impressoras listadas..."
    for PRINTER in $PRINTERS; do
        echo ">>> Configurando impressora: $PRINTER"
        # Adicionar impressora via lpadmin (IPP via servidor)
        lpadmin -p "$PRINTER" -E -v "ipp://${PRINT_SERVER}/printers/${PRINTER}" \
            -m everywhere 2>/dev/null || {
            echo ">>> AVISO: Falha ao adicionar impressora $PRINTER"
        }
    done
else
    echo ">>> Nenhuma impressora listada. Usando descoberta automatica."
    # Descoberta automatica via servidor remoto
    lpinfo -h "$PRINT_SERVER" -v 2>/dev/null | grep ipp | while read -r line; do
        PRINTER_URI=$(echo "$line" | awk '{print $2}')
        PRINTER_NAME=$(basename "$PRINTER_URI")
        echo ">>> Impressora encontrada: $PRINTER_NAME"
        lpadmin -p "$PRINTER_NAME" -E -v "$PRINTER_URI" -m everywhere 2>/dev/null || true
    done
fi

# ============================================================
# Definir impressora padrao
# ============================================================
if [ -n "$DEFAULT_PRINTER" ] && [ "$DEFAULT_PRINTER" != "" ]; then
    echo ">>> Definindo impressora padrao: $DEFAULT_PRINTER"
    lpadmin -d "$DEFAULT_PRINTER" 2>/dev/null || {
        echo ">>> AVISO: Falha ao definir impressora padrao"
    }
fi

# ============================================================
# Reiniciar CUPS para aplicar
# ============================================================
systemctl restart cups

echo ">>> [07] CUPS e impressoras configurados!"
echo "============================================================"
)
$SeederScript$,
    TRUE,
    TRUE,
    10,
    1,
    NULL
) ON CONFLICT (filename) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    content = EXCLUDED.content,
    execution_order = EXCLUDED.execution_order,
    version = EXCLUDED.version,
    is_active = EXCLUDED.is_active,
    updated_at = CURRENT_TIMESTAMP;

INSERT INTO scripts (name, filename, description, content, is_core, is_active, execution_order, version, organization_id)
VALUES (
    'Configuracao VNC',
    'core_vnc.sh',
    'Configura x11vnc para acesso remoto assistido.',
    $SeederScript$#!/bin/bash
# ============================================================================
# Core Script: core_vnc.sh
# SeederLinux Lite - x11vnc (configuracao apenas)
# ============================================================================
# Configura o x11vnc para suporte remoto, incluindo servico systemd e
# senha de acesso. A instalacao de pacotes e feita no core_packages.sh.
#
# SEGURANCA: A senha VNC e gravada em /etc/seederlinux/secrets.env
# (perm 600) e usada diretamente com x11vnc -storepasswd.
#
# Os placeholders {{VARIAVEL}} sao substituidos automaticamente
# pelo sistema na geracao do bundle.
# ============================================================================

(
set -e

echo "============================================================"
echo "08 - Configurar x11vnc"
echo "============================================================"

# ============================================================
# Variaveis
# ============================================================
VNC_ENABLED="{{VNC_ENABLED}}"
VNC_PASSWORD="{{VNC_PASSWORD}}"
DISPLAY_MANAGER="{{DISPLAY_MANAGER}}"

echo ">>> VNC habilitado: $VNC_ENABLED"

# ============================================================
# Verificar se VNC esta habilitado
# ============================================================
if [ "$VNC_ENABLED" != "true" ]; then
    echo ">>> VNC desativado. Pulando configuracao."
    echo ">>> [08] x11vnc desativado."
    echo "============================================================"
    exit 0
fi

# ============================================================
# Verificar se o x11vnc foi instalado (no core_packages.sh)
# ============================================================
if ! command -v x11vnc &>/dev/null; then
    echo ">>> AVISO: x11vnc nao instalado. Pulando configuracao."
    echo ">>> [08] x11vnc nao configurado (pacote ausente)."
    echo "============================================================"
    exit 0
fi

# ============================================================
# Detectar Display Manager se nao definido
# ============================================================
if [ -z "$DISPLAY_MANAGER" ] || [ "$DISPLAY_MANAGER" = "" ]; then
    if systemctl is-active --quiet lightdm 2>/dev/null; then DISPLAY_MANAGER="lightdm"
    elif systemctl is-active --quiet gdm3 2>/dev/null; then DISPLAY_MANAGER="gdm3"
    elif systemctl is-active --quiet sddm 2>/dev/null; then DISPLAY_MANAGER="sddm"
    else DISPLAY_MANAGER="lightdm"
    fi
    echo ">>> Display Manager detectado: $DISPLAY_MANAGER"
fi

# ============================================================
# Configurar senha do VNC (SEM expor em texto plano)
# ============================================================
echo ">>> Configurando senha do VNC..."
mkdir -p /etc/x11vnc
mkdir -p /etc/seederlinux

SECRETS_FILE="/etc/seederlinux/secrets.env"

if [ -n "$VNC_PASSWORD" ] && [ "$VNC_PASSWORD" != "" ]; then
    x11vnc -storepasswd "$VNC_PASSWORD" /etc/x11vnc/vncpasswd
    chmod 600 /etc/x11vnc/vncpasswd
    echo ">>> Senha VNC configurada (fornecida pela OM)"
    echo "VNC_PASSWORD_SET=true" >> "$SECRETS_FILE"
else
    echo ">>> VNC_PASSWORD nao definido. Gerando senha aleatoria."
    RANDOM_PASS=$(openssl rand -base64 12)
    x11vnc -storepasswd "$RANDOM_PASS" /etc/x11vnc/vncpasswd
    chmod 600 /etc/x11vnc/vncpasswd
    echo ">>> Senha VNC gerada com sucesso"
    echo "VNC_PASSWORD_SET=true" >> "$SECRETS_FILE"
fi

chmod 600 "$SECRETS_FILE" 2>/dev/null || true
unset VNC_PASSWORD
unset RANDOM_PASS

# ============================================================
# Criar servico systemd para x11vnc
# ============================================================
echo ">>> Criando servico systemd x11vnc..."

case "$DISPLAY_MANAGER" in
    lightdm)
        VNC_DISPLAY=":0"
        VNC_AUTH="/var/run/lightdm/root/:0"
        ;;
    gdm3)
        VNC_DISPLAY=":0"
        VNC_AUTH="/run/user/0/gdm/Xauthority"
        ;;
    sddm)
        VNC_DISPLAY=":0"
        VNC_AUTH="/var/run/sddm/:0"
        ;;
    *)
        VNC_DISPLAY=":0"
        VNC_AUTH="/tmp/.X0-lock"
        ;;
esac

cat > /etc/systemd/system/x11vnc.service <<EOF
[Unit]
Description=x11vnc Server - SeederLinux
After=display-manager.service
Requires=display-manager.service

[Service]
Type=simple
ExecStart=/usr/bin/x11vnc -display ${VNC_DISPLAY} -auth ${VNC_AUTH} -forever -loop -noxdamage -repeat -rfbauth /etc/x11vnc/vncpasswd -rfbport 5900 -shared -bg -o /var/log/x11vnc.log
ExecStop=/usr/bin/killall x11vnc
Restart=on-failure
RestartSec=5

[Install]
WantedBy=graphical.target
EOF

systemctl daemon-reload
systemctl enable x11vnc.service
systemctl start x11vnc.service 2>/dev/null || {
    echo ">>> AVISO: Nao foi possivel iniciar x11vnc agora."
    echo ">>> O servico sera iniciado apos o display manager."
}

echo ">>> [08] x11vnc configurado!"
echo "============================================================"
)
$SeederScript$,
    TRUE,
    TRUE,
    11,
    1,
    NULL
) ON CONFLICT (filename) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    content = EXCLUDED.content,
    execution_order = EXCLUDED.execution_order,
    version = EXCLUDED.version,
    is_active = EXCLUDED.is_active,
    updated_at = CURRENT_TIMESTAMP;