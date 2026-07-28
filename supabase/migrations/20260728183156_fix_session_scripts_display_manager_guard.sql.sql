/*
# Fix session scripts - Only run when DISPLAY_MANAGER matches

Each of the three display manager scripts (lightdm, gdm3, sddm) runs
unconditionally during bundle execution. This causes LightDM to be installed
even when the admin left DISPLAY_MANAGER empty.

Fix: Add a guard at the top of each script (after variables, before the
first echo) that exits early if DISPLAY_MANAGER is not set to the
specific DM name this script handles.

- core_session_lightdm.sh -> only runs if DISPLAY_MANAGER == "lightdm"
- core_session_gdm3.sh     -> only runs if DISPLAY_MANAGER == "gdm3"
- core_session_sddm.sh      -> only runs if DISPLAY_MANAGER == "sddm"
*/

-- core_session_lightdm.sh
UPDATE scripts SET content = replace(content,
    'echo ">>> Display Manager: $DISPLAY_MANAGER"',
    'if [ -z "$DISPLAY_MANAGER" ] || [ "$DISPLAY_MANAGER" = "" ]; then
    echo ">>> DISPLAY_MANAGER nao configurado. Nenhum DM sera instalado."
    exit 0
fi

if [ "$DISPLAY_MANAGER" != "lightdm" ]; then
    echo ">>> DISPLAY_MANAGER e $DISPLAY_MANAGER (nao e lightdm). Pulando."
    exit 0
fi

echo ">>> Display Manager: $DISPLAY_MANAGER"')
WHERE filename = 'core_session_lightdm.sh';

-- core_session_gdm3.sh
UPDATE scripts SET content = replace(content,
    'echo ">>> Display Manager: $DISPLAY_MANAGER"',
    'if [ -z "$DISPLAY_MANAGER" ] || [ "$DISPLAY_MANAGER" = "" ]; then
    echo ">>> DISPLAY_MANAGER nao configurado. Nenhum DM sera instalado."
    exit 0
fi

if [ "$DISPLAY_MANAGER" != "gdm3" ]; then
    echo ">>> DISPLAY_MANAGER e $DISPLAY_MANAGER (nao e gdm3). Pulando."
    exit 0
fi

echo ">>> Display Manager: $DISPLAY_MANAGER"')
WHERE filename = 'core_session_gdm3.sh';

-- core_session_sddm.sh
UPDATE scripts SET content = replace(content,
    'echo ">>> Display Manager: $DISPLAY_MANAGER"',
    'if [ -z "$DISPLAY_MANAGER" ] || [ "$DISPLAY_MANAGER" = "" ]; then
    echo ">>> DISPLAY_MANAGER nao configurado. Nenhum DM sera instalado."
    exit 0
fi

if [ "$DISPLAY_MANAGER" != "sddm" ]; then
    echo ">>> DISPLAY_MANAGER e $DISPLAY_MANAGER (nao e sddm). Pulando."
    exit 0
fi

echo ">>> Display Manager: $DISPLAY_MANAGER"')
WHERE filename = 'core_session_sddm.sh';
