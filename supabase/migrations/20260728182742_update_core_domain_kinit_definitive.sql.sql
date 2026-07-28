/*
# Fix core_domain.sh - Definitive Kerberos kinit fix

Replaces the entire script content with a new version that:
1. Tries pipe-based kinit first (4 combinations) if ADMIN_PASSWORD is set
2. Falls back to interactive kinit loop if pipe fails or no password:
   - If ADMIN_USERNAME is set, only asks for password (via kinit's own prompt)
   - If ADMIN_USERNAME is empty/unset, asks for username then password
   - Loops until ticket obtained or operator gives up
3. Fixes all previously identified bugs (REALM typo, WINBIND_OFFLINE syntax, etc.)

The cosmetic "DOMINIO_NETBIOS}" issue was already fixed in the previous
migration - it was caused by the old REALS="${DOMINIO^}}" typo. The current
content has no standalone DOMINIO_NETBIOS} occurrences (verified).
*/

UPDATE scripts SET content = '#!/bin/bash
# ============================================================================
# Core Script: core_domain.sh
# SeederLinux Lite - Ingresso no AD (SSSD/Winbind)
# ============================================================================
# Configura Kerberos, Samba, SSSD, PAM, NSS, sudo e mkhomedir para
# ingressar a estacao no dominio Active Directory.
# Os placeholders {{VARIAVEL}} são substituídos automaticamente
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
# Ingressar no dominio
# ============================================================
echo ">>> Ingressando no dominio..."

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

# Ingressar com net ads join
net ads join -U "${ADMIN_USERNAME}@${DOMINIO_NETBIOS}" \
    createcomputer="${OU_PADRAO}" || {
    echo ">>> ERRO: Falha ao ingressar no dominio"
    exit 1
}
echo ">>> Ingresso no dominio realizado"

# ============================================================
# Configurar SSSD
# ============================================================
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
    ${OFFLINE_CACHE}
    dyndns_update = false
    sudo_provider = ad
    ldap_sudo_search_base = OU=sudoers,${OU_PADRAO}
EOF

chmod 600 /etc/sssd/sssd.conf
echo ">>> SSSD configurado"

# ============================================================
# Configurar NSS
# ============================================================
echo ">>> Configurando NSS..."
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
systemctl restart samba 2>/dev/null || true
systemctl restart sssd
systemctl enable sssd

echo ">>> [04] Ingresso no AD concluido!"
echo "============================================================="
' WHERE filename = 'core_domain.sh';
