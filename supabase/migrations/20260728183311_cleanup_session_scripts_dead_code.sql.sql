/*
# Remove dead code from session scripts

The previous migration (fix_session_scripts_display_manager_guard.sql)
added early-exit guards at the top of each script. The old auto-detection
block and old skip-check further down are now unreachable dead code.

This migration removes the dead code from all three scripts to keep
them clean and avoid confusion.
*/

-- core_session_lightdm.sh: remove old detection + old skip check
UPDATE scripts SET content = replace(content,
'# ============================================================
# Detectar Display Manager ativo (se nao definido)
# ============================================================
if [ -z "$DISPLAY_MANAGER" ] || [ "$DISPLAY_MANAGER" = "" ]; then
    if systemctl is-active --quiet lightdm 2>/dev/null; then DISPLAY_MANAGER="lightdm"
    elif systemctl is-active --quiet gdm3 2>/dev/null; then DISPLAY_MANAGER="gdm3"
    elif systemctl is-active --quiet sddm 2>/dev/null; then DISPLAY_MANAGER="sddm"
    elif [ -f /etc/X11/default-display-manager ]; then
        DISPLAY_MANAGER="$(basename "$(cat /etc/X11/default-display-manager)")"
    elif command -v cinnamon-session &>/dev/null || command -v mate-session &>/dev/null || command -v startxfce4 &>/dev/null; then
        DISPLAY_MANAGER="lightdm"
    elif command -v gnome-session &>/dev/null; then
        DISPLAY_MANAGER="gdm3"
    elif command -v startplasma-x11 &>/dev/null; then
        DISPLAY_MANAGER="sddm"
    else
        DISPLAY_MANAGER="lightdm"
    fi
    echo ">>> Display Manager detectado: $DISPLAY_MANAGER"
fi

# ============================================================
# Verificar se este script deve ser executado
# ============================================================
if [ "$DISPLAY_MANAGER" != "lightdm" ]; then
    echo ">>> Display Manager nao e lightdm. Pulando este script."
    echo ">>> [14a] LightDM nao configurado (DM diferente)."
    echo "============================================================"
    exit 0
fi

# ============================================================
# Instalar LightDM',
'# ============================================================
# Instalar LightDM')
WHERE filename = 'core_session_lightdm.sh';

-- core_session_gdm3.sh: remove old detection + old skip check
UPDATE scripts SET content = replace(content,
'# ============================================================
# Detectar Display Manager ativo (se nao definido)
# ============================================================
if [ -z "$DISPLAY_MANAGER" ] || [ "$DISPLAY_MANAGER" = "" ]; then
    if systemctl is-active --quiet lightdm 2>/dev/null; then DISPLAY_MANAGER="lightdm"
    elif systemctl is-active --quiet gdm3 2>/dev/null; then DISPLAY_MANAGER="gdm3"
    elif systemctl is-active --quiet sddm 2>/dev/null; then DISPLAY_MANAGER="sddm"
    elif [ -f /etc/X11/default-display-manager ]; then
        DISPLAY_MANAGER="$(basename "$(cat /etc/X11/default-display-manager)")"
    elif command -v cinnamon-session &>/dev/null || command -v mate-session &>/dev/null || command -v startxfce4 &>/dev/null; then
        DISPLAY_MANAGER="lightdm"
    elif command -v gnome-session &>/dev/null; then
        DISPLAY_MANAGER="gdm3"
    elif command -v startplasma-x11 &>/dev/null; then
        DISPLAY_MANAGER="sddm"
    else
        DISPLAY_MANAGER="lightdm"
    fi
    echo ">>> Display Manager detectado: $DISPLAY_MANAGER"
fi

# ============================================================
# Verificar se este script deve ser executado
# ============================================================
if [ "$DISPLAY_MANAGER" != "gdm3" ]; then
    echo ">>> Display Manager nao e gdm3. Pulando este script."
    echo ">>> [14b] GDM3 nao configurado (DM diferente)."
    echo "============================================================"
    exit 0
fi

# ============================================================
# Instalar GDM3',
'# ============================================================
# Instalar GDM3')
WHERE filename = 'core_session_gdm3.sh';

-- core_session_sddm.sh: remove old detection + old skip check
UPDATE scripts SET content = replace(content,
'# ============================================================
# Detectar Display Manager ativo (se nao definido)
# ============================================================
if [ -z "$DISPLAY_MANAGER" ] || [ "$DISPLAY_MANAGER" = "" ]; then
    if systemctl is-active --quiet lightdm 2>/dev/null; then DISPLAY_MANAGER="lightdm"
    elif systemctl is-active --quiet gdm3 2>/dev/null; then DISPLAY_MANAGER="gdm3"
    elif systemctl is-active --quiet sddm 2>/dev/null; then DISPLAY_MANAGER="sddm"
    elif [ -f /etc/X11/default-display-manager ]; then
        DISPLAY_MANAGER="$(basename "$(cat /etc/X11/default-display-manager)")"
    elif command -v cinnamon-session &>/dev/null || command -v mate-session &>/dev/null || command -v startxfce4 &>/dev/null; then
        DISPLAY_MANAGER="lightdm"
    elif command -v gnome-session &>/dev/null; then
        DISPLAY_MANAGER="gdm3"
    elif command -v startplasma-x11 &>/dev/null; then
        DISPLAY_MANAGER="sddm"
    else
        DISPLAY_MANAGER="lightdm"
    fi
    echo ">>> Display Manager detectado: $DISPLAY_MANAGER"
fi

# ============================================================
# Verificar se este script deve ser executado
# ============================================================
if [ "$DISPLAY_MANAGER" != "sddm" ]; then
    echo ">>> Display Manager nao e sddm. Pulando este script."
    echo ">>> [14c] SDDM nao configurado (DM diferente)."
    echo "============================================================"
    exit 0
fi

# ============================================================
# Instalar SDDM',
'# ============================================================
# Instalar SDDM')
WHERE filename = 'core_session_sddm.sh';
