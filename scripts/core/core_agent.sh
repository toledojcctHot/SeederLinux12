#!/bin/bash
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
