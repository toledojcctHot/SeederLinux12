#!/bin/bash
# ============================================================================
# Core Script: core_session_sddm.sh
# SeederLinux Lite - SDDM: logon/logoff (KDE)
# ============================================================================
# Configura o SDDM como display manager e define os scripts de logon
# e logoff que serao executados nas transicoes de sessao.
# Os placeholders VARIAVEL são substituídos automaticamente
# pelo sistema na geração do bundle.
# ============================================================================

(
set -e

echo "============================================================"
echo "14c - Configurar SDDM (KDE)"
echo "============================================================"

# ============================================================
# Variáveis
# ============================================================
DISPLAY_MANAGER="{{DISPLAY_MANAGER}}"
DESKTOP_ENV="{{DESKTOP_ENV}}"
BASE_URL="{{BASE_URL}}"
DOMINIO="{{DOMINIO}}"
DOMINIO_NETBIOS="{{DOMINIO_NETBIOS}}"
GRUPO_ADMIN_AD="{{GRUPO_ADMIN_AD}}"

if [ -z "$DISPLAY_MANAGER" ] || [ "$DISPLAY_MANAGER" = "" ]; then
    echo ">>> DISPLAY_MANAGER nao configurado. Nenhum DM sera instalado."
    exit 0
fi

if [ "$DISPLAY_MANAGER" != "sddm" ]; then
    echo ">>> DISPLAY_MANAGER e $DISPLAY_MANAGER (nao e sddm). Pulando."
    exit 0
fi

echo ">>> Display Manager: $DISPLAY_MANAGER"
echo ">>> Ambiente: $DESKTOP_ENV"

# ============================================================
# Instalar SDDM
# ============================================================
echo ">>> Instalando SDDM..."
export DEBIAN_FRONTEND=noninteractive
apt-get install -y sddm sddm-theme-breeze

# Garantir que o SDDM seja o DM padrao
echo "sddm shared/default-x-display-manager select sddm" | debconf-set-selections 2>/dev/null || true
echo "sddm sddm/daemon_name string sddm" | debconf-set-selections 2>/dev/null || true

# ============================================================
# Configurar SDDM
# ============================================================
echo ">>> Configurando SDDM..."
mkdir -p /etc/sddm.conf.d

cat > /etc/sddm.conf.d/seederlinux.conf <<EOF
# Configuracao SDDM - SeederLinux
[Theme]
Current=breeze
ThemeDir=/usr/share/sddm/themes

[Users]
MaximumUid=60000
MinimumUid=1000

[Autologin]
User=
Session=
EOF

echo ">>> SDDM configurado"

# ============================================================
# Configurar scripts de logon/logoff via Xsession
# ============================================================
echo ">>> Configurando scripts de logon/logoff no SDDM..."

# SDDM executa /etc/X11/Xsession que por sua vez pode chamar scripts.
# Para integrar logon/logoff, usamos o Xsetup e Xstop do SDDM.

# Xsetup - executado antes da sessao (logon)
XSETUP_FILE="/usr/share/sddm/scripts/Xsetup"
mkdir -p /usr/share/sddm/scripts

cat > "$XSETUP_FILE" <<'XSETUP'
#!/bin/bash
# Xsetup do SDDM - SeederLinux
# Executa o script de logon do SeederLinux
if [ -x /usr/local/bin/seederlinux-logon ]; then
    /usr/local/bin/seederlinux-logon "$@"
fi

exit 0
XSETUP
chmod +x "$XSETUP_FILE"

# Xstop - executado apos a sessao (logoff)
XSTOP_FILE="/usr/share/sddm/scripts/Xstop"

cat > "$XSTOP_FILE" <<'XSTOP'
#!/bin/bash
# Xstop do SDDM - SeederLinux
# Executa o script de logoff do SeederLinux
if [ -x /usr/local/bin/seederlinux-logoff ]; then
    /usr/local/bin/seederlinux-logoff "$@"
fi

exit 0
XSTOP
chmod +x "$XSTOP_FILE"

echo ">>> Scripts de logon/logoff configurados no SDDM"

# ============================================================
# Garantir que os scripts de logon/logoff existam
# ============================================================
echo ">>> Verificando scripts de logon/logoff..."
for SCRIPT in seederlinux-logon seederlinux-logoff; do
    if [ ! -f "/usr/local/bin/${SCRIPT}" ]; then
        echo ">>> AVISO: /usr/local/bin/${SCRIPT} nao encontrado."
        echo ">>> Os scripts core_logon.sh e core_logoff.sh devem ser executados antes."
    fi
done

# ============================================================
# Desabilitar outros display managers
# ============================================================
echo ">>> Desabilitando outros display managers..."
systemctl disable lightdm 2>/dev/null || true
systemctl disable gdm3 2>/dev/null || true
systemctl enable sddm

# ============================================================
# Reiniciar servico
# ============================================================
echo ">>> Reiniciando SDDM..."
systemctl restart sddm 2>/dev/null || {
    echo ">>> AVISO: SDDM sera iniciado no proximo boot."
}

echo ">>> [14c] SDDM configurado!"
echo "============================================================"
)
