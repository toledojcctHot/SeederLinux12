/*
# Fix core_domain.sh - Kerberos interactive kinit + multiple bug fixes

The database version of core_domain.sh had several critical bugs:
1. REALS="${DOMINIO^}}" - typo, should be REALM="${DOMINIO^^}"
2. kinit "${ADMIN_USERNAME}@${REALL}" - typo, should use ${REALM}
3. WINBIND_OFFLINE = "yes" - invalid bash (spaces around =)
4. kinit used pipe only, which fails on many DCs with
   "Client's credentials have been revoked"
5. krb5.conf [realms] section used DOMINIO_NETBIOS instead of REALM
6. SSSD OFFLINE_CACHE had leading space breaking heredoc

This update replaces the entire script with the corrected version:
- kinit tries interactive first (user types password), then pipe fallbacks
- REALM variable properly defined as ${DOMINIO^^}
- All bash variable assignments use correct syntax (no spaces around =)
- krb5.conf uses REALM consistently
- SSSD offline cache properly formatted
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

# Obter ticket Kerberos (requer senha de admin do dominio)
echo ">>> Obtendo ticket Kerberos..."
echo ">>> DIGITE SUA SENHA DO DOMINIO quando solicitado:"
KINIT_OK=false

# Tentativa 1: Interativa - REALM maiusculo (recomendado, funciona com qualquer DC)
kinit "${ADMIN_USERNAME}@${REALM}" 2>/dev/null && KINIT_OK=true

# Tentativa 2: Pipe - NETBIOS
if [ "$KINIT_OK" != "true" ] && [ -n "$ADMIN_PASSWORD" ]; then
    echo "$ADMIN_PASSWORD" | kinit "${ADMIN_USERNAME}@${DOMINIO_NETBIOS}" 2>/dev/null && KINIT_OK=true
fi

# Tentativa 3: Pipe - Usuario minusculo, REALM maiusculo
if [ "$KINIT_OK" != "true" ] && [ -n "$ADMIN_PASSWORD" ]; then
    echo "$ADMIN_PASSWORD" | kinit "${ADMIN_USERNAME,,}@${REALM}" 2>/dev/null && KINIT_OK=true
fi

# Tentativa 4: Pipe - Dominio minusculo
if [ "$KINIT_OK" != "true" ] && [ -n "$ADMIN_PASSWORD" ]; then
    echo "$ADMIN_PASSWORD" | kinit "${ADMIN_USERNAME,,}@${DOMINIO,,}" 2>/dev/null && KINIT_OK=true
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
