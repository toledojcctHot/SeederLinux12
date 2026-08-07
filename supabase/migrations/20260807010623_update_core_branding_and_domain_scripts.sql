/*
# Update core_branding.sh and core_domain.sh scripts

1. Purpose
   - Fix #1: core_branding.sh URL prefixing loop was producing truncated URLs
     (http:///assets/...) when SEEDER_SERVER was empty or the URL was relative.
     Replaced the case-based prefixing with a grep-based check that skips
     already-absolute URLs and correctly prepends SEEDER_SERVER.
   - Fix #2: core_domain.sh domain join block now detects if the machine
     is already joined (via `realm list`) and prompts to remove + rejoin.
     The `net ads join` fallback now uses DC_FQDN (dc-<acronym>.<domain>)
     instead of the NetBIOS name that DNS cannot resolve.

2. Tables modified
   - scripts: updates content for core_branding.sh and core_domain.sh
     (ON CONFLICT filename DO UPDATE). No schema changes.

3. Security
   - No RLS or policy changes.

4. Notes
   - Only the two affected scripts are updated. All other scripts, OMs,
     groups, and default values remain untouched.
*/

INSERT INTO scripts (name, filename, description, content, is_core, is_active, execution_order, version, organization_id)
VALUES (
    'Ingresso em Dominio AD',
    'core_domain.sh',
    'Ingressa a estacao no Active Directory (SSSD/Winbind com fallback).',
    $SeederScript$#!/bin/bash
# ============================================================================
# Core Script: core_domain.sh
# SeederLinux Lite - Ingresso no AD (SSSD/Winbind)
# ============================================================================
# Configura Kerberos, Samba, SSSD, PAM, NSS, sudo e mkhomedir para
# ingressar a estacao no dominio Active Directory.
# Os placeholders VARIAVEL são substituídos automaticamente
# pelo sistema na geração do bundle.
# ============================================================================

set -e

echo "============================================================"
echo "04 - Ingresso no Active Directory"
echo "============================================================"

# ============================================================
# Variáveis
# ============================================================
DOMINIO="{{DOMINIO}}"
DOMINIO_NETBIOS="{{DOMINIO_NETBIOS}}"
DC_IP="{{DC_IP}}"
DC_IP_LIST="{{DC_IP_LIST}}"
OU_PADRAO="{{OU_PADRAO}}"
GRUPO_ADMIN="{{GRUPO_ADMIN}}"
GRUPO_ADMIN_AD="{{GRUPO_ADMIN_AD}}"
GRUPO_ADMIN_LINUX="{{GRUPO_ADMIN_LINUX}}"
GRUPO_DASTI="{{GRUPO_DASTI}}"
OFFLINE_AUTH_ENABLED="{{OFFLINE_AUTH_ENABLED}}"
OFFLINE_AUTH_DAYS="{{OFFLINE_AUTH_DAYS}}"
ADMIN_USERNAME="{{ADMIN_USERNAME}}"
AUTH_METHOD="{{AUTH_METHOD}}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-}"

echo ">>> Dominio: $DOMINIO"
echo ">>> NetBIOS: $DOMINIO_NETBIOS"
echo ">>> DC principal: $DC_IP"

# ============================================================
# Definir modo winbind offline logon conforme AUTH_METHOD e OFFLINE_AUTH_ENABLED
# ============================================================
if [ "$AUTH_METHOD" = "winbind" ] && [ "$OFFLINE_AUTH_ENABLED" = "true" ]; then
    WINBIND_OFFLINE="yes"
else
    WINBIND_OFFLINE="false"
fi

# ============================================================
# Configurar Kerberos
# ============================================================
echo ">>> Configurando Kerberos..."
REALM="${DOMINIO^^}"

cat > /etc/krb5.conf <<EOF
[libdefaults]
    default_realm = ${REALM}
    dns_lookup_realm = false
    dns_lookup_kdc = true
    rdns = false
    ticket_lifetime = 24h
    forwardable = yes
    renew_lifetime = 7d

[realms]
    ${REALM} = {
        kdc = ${DC_IP}
        admin_server = ${DC_IP}
    }

[domain_realm]
    .${DOMINIO} = ${REALM}
    ${DOMINIO} = ${REALM}
EOF

echo ">>> Kerberos configurado"

# ============================================================
# Configurar Samba
# ============================================================
echo ">>> Configurando Samba..."
cat > /etc/samba/smb.conf <<EOF
[global]
    workgroup = ${DOMINIO_NETBIOS}
    realm = ${DOMINIO}
    security = ads
    dns forwarder = ${DC_IP}
    idmap config * : backend = tdb
    idmap config * : range = 3000-7999
    idmap config ${DOMINIO_NETBIOS} : backend = rid
    idmap config ${DOMINIO_NETBIOS} : range = 10000-999999
    template shell = /bin/bash
    template homedir = /home/%D/%U
    winbind use default domain = true
    winbind offline logon = ${WINBIND_OFFLINE}
    winbind nss info = rfc2307
    winbind enum users = no
    winbind enum groups = no
    load printers = no
    printing = bsd
    printcap name = /dev/null
    disable spoolss = yes
EOF

echo ">>> Samba configurado"

# ============================================================
# Ajustar DNS para o DC (IMPRESCINDÍVEL para ingresso)
# ============================================================
echo ">>> Ajustando DNS para ingresso no dominio..."
cat > /etc/resolv.conf <<EOF
nameserver $DC_IP
search $DOMINIO
EOF
echo ">>> DNS ajustado para: $DC_IP"

# ============================================================
# Obter ticket Kerberos
# Estrategia:
# 1. Se ADMIN_PASSWORD estiver definida, tenta pipe com 4 combinacoes
# 2. Se pipe falhou ou nao havia senha, entra em modo interativo:
#    - Se ADMIN_USERNAME ja estiver definido, pede apenas a senha
#    - Se ADMIN_USERNAME estiver vazio, pede usuario e senha
# 3. Loop ate obter o ticket ou o operador desistir
# ============================================================
echo ">>> Obtendo ticket Kerberos..."
KINIT_OK=false

# --- Tentativa via pipe (se senha disponivel) ---
if [ -n "$ADMIN_PASSWORD" ]; then
    echo ">>> Tentando obter ticket com senha pre-definida..."
    echo "$ADMIN_PASSWORD" | kinit "${ADMIN_USERNAME}@${DOMINIO^^}" 2>/dev/null && KINIT_OK=true
    [ "$KINIT_OK" != "true" ] && echo "$ADMIN_PASSWORD" | kinit "${ADMIN_USERNAME}@${DOMINIO_NETBIOS}" 2>/dev/null && KINIT_OK=true
    [ "$KINIT_OK" != "true" ] && echo "$ADMIN_PASSWORD" | kinit "${ADMIN_USERNAME,,}@${DOMINIO^^}" 2>/dev/null && KINIT_OK=true
    [ "$KINIT_OK" != "true" ] && echo "$ADMIN_PASSWORD" | kinit "${ADMIN_USERNAME,,}@${DOMINIO,,}" 2>/dev/null && KINIT_OK=true
fi

# --- Tentativa interativa (se pipe falhou ou nao havia senha) ---
if [ "$KINIT_OK" != "true" ]; then
    echo ">>> Nao foi possivel obter ticket automaticamente."
    echo ">>> Solicitando credenciais interativamente..."

    while [ "$KINIT_OK" != "true" ]; do
        # Se usuario nao estiver definido, pede o usuario
        if [ -z "$ADMIN_USERNAME" ] || [ "$ADMIN_USERNAME" = "{{ADMIN_USERNAME}}" ]; then
            read -p ">>> Usuario do dominio: " input_user
            [ -n "$input_user" ] && ADMIN_USERNAME="$input_user"
        else
            echo ">>> Usuario: ${ADMIN_USERNAME}"
        fi

        # kinit interativo pede a senha no terminal
        echo ">>> Tentando kinit para ${ADMIN_USERNAME}@${DOMINIO^^} ..."
        if kinit "${ADMIN_USERNAME}@${DOMINIO^^}"; then
            KINIT_OK=true
        else
            echo ">>> Falhou. Verifique a senha e conectividade com o DC."
            read -p ">>> Tentar novamente? (S/n): " try_again
            if [[ "$try_again" =~ ^[Nn]$ ]]; then
                break
            fi
            # Na proxima tentativa, permite trocar o usuario
            ADMIN_USERNAME=""
        fi
    done
fi

if [ "$KINIT_OK" != "true" ]; then
    echo ">>> ERRO: Falha ao obter ticket Kerberos."
    echo ">>> Verifique as credenciais e conectividade com o DC."
    exit 1
fi
echo ">>> Ticket Kerberos obtido com sucesso!"

# ============================================================
# Ingressar no dominio
# Metodo 1 (PRINCIPAL): realm join (SSSD)
# Metodo 2 (FALLBACK): net ads join (Winbind)
# ============================================================
JOIN_OK=false
JOIN_METHOD=""

# Verificar se já está no domínio
REALM_LIST=$(realm list 2>/dev/null | grep -c "$DOMINIO" || true)
if [ "$REALM_LIST" -gt 0 ]; then
    echo ">>> Maquina ja esta associada ao dominio $DOMINIO."
    read -p ">>> Deseja remover e reingressar? (S/n): " REJOIN
    if [[ "$REJOIN" =~ ^[Nn]$ ]]; then
        echo ">>> Mantendo associacao existente. Prosseguindo..."
        JOIN_OK=true
        JOIN_METHOD="sssd"
    else
        echo ">>> Removendo associacao anterior..."
        realm leave "$DOMINIO" -U "$ADMIN_USERNAME" 2>/dev/null || true
        net ads leave -U "$ADMIN_USERNAME" 2>/dev/null || true
    fi
fi

# --- Metodo 1: realm join (SSSD) ---
if [ "$JOIN_OK" != "true" ]; then
    echo ">>> Ingressando no dominio via realm join (SSSD)..."
    if echo "$ADMIN_PASSWORD" | realm join "$DOMINIO" \
        --user="$ADMIN_USERNAME" \
        --computer-ou="$OU_PADRAO" \
        --verbose 2>&1; then
        JOIN_OK=true
        JOIN_METHOD="sssd"
        echo ">>> Ingresso via SSSD (realm join) bem-sucedido!"
    else
        echo ">>> realm join falhou."
    fi
fi

# --- Metodo 2: net ads join (Winbind) ---
if [ "$JOIN_OK" != "true" ]; then
    echo ">>> Tentando fallback com net ads join (Winbind)..."

    if ! grep -q "kerberos method" /etc/samba/smb.conf; then
        sed -i '/\[global\]/a\    kerberos method = secrets and keytab' /etc/samba/smb.conf
    fi

    DC_FQDN="dc-${OM_ACRONYM,,}.${DOMINIO}"
    if echo "$ADMIN_PASSWORD" | net ads join "$DOMINIO" \
        -U "$ADMIN_USERNAME" \
        -S "$DC_FQDN" \
        createcomputer="$OU_PADRAO" 2>&1; then
        JOIN_OK=true
        JOIN_METHOD="winbind"
        echo ">>> Ingresso via Winbind (net ads join) bem-sucedido!"

        net ads keytab create -U "$ADMIN_USERNAME" -P "$ADMIN_PASSWORD" 2>/dev/null || {
            echo "$ADMIN_PASSWORD" | adcli join "$DOMINIO" \
                --login-user="$ADMIN_USERNAME" \
                --domain-ou="$OU_PADRAO" \
                --stdin-password 2>&1 || true
        }
    else
        echo ">>> net ads join falhou."
    fi
fi

# --- Se ambos falharem ---
if [ "$JOIN_OK" != "true" ]; then
    echo ">>> ERRO: Falha ao ingressar no dominio com todos os metodos."
    read -p ">>> Deseja continuar mesmo assim? (S/n): " CONTINUE
    if [[ "$CONTINUE" =~ ^[Nn]$ ]]; then
        echo ">>> Instalacao abortada pelo usuario."
        exit 1
    fi
    JOIN_METHOD="nenhum"
fi

# ============================================================
# Configurar SSSD (apenas se metodo for sssd)
# ============================================================
if [ "$JOIN_METHOD" = "sssd" ]; then
    echo ">>> Configurando SSSD..."
    OFFLINE_CACHE=""
    if [ "$OFFLINE_AUTH_ENABLED" = "true" ]; then
        DAYS="${OFFLINE_AUTH_DAYS:-3}"
        OFFLINE_CACHE="cache_credentials = true
        krb5_store_password_if_offline = true
        offline_credentials_expiration = ${DAYS}"
    fi

    cat > /etc/sssd/sssd.conf <<EOF
[sssd]
services = nss, pam, sudo
config_file_version = 2
domains = ${DOMINIO}

[domain/${DOMINIO}]
    id_provider = ad
    ad_domain = ${DOMINIO}
    ad_server = ${DC_IP}
    ad_hostname = $(hostname).${DOMINIO}
    ldap_id_mapping = true
    enumerate = false
    use_fully_qualified_names = false
    fallback_homedir = /home/%d/%u
    default_shell = /bin/bash
    krb5_use_fast = false
    ${OFFLINE_CACHE}
    dyndns_update = false
    sudo_provider = ad
    ldap_sudo_search_base = OU=sudoers,${OU_PADRAO}
EOF

    chmod 600 /etc/sssd/sssd.conf
    echo ">>> SSSD configurado"
fi

# ============================================================
# Configurar NSS
# ============================================================
echo ">>> Configurando NSS..."
if [ "$JOIN_METHOD" = "winbind" ]; then
    cat > /etc/nsswitch.conf <<EOF
passwd:     files systemd winbind
shadow:     files winbind
group:      files systemd winbind
gshadow:    files

hosts:      files dns

services:   files
netgroup:   files
sudoers:    files

automount:  files
EOF
else
    cat > /etc/nsswitch.conf <<EOF
passwd:     files systemd sss
shadow:     files sss
group:      files systemd sss
gshadow:    files

hosts:      files dns

services:   files sss
netgroup:   files sss
sudoers:    files sss

automount:  files sss
EOF
fi

echo ">>> NSS configurado"

# ============================================================
# Configurar PAM (mkhomedir)
# ============================================================
echo ">>> Configurando PAM e mkhomedir..."
pam-auth-update --enable mkhomedir --force 2>/dev/null || true

# Garantir criacao automatica do home
if [ -f /etc/pam.d/common-session ]; then
    grep -q "pam_mkhomedir" /etc/pam.d/common-session || \
        echo "session required pam_mkhomedir.so skel=/etc/skel umask=0022" >> /etc/pam.d/common-session
fi

echo ">>> PAM configurado"

# ============================================================
# Configurar sudo para grupos do dominio
# ============================================================
echo ">>> Configurando sudo..."
SUDO_FILE="/etc/sudoers.d/seederlinux-domain"
cat > "$SUDO_FILE" <<EOF
# SeederLinux - Acesso sudo para grupos do dominio
%${GRUPO_ADMIN_AD}    ALL=(ALL:ALL) ALL
%${GRUPO_ADMIN_LINUX}  ALL=(ALL:ALL) ALL
EOF

if [ -n "$GRUPO_DASTI" ] && [ "$GRUPO_DASTI" != "" ]; then
    echo "%${GRUPO_DASTI}    ALL=(ALL:ALL) ALL" >> "$SUDO_FILE"
fi

chmod 440 "$SUDO_FILE"
visudo -cf "$SUDO_FILE" || {
    echo ">>> ERRO: sintaxe do sudoers invalida"
    exit 1
}

echo ">>> Sudo configurado"

# ============================================================
# Reiniciar servicos
# ============================================================
echo ">>> Reiniciando servicos..."
if [ "$JOIN_METHOD" = "sssd" ]; then
    systemctl restart sssd 2>/dev/null || true
    systemctl enable sssd
elif [ "$JOIN_METHOD" = "winbind" ]; then
    systemctl restart winbind 2>/dev/null || true
    systemctl enable winbind
fi
systemctl restart samba 2>/dev/null || true

echo ">>> [04] Ingresso no AD concluido! Metodo: ${JOIN_METHOD:-manual}"
echo "============================================================="
$SeederScript$,
    TRUE,
    TRUE,
    4,
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
    'Identidade Visual (Branding)',
    'core_branding.sh',
    'Aplica wallpaper, logo, tema GTK e branding da OM.',
    $SeederScript$#!/bin/bash
# ============================================================================
# Core Script: core_branding.sh
# SeederLinux Lite - Wallpaper, logo, tema (varia por DE)
# ============================================================================
# Aplica identidade visual da OM: wallpaper, logo, tema GTK e configuracoes
# de aparencia. Varia conforme o ambiente grafico (DE).
# Os placeholders VARIAVEL são substituídos automaticamente
# pelo sistema na geração do bundle.
# ============================================================================

set -e

echo "============================================================"
echo "13 - Aplicar identidade visual (branding)"
echo "============================================================"

# ============================================================
# Variáveis
# ============================================================
OM_ACRONYM="{{OM_ACRONYM}}"
OM_NAME="{{OM_NAME}}"
DISPLAY_NAME="{{DISPLAY_NAME}}"
WALLPAPER_URL="{{WALLPAPER_URL}}"
WALLPAPER_LOGIN_URL="{{WALLPAPER_LOGIN_URL}}"
LOGO_URL="{{LOGO_URL}}"
GREETER_URL="{{GREETER_URL}}"
THEME="{{THEME}}"
DESKTOP_ENV="{{DESKTOP_ENV}}"
DISPLAY_MANAGER="{{DISPLAY_MANAGER}}"
SEEDER_SERVER="{{SEEDER_SERVER}}"

# ============================================================
# Prefixar URLs de assets com SEEDER_SERVER quando relativas
# ============================================================
for url_var in WALLPAPER_URL WALLPAPER_LOGIN_URL LOGO_URL GREETER_URL; do
    url_val="${!url_var}"
    if [ -n "$url_val" ] && [ "$url_val" != "" ]; then
        if echo "$url_val" | grep -qE '^https?://[^/]+/'; then
            continue
        fi
        server_clean="${SEEDER_SERVER%/}"
        if echo "$url_val" | grep -q '^/'; then
            eval "${url_var}=\"${server_clean}${url_val}\""
        else
            eval "${url_var}=\"${server_clean}/${url_val}\""
        fi
    fi
done

# ============================================================
# Detectar ambiente grafico se nao definido
# ============================================================
if [ -z "$DESKTOP_ENV" ] || [ "$DESKTOP_ENV" = "" ]; then
    if command -v cinnamon-session &>/dev/null; then DESKTOP_ENV="cinnamon"
    elif command -v mate-session &>/dev/null; then DESKTOP_ENV="mate"
    elif command -v gnome-session &>/dev/null; then DESKTOP_ENV="gnome"
    elif command -v startxfce4 &>/dev/null; then DESKTOP_ENV="xfce"
    elif command -v startplasma-x11 &>/dev/null; then DESKTOP_ENV="kde"
    elif command -v startlxde &>/dev/null; then DESKTOP_ENV="lxde"
    else DESKTOP_ENV="unknown"
    fi
fi
echo ">>> Ambiente detectado: $DESKTOP_ENV"

# ============================================================
# Detectar display manager se nao definido
# ============================================================
if [ -z "$DISPLAY_MANAGER" ] || [ "$DISPLAY_MANAGER" = "" ]; then
    if systemctl is-active --quiet lightdm 2>/dev/null; then DISPLAY_MANAGER="lightdm"
    elif systemctl is-active --quiet gdm3 2>/dev/null; then DISPLAY_MANAGER="gdm3"
    elif systemctl is-active --quiet sddm 2>/dev/null; then DISPLAY_MANAGER="sddm"
    elif [ -f /etc/X11/default-display-manager ]; then
        DISPLAY_MANAGER="$(basename "$(cat /etc/X11/default-display-manager)")"
    else DISPLAY_MANAGER="unknown"
    fi
fi
echo ">>> Display Manager detectado: $DISPLAY_MANAGER"

echo ">>> OM: $OM_ACRONYM - $OM_NAME"
echo ">>> Ambiente: $DESKTOP_ENV / $DISPLAY_MANAGER"
echo ">>> Tema: $THEME"

# ============================================================
# Criar diretorios de branding
# ============================================================
mkdir -p /usr/share/seederlinux/branding
mkdir -p /usr/share/backgrounds/seederlinux
mkdir -p /usr/share/pixmaps

# ============================================================
# Baixar e instalar wallpaper
# ============================================================
echo ">>> Baixando wallpaper..."
if [ -n "$WALLPAPER_URL" ] && [ "$WALLPAPER_URL" != "" ]; then
    if wget -q -O /usr/share/backgrounds/seederlinux/wallpaper.jpg "$WALLPAPER_URL"; then
        echo ">>> Wallpaper instalado"
    else
        echo ">>> AVISO: Falha ao baixar wallpaper de: $WALLPAPER_URL"
    fi
else
    echo ">>> WALLPAPER_URL nao definido. Pulando wallpaper."
fi

# ============================================================
# Baixar e instalar wallpaper de login
# ============================================================
echo ">>> Baixando wallpaper de login..."
if [ -n "$WALLPAPER_LOGIN_URL" ] && [ "$WALLPAPER_LOGIN_URL" != "" ]; then
    if wget -q -O /usr/share/backgrounds/seederlinux/wallpaper-login.jpg "$WALLPAPER_LOGIN_URL"; then
        echo ">>> Wallpaper de login instalado"
    else
        echo ">>> AVISO: Falha ao baixar wallpaper de login"
    fi
fi

# ============================================================
# Baixar e instalar logo
# ============================================================
echo ">>> Baixando logo..."
if [ -n "$LOGO_URL" ] && [ "$LOGO_URL" != "" ]; then
    if wget -q -O /usr/share/pixmaps/seederlinux-logo.png "$LOGO_URL"; then
        echo ">>> Logo instalado"
    else
        echo ">>> AVISO: Falha ao baixar logo"
    fi
fi

# ============================================================
# Baixar e instalar greeter personalizado
# ============================================================
echo ">>> Baixando greeter..."
if [ -n "$GREETER_URL" ] && [ "$GREETER_URL" != "" ]; then
    GREETER_TARBALL="/tmp/seederlinux-greeter.tar.gz"
    if wget -q -O "$GREETER_TARBALL" "$GREETER_URL"; then
        mkdir -p /tmp/seederlinux-greeter
        tar xzf "$GREETER_TARBALL" -C /tmp/seederlinux-greeter
        # Copiar para o local apropriado conforme o DM
        case "$DISPLAY_MANAGER" in
            lightdm)
                cp -r /tmp/seederlinux-greeter/* /usr/share/lightdm/ 2>/dev/null || true
                ;;
            gdm3)
                cp -r /tmp/seederlinux-greeter/* /usr/share/gdm/ 2>/dev/null || true
                ;;
            sddm)
                cp -r /tmp/seederlinux-greeter/* /usr/share/sddm/themes/ 2>/dev/null || true
                ;;
        esac
        rm -rf /tmp/seederlinux-greeter "$GREETER_TARBALL"
        echo ">>> Greeter instalado"
    else
        echo ">>> AVISO: Falha ao baixar greeter"
    fi
fi

# ============================================================
# Aplicar tema GTK
# ============================================================
echo ">>> Aplicando tema GTK: $THEME"
if [ -n "$THEME" ] && [ "$THEME" != "" ]; then
    # Configuracao global do tema
    mkdir -p /etc/skel/.config/gtk-3.0
    cat > /etc/skel/.config/gtk-3.0/settings.ini <<EOF
[Settings]
gtk-theme-name=${THEME}
gtk-icon-theme-name=Adwaita
gtk-font-name=DejaVu Sans 10
gtk-cursor-theme-name=Adwaita
gtk-cursor-theme-size=16
gtk-toolbar-style=GTK_TOOLBAR_BOTH
gtk-toolbar-icon-size=GTK_ICON_SIZE_LARGE_TOOLBAR
gtk-button-images=1
gtk-menu-images=1
gtk-application-prefer-dark-theme=0
EOF
    echo ">>> Tema GTK configurado: $THEME"
fi

# ============================================================
# Aplicar wallpaper e configuracoes conforme o DE
# ============================================================
echo ">>> Aplicando configuracoes para: $DESKTOP_ENV"

case "$DESKTOP_ENV" in
    cinnamon)
        # Cinnamon - via gsettings (schema global)
        mkdir -p /etc/skel/.config
        cat > /etc/skel/.config/cinnamon-settings.conf <<EOF
[org.cinnamon.desktop.background]
picture-uri='file:///usr/share/backgrounds/seederlinux/wallpaper.jpg'
picture-options='zoom'

[org.cinnamon.desktop.interface]
gtk-theme='${THEME}'
icon-theme='Adwaita'

[org.cinnamon.theme]
name='${THEME}'
EOF
        ;;

    mate)
        # MATE - via gsettings
        mkdir -p /etc/skel/.config
        cat > /etc/skel/.config/mate-background.conf <<EOF
[org.mate.desktop.background]
picture-filename='/usr/share/backgrounds/seederlinux/wallpaper.jpg'
picture-options='zoom'

[org.mate.desktop.interface]
gtk-theme='${THEME}'
icon-theme='Adwaita'
EOF
        ;;

    gnome)
        # GNOME - via gsettings (dconf)
        mkdir -p /etc/dconf/db/local.d
        cat > /etc/dconf/db/local.d/seederlinux-branding <<EOF
[org/gnome/desktop/background]
picture-uri='file:///usr/share/backgrounds/seederlinux/wallpaper.jpg'
picture-uri-dark='file:///usr/share/backgrounds/seederlinux/wallpaper.jpg'
picture-options='zoom'

[org/gnome/desktop/interface]
gtk-theme='${THEME}'
icon-theme='Adwaita'

[org/gnome/login-screen]
logo='/usr/share/pixmaps/seederlinux-logo.png'
EOF
        dconf update 2>/dev/null || true
        ;;

    xfce)
        # XFCE - via xfconf
        mkdir -p /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml
        cat > /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop">
  <property name="backdrop" type="empty">
    <property name="screen0" type="empty">
      <property name="monitor0" type="empty">
        <property name="image-path" type="string" value="/usr/share/backgrounds/seederlinux/wallpaper.jpg"/>
        <property name="image-style" type="int" value="5"/>
      </property>
    </property>
  </property>
</channel>
EOF
        ;;

    kde)
        # KDE Plasma - via kdeglobals
        mkdir -p /etc/skel/.config
        cat > /etc/skel/.config/kdeglobals <<EOF
[General]
ColorScheme=${THEME}
Name=${THEME}

[KDE]
widgetStyle=${THEME}
EOF
        # Wallpaper via plasma config
        mkdir -p /etc/skel/.config
        cat > /etc/skel/.config/plasma-org.kde.plasma.desktop-appletsrc <<EOF
[Containments][1][Wallpaper][org.kde.image][General]
Image=file:///usr/share/backgrounds/seederlinux/wallpaper.jpg
EOF
        ;;

    lxde)
        # LXDE - via pcmanfm
        mkdir -p /etc/skel/.config/pcmanfm/LXDE
        cat > /etc/skel/.config/pcmanfm/LXDE/pcmanfm.conf <<EOF
[desktop]
wallpaper_mode=crop
wallpaper=/usr/share/backgrounds/seederlinux/wallpaper.jpg
EOF
        ;;
esac

# ============================================================
# Configurar wallpaper de login (greeter)
# ============================================================
echo ">>> Configurando wallpaper de login..."
case "$DISPLAY_MANAGER" in
    lightdm)
        mkdir -p /etc/lightdm
        if [ -f /usr/share/backgrounds/seederlinux/wallpaper-login.jpg ]; then
            cat > /etc/lightdm/lightdm-gtk-greeter.conf <<EOF
[greeter]
background=/usr/share/backgrounds/seederlinux/wallpaper-login.jpg
logo=/usr/share/pixmaps/seederlinux-logo.png
theme-name=${THEME}
icon-theme-name=Adwaita
font-name=DejaVu Sans 10
EOF
        fi
        ;;
    gdm3)
        if [ -f /usr/share/backgrounds/seederlinux/wallpaper-login.jpg ]; then
            # GDM3 usa dconf para configuracao
            mkdir -p /etc/dconf/db/gdm.d
            cat > /etc/dconf/db/gdm.d/01-seederlinux-background <<EOF
[org/gnome/desktop/background]
picture-uri='file:///usr/share/backgrounds/seederlinux/wallpaper-login.jpg'
picture-options='zoom'
EOF
            dconf update 2>/dev/null || true
        fi
        ;;
    sddm)
        if [ -f /usr/share/backgrounds/seederlinux/wallpaper-login.jpg ]; then
            mkdir -p /etc/sddm.conf.d
            cat > /etc/sddm.conf.d/seederlinux.conf <<EOF
[Theme]
ThemeDir=/usr/share/sddm/themes
Current=seederlinux
Background=/usr/share/backgrounds/seederlinux/wallpaper-login.jpg
EOF
        fi
        ;;
esac

echo ">>> [13] Identidade visual aplicada!"
echo "============================================================"
$SeederScript$,
    TRUE,
    TRUE,
    13,
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
