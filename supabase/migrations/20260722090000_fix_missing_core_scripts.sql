-- Fix core_network.sh: rename to core_dns.sh and set correct order
UPDATE scripts SET filename = 'core_dns.sh', name = 'Configuracao de DNS', execution_order = 1 WHERE filename = 'core_network.sh' AND is_core = TRUE;

-- Insert/update core_repositories.sh
INSERT INTO scripts (name, filename, description, content, is_core, is_active, execution_order, version, organization_id)
VALUES (
    'Configuracao de Repositorios',
    'core_repositories.sh',
    'Configura repositorios APT',
    $SeederScript$#!/bin/bash
# ============================================================================
# Core Script: core_repositories.sh
# SeederLinux Lite - Configurar sources.list (APT)
# ============================================================================
# Detecta a distribuicao (Debian, Ubuntu, Mint, Zorin) e configura os
# repositorios APT conforme o modo e as variaveis por distro:
#   REPOSITORY_DEBIAN_ENABLED / REPOSITORY_DEBIAN_URL
#   REPOSITORY_UBUNTU_ENABLED / REPOSITORY_UBUNTU_URL
#   REPOSITORY_MINT_ENABLED   / REPOSITORY_MINT_URL
#   REPOSITORY_ZORIN_ENABLED  / REPOSITORY_ZORIN_URL
# NUNCA altera sources.list se o modo for PUBLIC ou se o mirror da distro
# detectada nao estiver habilitado.
# Os placeholders {{VARIAVEL}} sao substituidos automaticamente
# pelo sistema na geracao do bundle.
# ============================================================================

set -e

echo "============================================================"
echo "02 - Configurar repositorios APT"
echo "============================================================"

# ============================================================
# Variaveis globais
# ============================================================
REPOSITORY_MODE="{{REPOSITORY_MODE}}"
REPOSITORY_URL="{{REPOSITORY_URL}}"
REPOSITORY_FALLBACK="{{REPOSITORY_FALLBACK}}"

# Variaveis por distro
REPOSITORY_DEBIAN_ENABLED="{{REPOSITORY_DEBIAN_ENABLED}}"
REPOSITORY_DEBIAN_URL="{{REPOSITORY_DEBIAN_URL}}"
REPOSITORY_UBUNTU_ENABLED="{{REPOSITORY_UBUNTU_ENABLED}}"
REPOSITORY_UBUNTU_URL="{{REPOSITORY_UBUNTU_URL}}"
REPOSITORY_MINT_ENABLED="{{REPOSITORY_MINT_ENABLED}}"
REPOSITORY_MINT_URL="{{REPOSITORY_MINT_URL}}"
REPOSITORY_ZORIN_ENABLED="{{REPOSITORY_ZORIN_ENABLED}}"
REPOSITORY_ZORIN_URL="{{REPOSITORY_ZORIN_URL}}"

echo ">>> Modo de repositorio: $REPOSITORY_MODE"

# ============================================================
# Detectar a distribuicao
# ============================================================
detect_distro() {
    if [ -f /etc/linuxmint/info ]; then
        echo "mint"
    elif [ -f /etc/zorin-release ]; then
        echo "zorin"
    elif grep -qi "ubuntu" /etc/os-release 2>/dev/null; then
        echo "ubuntu"
    elif grep -qi "debian" /etc/os-release 2>/dev/null; then
        echo "debian"
    else
        echo "unknown"
    fi
}

DISTRO=$(detect_distro)
echo ">>> Distribuicao detectada: $DISTRO"

# ============================================================
# Backup do sources.list original
# ============================================================
backup_sources() {
    if [ -f /etc/apt/sources.list ]; then
        cp /etc/apt/sources.list /etc/apt/sources.list.bak.$(date +%Y%m%d%H%M%S)
        echo ">>> Backup do sources.list criado"
    fi
}

# ============================================================
# Obter codename da distro
# ============================================================
get_codename() {
    lsb_release -cs 2>/dev/null || echo "$1"
}

# ============================================================
# Configuracao conforme o modo
# ============================================================
case "$REPOSITORY_MODE" in
    PUBLIC|"")
        echo ">>> Modo PUBLIC: mantendo repositorios padrao da distribuicao ($DISTRO)."
        echo ">>> Nenhuma alteracao em sources.list foi feita."
        ;;

    MIRROR|HYBRID)
        case "$DISTRO" in
            debian)
                if [ "${REPOSITORY_DEBIAN_ENABLED:-false}" = "true" ] && [ -n "${REPOSITORY_DEBIAN_URL:-}" ]; then
                    echo ">>> Configurando mirror Debian: $REPOSITORY_DEBIAN_URL"
                    backup_sources
                    DEBIAN_CODENAME=$(get_codename trixie)
                    cat > /etc/apt/sources.list <<EOF
deb $REPOSITORY_DEBIAN_URL/debian $DEBIAN_CODENAME main contrib non-free non-free-firmware
deb $REPOSITORY_DEBIAN_URL/debian-security $DEBIAN_CODENAME-security main contrib non-free non-free-firmware
deb $REPOSITORY_DEBIAN_URL/debian $DEBIAN_CODENAME-updates main contrib non-free non-free-firmware
EOF
                    if [ "$REPOSITORY_MODE" = "HYBRID" ] && [ -n "$REPOSITORY_FALLBACK" ]; then
                        echo ">>> Adicionando fallback Debian..."
                        cat >> /etc/apt/sources.list <<EOF
deb $REPOSITORY_FALLBACK/debian $DEBIAN_CODENAME main contrib non-free non-free-firmware
deb $REPOSITORY_FALLBACK/debian-security $DEBIAN_CODENAME-security main contrib non-free non-free-firmware
deb $REPOSITORY_FALLBACK/debian $DEBIAN_CODENAME-updates main contrib non-free non-free-firmware
EOF
                    fi
                else
                    echo ">>> Mirror Debian nao habilitado. Mantendo repositorios oficiais."
                fi
                ;;

            ubuntu)
                if [ "${REPOSITORY_UBUNTU_ENABLED:-false}" = "true" ] && [ -n "${REPOSITORY_UBUNTU_URL:-}" ]; then
                    echo ">>> Configurando mirror Ubuntu: $REPOSITORY_UBUNTU_URL"
                    backup_sources
                    UBUNTU_CODENAME=$(get_codename noble)
                    cat > /etc/apt/sources.list <<EOF
deb $REPOSITORY_UBUNTU_URL/ubuntu $UBUNTU_CODENAME main restricted universe multiverse
deb $REPOSITORY_UBUNTU_URL/ubuntu $UBUNTU_CODENAME-updates main restricted universe multiverse
deb $REPOSITORY_UBUNTU_URL/ubuntu $UBUNTU_CODENAME-security main restricted universe multiverse
EOF
                    if [ "$REPOSITORY_MODE" = "HYBRID" ] && [ -n "$REPOSITORY_FALLBACK" ]; then
                        echo ">>> Adicionando fallback Ubuntu..."
                        cat >> /etc/apt/sources.list <<EOF
deb $REPOSITORY_FALLBACK/ubuntu $UBUNTU_CODENAME main restricted universe multiverse
deb $REPOSITORY_FALLBACK/ubuntu $UBUNTU_CODENAME-updates main restricted universe multiverse
deb $REPOSITORY_FALLBACK/ubuntu $UBUNTU_CODENAME-security main restricted universe multiverse
EOF
                    fi
                else
                    echo ">>> Mirror Ubuntu nao habilitado. Mantendo repositorios oficiais."
                fi
                ;;

            mint)
                MINT_CODENAME=$(get_codename wilma)
                UBUNTU_CODENAME=$(grep UBUNTU_CODENAME /etc/linuxmint/info 2>/dev/null | cut -d= -f2 || echo noble)
                MINT_OK=false

                if [ "${REPOSITORY_MINT_ENABLED:-false}" = "true" ] && [ -n "${REPOSITORY_MINT_URL:-}" ]; then
                    MINT_OK=true
                fi

                if [ "$MINT_OK" = "true" ]; then
                    echo ">>> Configurando mirror Mint: $REPOSITORY_MINT_URL"
                    backup_sources
                    cat > /etc/apt/sources.list <<EOF
deb $REPOSITORY_MINT_URL/mint $MINT_CODENAME main upstream import backport
EOF
                    if [ "${REPOSITORY_UBUNTU_ENABLED:-false}" = "true" ] && [ -n "${REPOSITORY_UBUNTU_URL:-}" ]; then
                        echo ">>> Configurando mirror Ubuntu base para Mint: $REPOSITORY_UBUNTU_URL"
                        cat >> /etc/apt/sources.list <<EOF
deb $REPOSITORY_UBUNTU_URL/ubuntu $UBUNTU_CODENAME main restricted universe multiverse
deb $REPOSITORY_UBUNTU_URL/ubuntu $UBUNTU_CODENAME-updates main restricted universe multiverse
deb $REPOSITORY_UBUNTU_URL/ubuntu $UBUNTU_CODENAME-security main restricted universe multiverse
EOF
                    else
                        echo ">>> Mirror Ubuntu nao habilitado. Mantendo repositorios oficiais do Ubuntu base."
                        cat >> /etc/apt/sources.list <<EOF
deb http://archive.ubuntu.com/ubuntu $UBUNTU_CODENAME main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu $UBUNTU_CODENAME-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu $UBUNTU_CODENAME-security main restricted universe multiverse
EOF
                    fi

                    if [ "$REPOSITORY_MODE" = "HYBRID" ] && [ -n "$REPOSITORY_FALLBACK" ]; then
                        echo ">>> Adicionando fallback..."
                        cat >> /etc/apt/sources.list <<EOF
deb $REPOSITORY_FALLBACK/mint $MINT_CODENAME main upstream import backport
deb $REPOSITORY_FALLBACK/ubuntu $UBUNTU_CODENAME main restricted universe multiverse
deb $REPOSITORY_FALLBACK/ubuntu $UBUNTU_CODENAME-updates main restricted universe multiverse
deb $REPOSITORY_FALLBACK/ubuntu $UBUNTU_CODENAME-security main restricted universe multiverse
EOF
                    fi
                else
                    echo ">>> Mirror Mint nao habilitado. Mantendo repositorios oficiais."
                fi
                ;;

            zorin)
                if [ "${REPOSITORY_ZORIN_ENABLED:-false}" = "true" ] && [ -n "${REPOSITORY_ZORIN_URL:-}" ]; then
                    echo ">>> Configurando mirror Zorin: $REPOSITORY_ZORIN_URL"
                    backup_sources
                    UBUNTU_CODENAME=$(get_codename jammy)
                    cat > /etc/apt/sources.list <<EOF
deb $REPOSITORY_ZORIN_URL/ubuntu $UBUNTU_CODENAME main restricted universe multiverse
deb $REPOSITORY_ZORIN_URL/ubuntu $UBUNTU_CODENAME-updates main restricted universe multiverse
deb $REPOSITORY_ZORIN_URL/ubuntu $UBUNTU_CODENAME-security main restricted universe multiverse
EOF
                    if [ "$REPOSITORY_MODE" = "HYBRID" ] && [ -n "$REPOSITORY_FALLBACK" ]; then
                        echo ">>> Adicionando fallback Zorin..."
                        cat >> /etc/apt/sources.list <<EOF
deb $REPOSITORY_FALLBACK/ubuntu $UBUNTU_CODENAME main restricted universe multiverse
deb $REPOSITORY_FALLBACK/ubuntu $UBUNTU_CODENAME-updates main restricted universe multiverse
deb $REPOSITORY_FALLBACK/ubuntu $UBUNTU_CODENAME-security main restricted universe multiverse
EOF
                    fi
                else
                    echo ">>> Mirror Zorin nao habilitado. Mantendo repositorios oficiais."
                fi
                ;;

            *)
                echo ">>> Distribuicao nao reconhecida. Mantendo sources.list padrao."
                ;;
        esac
        ;;

    CUSTOM)
        if [ -z "$REPOSITORY_URL" ] || [ "$REPOSITORY_URL" = "" ]; then
            echo ">>> ERRO: REPOSITORY_URL nao definido para modo CUSTOM"
            read -p ">>> Deseja continuar mesmo assim? (S/n): " CONTINUE
            if [[ "$CONTINUE" =~ ^[Nn]$ ]]; then
                echo ">>> Instalacao abortada pelo usuario."
                exit 1
            fi
            echo ">>> Continuando apesar do erro..."
        fi

        echo ">>> Configurando repositorio personalizado"
        backup_sources

        cat > /etc/apt/sources.list <<EOF
$REPOSITORY_URL
EOF
        ;;

    *)
        echo ">>> ERRO: Modo de repositorio invalido: $REPOSITORY_MODE"
        read -p ">>> Deseja continuar mesmo assim? (S/n): " CONTINUE
        if [[ "$CONTINUE" =~ ^[Nn]$ ]]; then
            echo ">>> Instalacao abortada pelo usuario."
            exit 1
        fi
        echo ">>> Continuando apesar do erro..."
        ;;
esac

# ============================================================
# Atualizar indice de pacotes
# ============================================================
echo ">>> Atualizando apt-get update..."
apt-get update

echo ">>> [02] Repositorios configurados com sucesso!"
echo "============================================================"
$SeederScript$,
    TRUE, TRUE, 2, 1, NULL
) ON CONFLICT (filename) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    content = EXCLUDED.content,
    execution_order = EXCLUDED.execution_order,
    updated_at = CURRENT_TIMESTAMP;

-- Insert/update core_browser.sh
INSERT INTO scripts (name, filename, description, content, is_core, is_active, execution_order, version, organization_id)
VALUES (
    'Configuracao de Navegador',
    'core_browser.sh',
    'Configura Firefox ESR e Chrome',
    $SeederScript$#!/bin/bash
# ============================================================================
# Core Script: core_browser.sh
# SeederLinux Lite - Politicas Firefox/Chrome
# ============================================================================
# Configura politicas corporativas para Firefox ESR, Google Chrome e Chromium
# via arquivos de policies (JSON) no sistema.
# Os placeholders {{VARIAVEL}} são substituídos automaticamente
# pelo sistema na geração do bundle.
# ============================================================================

set -e

echo "============================================================"
echo "06 - Configurar politicas de navegadores"
echo "============================================================"

# ============================================================
# Variáveis
# ============================================================
HOMEPAGE="{{HOMEPAGE}}"
PROXY_MODE="{{PROXY_MODE}}"
PROXY_HTTP="{{PROXY_HTTP}}"
PROXY_PORTA="{{PROXY_PORTA}}"
PAC_URL="{{PAC_URL}}"
NO_PROXY="{{NO_PROXY}}"
DOMINIO="{{DOMINIO}}"
OM_ACRONYM="{{OM_ACRONYM}}"
CERTIFICATE_BUNDLE="{{CERTIFICATE_BUNDLE}}"

echo ">>> Homepage: $HOMEPAGE"
echo ">>> Modo de proxy: $PROXY_MODE"

# ============================================================
# Firefox ESR - Politicas (policies.json)
# ============================================================
echo ">>> Configurando politicas do Firefox ESR..."
mkdir -p /usr/lib/firefox-esr/distribution

cat > /usr/lib/firefox-esr/distribution/policies.json <<EOF
{
    "policies": {
        "DisableTelemetry": true,
        "DisableFirefoxStudies": true,
        "DisablePocket": true,
        "DisableDeveloperTools": false,
        "BlockAboutConfig": false,
        "Homepage": {
            "URL": "${HOMEPAGE}",
            "Locked": true,
            "StartPage": "homepage"
        },
        "HomepageURL": "${HOMEPAGE}",
        "SearchBar": "unified",
        "SearchEngines": {
            "Add": [
                {
                    "Name": "${OM_ACRONYM}",
                    "URL": "${HOMEPAGE}",
                    "Method": "GET"
                }
            ]
        },
        "Proxy": {
            "Mode": "system",
            "Locked": true
        },
        "Certificates": {
            "ImportEnterpriseRoots": true
        },
        "ExtensionSettings": {
            "*": {
                "installation_mode": "allowed"
            }
        },
        "DisableSetDesktopBackground": false,
        "DontCheckDefaultBrowser": true,
        "PrimaryPassword": false,
        "OfferToSaveLogins": false,
        "PasswordManagerEnabled": false,
        "SanitizeOnShutdown": {
            "Cache": true,
            "Cookies": false,
            "Downloads": false,
            "FormData": true,
            "History": false,
            "Sessions": false,
            "SiteSettings": false,
            "OfflineApps": false
        }
    }
}
EOF

echo ">>> Politicas do Firefox configuradas"

# ============================================================
# Firefox ESR - autoconfig (para proxy PAC)
# ============================================================
if [ "$PROXY_MODE" = "PAC" ]; then
    echo ">>> Configurando PAC no Firefox..."
    mkdir -p /usr/lib/firefox-esr/defaults/pref
    cat > /usr/lib/firefox-esr/defaults/pref/autoconfig.js <<EOF
pref("general.config.filename", "seederlinux.cfg");
pref("general.config.obscure_value", 0);
EOF

    cat > /usr/lib/firefox-esr/seederlinux.cfg <<EOF
lockPref("network.proxy.type", 2);
lockPref("network.proxy.autoconfig_url", "${PAC_URL}");
lockPref("network.proxy.no_proxies_on", "${NO_PROXY}");
EOF
    echo ">>> PAC configurado no Firefox"
elif [ "$PROXY_MODE" = "MANUAL" ]; then
    echo ">>> Configurando proxy manual no Firefox..."
    mkdir -p /usr/lib/firefox-esr/defaults/pref
    cat > /usr/lib/firefox-esr/defaults/pref/autoconfig.js <<EOF
pref("general.config.filename", "seederlinux.cfg");
pref("general.config.obscure_value", 0);
EOF

    cat > /usr/lib/firefox-esr/seederlinux.cfg <<EOF
lockPref("network.proxy.type", 1);
lockPref("network.proxy.http", "${PROXY_HTTP}");
lockPref("network.proxy.http_port", ${PROXY_PORTA});
lockPref("network.proxy.https", "${PROXY_HTTP}");
lockPref("network.proxy.https_port", ${PROXY_PORTA});
lockPref("network.proxy.no_proxies_on", "${NO_PROXY}");
EOF
    echo ">>> Proxy manual configurado no Firefox"
fi

# ============================================================
# Google Chrome - Politicas
# ============================================================
echo ">>> Configurando politicas do Google Chrome..."
mkdir -p /etc/opt/chrome/policies/managed
mkdir -p /etc/opt/chrome/policies/recommended

# Proxy config para Chrome
case "$PROXY_MODE" in
    NONE)
        CHROME_PROXY_MODE="direct"
        ;;
    MANUAL)
        CHROME_PROXY_MODE="fixed_servers"
        CHROME_PROXY_SERVERS="http=${PROXY_HTTP}:${PROXY_PORTA};https=${PROXY_HTTP}:${PROXY_PORTA}"
        ;;
    PAC)
        CHROME_PROXY_MODE="pac_script"
        CHROME_PROXY_PAC_URL="$PAC_URL"
        ;;
    *)
        CHROME_PROXY_MODE="system"
        ;;
esac

# Construir JSON de proxy
PROXY_JSON=""
if [ "$CHROME_PROXY_MODE" = "fixed_servers" ]; then
    PROXY_JSON=", \"ProxyMode\": \"${CHROME_PROXY_MODE}\", \"ProxyServer\": \"${CHROME_PROXY_SERVERS}\""
elif [ "$CHROME_PROXY_MODE" = "pac_script" ]; then
    PROXY_JSON=", \"ProxyMode\": \"${CHROME_PROXY_MODE}\", \"ProxyPacUrl\": \"${CHROME_PROXY_PAC_URL}\""
else
    PROXY_JSON=", \"ProxyMode\": \"${CHROME_PROXY_MODE}\""
fi

cat > /etc/opt/chrome/policies/managed/seederlinux.json <<EOF
{
    "HomepageLocation": "${HOMEPAGE}",
    "HomepageIsNewTabPage": false,
    "RestoreOnStartup": 1,
    "RestoreOnStartupURLs": ["${HOMEPAGE}"],
    "BrowserSignin": 0,
    "SyncDisabled": true,
    "BlockThirdPartyCookies": true,
    "BackgroundModeEnabled": false,
    "TelemetryReportingEnabled": false,
    "UrlKeyboardsEnabled": false${PROXY_JSON},
    "DefaultCookiesSetting": 1,
    "AutoSelectCertificateForUrls": ["{\"pattern\":\"https://*\",\"filter\":{}}"],
    "ChromeCertProtectorEnabled": false
}
EOF

echo ">>> Politicas do Chrome configuradas"

# ============================================================
# Chromium - Politicas (mesmas do Chrome)
# ============================================================
echo ">>> Configurando politicas do Chromium..."
mkdir -p /etc/chromium/policies/managed
mkdir -p /etc/chromium/policies/recommended

cp /etc/opt/chrome/policies/managed/seederlinux.json \
   /etc/chromium/policies/managed/seederlinux.json 2>/dev/null || true

echo ">>> Politicas do Chromium configuradas"

echo ">>> [06] Politicas de navegadores configuradas!"
echo "============================================================"
$SeederScript$,
    TRUE, TRUE, 8, 1, NULL
) ON CONFLICT (filename) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    content = EXCLUDED.content,
    execution_order = EXCLUDED.execution_order,
    updated_at = CURRENT_TIMESTAMP;
