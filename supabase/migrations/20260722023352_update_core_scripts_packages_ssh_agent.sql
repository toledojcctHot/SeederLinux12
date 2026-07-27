INSERT INTO scripts (name, filename, description, content, is_core, is_active, execution_order, version, organization_id)
VALUES (
    'Instalacao de Pacotes',
    'core_packages.sh',
    'Instala TODOS os pacotes necessarios (sistema, OCS, CUPS, VNC, Conky, Java, etc).',
    $SeederScript$#!/bin/bash
# ============================================================================
# Core Script: core_packages.sh
# SeederLinux Lite - Instalar pacotes essenciais
# ============================================================================
# Instala todos os pacotes necessarios para o funcionamento da estacao:
# ferramentas de rede, autenticacao, sistema grafico, utilitarios.
# Os placeholders {{VARIAVEL}} são substituídos automaticamente
# pelo sistema na geração do bundle.
# ============================================================================

set -e

echo "============================================================"
echo "03 - Instalar pacotes essenciais"
echo "============================================================"

# ============================================================
# Variáveis
# ============================================================
DESKTOP_ENV="{{DESKTOP_ENV}}"
INSTALL_DESKTOP="{{INSTALL_DESKTOP}}"

echo ">>> Ambiente grafico solicitado (opcional): $DESKTOP_ENV"
echo ">>> Instalar ambiente grafico: $INSTALL_DESKTOP"

# ============================================================
# Detectar ambiente grafico ja instalado
# ============================================================
detectar_de() {
    if command -v cinnamon-session &>/dev/null; then echo "cinnamon"
    elif command -v mate-session &>/dev/null; then echo "mate"
    elif command -v gnome-session &>/dev/null; then echo "gnome"
    elif command -v startxfce4 &>/dev/null; then echo "xfce"
    elif command -v startplasma-x11 &>/dev/null; then echo "kde"
    elif command -v startlxde &>/dev/null; then echo "lxde"
    else echo "unknown"
    fi
}

detectar_dm() {
    if systemctl is-active --quiet lightdm 2>/dev/null; then echo "lightdm"
    elif systemctl is-active --quiet gdm3 2>/dev/null; then echo "gdm3"
    elif systemctl is-active --quiet sddm 2>/dev/null; then echo "sddm"
    elif [ -f /etc/X11/default-display-manager ]; then
        basename "$(cat /etc/X11/default-display-manager)"
    else echo "unknown"
    fi
}

DETECTED_DE="$(detectar_de)"
DETECTED_DM="$(detectar_dm)"
export DETECTED_DE DETECTED_DM

echo ">>> DE detectado na estacao: $DETECTED_DE"
echo ">>> DM detectado na estacao: $DETECTED_DM"

# ============================================================
# Atualizar sistema
# ============================================================
echo ">>> Atualizando pacotes do sistema..."
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get -y upgrade

# ============================================================
# Pacotes base do sistema
# ============================================================
echo ">>> Instalando pacotes base..."
BASE_PACKAGES=(
    wget
    curl
    gnupg
    ca-certificates
    lsb-release
    apt-transport-https
    software-properties-common
    unzip
    rsync
    htop
    vim
    nano
    less
    bash-completion
    net-tools
    dnsutils
    iproute2
    iputils-ping
    traceroute
    nmap
    tcpdump
    openssh-server
    openssh-client
    cifs-utils
    nfs-common
    smbclient
    policykit-1
    udisks2
    gvfs-backends
    gvfs-fuse
    fuse3
    libnotify-bin
    dbus-x11
    xdg-utils
    fonts-liberation
    fonts-noto
    fonts-noto-cjk
    fontconfig
)

apt-get install -y "${BASE_PACKAGES[@]}"

# ============================================================
# Pacotes de autenticacao (AD/Kerberos/SSSD)
# ============================================================
echo ">>> Instalando pacotes de autenticacao..."
AUTH_PACKAGES=(
    krb5-user
    samba
    samba-common
    samba-common-bin
    sssd
    sssd-tools
    sssd-krb5
    sssd-krb5-common
    libnss-sss
    libpam-sss
    adcli
    realmd
    oddjob
    oddjob-mkhomedir
    packagekit
    network-manager
    network-manager-gnome
)

apt-get install -y "${AUTH_PACKAGES[@]}"

# ============================================================
# Pacotes do ambiente grafico (OPCIONAL)
# ============================================================
# Por padrao NAO instala DE. Somente instala se INSTALL_DESKTOP=true
# e DESKTOP_ENV estiver definido. Caso contrario, usa o ambiente
# grafico ja presente na estacao (detectado em DETECTED_DE).
if [ "$INSTALL_DESKTOP" = "true" ] && [ -n "$DESKTOP_ENV" ] && [ "$DESKTOP_ENV" != "" ]; then
    echo ">>> Instalando ambiente grafico solicitado: $DESKTOP_ENV"
    case "$DESKTOP_ENV" in
        cinnamon)
            apt-get install -y cinnamon cinnamon-core lightdm
            ;;
        mate)
            apt-get install -y mate mate-core mate-desktop-environment lightdm
            ;;
        gnome)
            apt-get install -y gnome gnome-core gdm3
            ;;
        xfce)
            apt-get install -y xfce4 xfce4-goodies lightdm
            ;;
        kde)
            apt-get install -y kde-plasma-desktop sddm
            ;;
        lxde)
            apt-get install -y lxde lightdm
            ;;
        *)
            echo ">>> AVISO: Ambiente grafico nao reconhecido: $DESKTOP_ENV"
            echo ">>> Nenhum DE sera instalado. Usando o ja presente: $DETECTED_DE"
            ;;
    esac
else
    echo ">>> INSTALL_DESKTOP != true. Nao instalando DE."
    echo ">>> Utilizando ambiente grafico ja presente: $DETECTED_DE"
fi

# ============================================================
# Garantir repositorio universe (necessario para ocsinventory-agent no Mint/Ubuntu)
# ============================================================
echo ">>> Garantindo repositorio universe..."
if command -v add-apt-repository &>/dev/null; then
    add-apt-repository -y universe 2>/dev/null || true
fi
apt-get update -qq

# ============================================================
# Pacotes complementares
# ============================================================
echo ">>> Instalando pacotes complementares..."
EXTRA_PACKAGES=(
    cups
    cups-client
    system-config-printer
    x11vnc
    conky-all
    jq
    dmidecode
    openjdk-8-jre
    gimp
    vlc
    evince
    file-roller
    gparted
    gnome-screenshot
    xbacklight
    pavucontrol
    pulseaudio
    pulseaudio-utils
    alsa-utils
    intel-microcode
    amd64-microcode
    acpi
    acpid
    powermgmt-base
    upower
    colord
    geoclue-2.0
)

apt-get install -y "${EXTRA_PACKAGES[@]}" || true

# ============================================================
# OCS Inventory Agent (pacote critico para inventario)
# Instalado separadamente para garantir verificacao e diagnostico
# ============================================================
echo ">>> Instalando OCS Inventory Agent..."
if ! apt-get install -y ocsinventory-agent 2>/dev/null; then
    echo ">>> AVISO: Falha ao instalar ocsinventory-agent."
    echo ">>> Verifique se o repositorio universe esta habilitado."
    echo ">>> Comando manual: sudo add-apt-repository universe && sudo apt-get update && sudo apt-get install -y ocsinventory-agent"
else
    echo ">>> OCS Inventory Agent instalado com sucesso"
fi

# Firefox ESR com fallback para firefox
apt-get install -y firefox-esr firefox-esr-l10n-pt-br 2>/dev/null || \
    apt-get install -y firefox firefox-l10n-pt-br 2>/dev/null || true

# Firmware opcional (varia por distro)
apt-get install -y firmware-linux 2>/dev/null || true
apt-get install -y firmware-linux-nonfree 2>/dev/null || true

# ============================================================
# Detectar GPU e instalar drivers
# ============================================================
echo ">>> Detectando placa de video..."
if lspci | grep -qi nvidia; then
    echo ">>> Placa NVIDIA detectada. Instalando drivers..."
    apt-get install -y nvidia-driver-550 2>/dev/null || {
        echo ">>> AVISO: Falha ao instalar driver NVIDIA. Tentando ubuntu-drivers..."
        ubuntu-drivers autoinstall 2>/dev/null || true
    }
elif lspci | grep -qi amd; then
    echo ">>> Placa AMD detectada. Instalando drivers..."
    apt-get install -y mesa-utils xserver-xorg-video-amdgpu 2>/dev/null || true
else
    echo ">>> GPU NVIDIA/AMD nao detectada. Usando driver generico."
fi

# ============================================================
# Remover LibreOffice (opcional)
# ============================================================
if [ "{{REMOVER_LIBREOFFICE}}" = "true" ]; then
    echo ">>> Removendo LibreOffice..."
    apt-get remove --purge -y libreoffice* libreoffice-core libreoffice-common
fi

# ============================================================
# Limpar cache do APT
# ============================================================
echo ">>> Limpando cache do APT..."
apt-get clean
apt-get autoremove -y

echo ">>> [03] Pacotes essenciais instalados!"
echo "============================================================"
$SeederScript$,
    TRUE,
    TRUE,
    3,
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
    'Configuracao SSH',
    'core_ssh.sh',
    'Configura porta SSH e AllowGroups apos ingresso no AD.',
    $SeederScript$#!/bin/bash
# ============================================================================
# Core Script: core_ssh.sh
# SeederLinux Lite - Configuracao SSH (porta, AllowGroups)
# Executado APOS o ingresso no AD para que os grupos do dominio existam.
# ============================================================================

set -e

echo "============================================================"
echo "07 - Configurar SSH"
echo "============================================================"

SSH_PORT="{{SSH_PORT}}"
SSH_GROUPS="{{SSH_GROUPS}}"

echo ">>> Porta SSH: ${SSH_PORT:-22}"
echo ">>> Grupos SSH: ${SSH_GROUPS:-nenhum}"

# Configurar porta
if [ -n "$SSH_PORT" ] && [ "$SSH_PORT" != "" ] && [ "$SSH_PORT" != "22" ]; then
    echo ">>> Configurando porta SSH: $SSH_PORT"
    if [ -f /etc/ssh/sshd_config ]; then
        cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.$(date +%Y%m%d%H%M%S) 2>/dev/null || true
        sed -i "s/^#*Port .*/Port $SSH_PORT/" /etc/ssh/sshd_config
        echo ">>> Porta SSH alterada para $SSH_PORT"
    fi
fi

# Configurar AllowGroups
if [ -n "$SSH_GROUPS" ] && [ "$SSH_GROUPS" != "" ]; then
    echo ">>> Configurando AllowGroups: $SSH_GROUPS"
    if [ -f /etc/ssh/sshd_config ]; then
        IFS=$'\n,' read -ra GRP_ARRAY <<< "$SSH_GROUPS"
        GRP_LIST=""
        for GRP in "${GRP_ARRAY[@]}"; do
            GRP=$(echo "$GRP" | xargs)
            if [ -n "$GRP" ] && [ "$GRP" != "" ]; then
                if [ -z "$GRP_LIST" ]; then
                    GRP_LIST="$GRP"
                else
                    GRP_LIST="$GRP_LIST $GRP"
                fi
            fi
        done
        if [ -n "$GRP_LIST" ]; then
            sed -i "s/^#*AllowGroups .*/AllowGroups $GRP_LIST/" /etc/ssh/sshd_config
            if ! grep -q "^AllowGroups " /etc/ssh/sshd_config; then
                echo "AllowGroups $GRP_LIST" >> /etc/ssh/sshd_config
            fi
            echo ">>> AllowGroups configurado: $GRP_LIST"
        fi
    fi
fi

# Reiniciar SSH
if [ -f /etc/ssh/sshd_config ]; then
    systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null || true
fi

echo ">>> [07] SSH configurado!"
echo "============================================================"
$SeederScript$,
    TRUE,
    TRUE,
    7,
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
    'Agente de Check-in',
    'core_agent.sh',
    'Baixa e instala o agente de check-in periodico (cron a cada 15 min).',
    $SeederScript$#!/bin/bash
# ============================================================================
# Core Script: core_agent.sh
# SeederLinux Lite - Instalacao do agente de check-in periodico
# ============================================================================
# Baixa o agent.py do servidor, configura cron a cada 15 minutos e
# executa o primeiro check-in em background.
# ============================================================================

set -e

echo "============================================================"
echo "18 - Instalar agente de check-in (seeder-agent)"
echo "============================================================"

INSTALL_AGENT="{{INSTALL_AGENT}}"
if [ "$INSTALL_AGENT" != "true" ]; then
    echo ">>> Instalacao do agente desativada (INSTALL_AGENT=false). Pulando."
    echo "============================================================"
    return 0
fi

SEEDER_SERVER="{{SEEDER_SERVER}}"
OM_ACRONYM="{{OM_ACRONYM}}"
AGENT_NO_CHECK_CERT="{{AGENT_NO_CHECK_CERT}}"

echo ">>> Servidor: $SEEDER_SERVER"
echo ">>> Organizacao: $OM_ACRONYM"

# Baixar o agente
mkdir -p /usr/local/bin
if wget -q -O /usr/local/bin/seeder-agent "${SEEDER_SERVER}/downloads/agent.py"; then
    chmod 755 /usr/local/bin/seeder-agent
    echo ">>> Agente baixado com sucesso"
else
    echo ">>> ERRO: Falha ao baixar o agente. Verifique conectividade com $SEEDER_SERVER"
    echo "============================================================"
    return 1
fi

# Criar configuracao
mkdir -p /etc/seeder
cat > /etc/seeder/agent.conf <<EOF
[server]
url = ${SEEDER_SERVER}
no_check_certificate = ${AGENT_NO_CHECK_CERT}
EOF

# Configurar cron
cat > /etc/cron.d/seeder-agent <<EOF
# SeederLinux Agent - check-in a cada 15 minutos
*/15 * * * * root /usr/local/bin/seeder-agent --no-check-certificate >> /var/log/seeder/agent.log 2>&1
EOF

# Primeiro check-in (em background, sem bloquear o bundle)
echo ">>> Executando primeiro check-in em background..."
nohup /usr/local/bin/seeder-agent --org "$OM_ACRONYM" --no-check-certificate > /tmp/seeder-first-checkin.log 2>&1 &

echo ">>> [18] Agente instalado e agendado!"
echo "============================================================"
$SeederScript$,
    TRUE,
    TRUE,
    20,
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