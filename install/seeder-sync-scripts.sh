#!/bin/bash
# ============================================================================
# seeder-sync-scripts.sh
# Sincroniza scripts do repositorio Git para o banco de dados PostgreSQL
# ============================================================================
set -e

REPO_DIR="/opt/seederlinux-lite"
SCRIPTS_DIR="$REPO_DIR/scripts/core"
BRANCH="main"
DB_USER="seeder"
DB_NAME="seederlinux"
LOG_FILE="/var/log/seeder-sync.log"
SEEDER_SERVER="https://seederlinux.om.local"

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$msg"
    echo "$msg" >> "$LOG_FILE"
}

error_exit() {
    log "ERRO: $1"
    exit 1
}

[ "$EUID" -ne 0 ] && error_exit "Execute como root (sudo)."
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

log "============================================"
log "Iniciando sincronizacao de scripts"

[ ! -d "$REPO_DIR" ] && error_exit "Diretorio do repositorio nao encontrado: $REPO_DIR"

cd "$REPO_DIR"
log "Fazendo pull da branch '$BRANCH'..."
git pull origin "$BRANCH" 2>&1 | tee -a "$LOG_FILE" || error_exit "Falha no git pull"
log "Pull concluido."

[ ! -d "$SCRIPTS_DIR" ] && error_exit "Diretorio de scripts nao encontrado: $SCRIPTS_DIR"

SCRIPTS_COUNT=0
ERRORS=0

for script_file in "$SCRIPTS_DIR"/*.sh; do
    [ -f "$script_file" ] || continue
    filename=$(basename "$script_file")

    EXISTS=$(psql -U "$DB_USER" -d "$DB_NAME" -tAc "SELECT COUNT(*) FROM scripts WHERE filename = '$filename';" 2>/dev/null)
    if [ "$EXISTS" = "0" ]; then
        log "AVISO: '$filename' nao cadastrado. Pulando."
        continue
    fi

    log "Atualizando: $filename"

    CONTENT_JSON=$(cat "$script_file" | jq -Rs .)
    if curl -s -X POST "${SEEDER_SERVER}/api/?action=sync-script" \
        -H "Content-Type: application/json" \
        -d "{\"filename\": \"$filename\", \"content\": $CONTENT_JSON}"; then
        SCRIPTS_COUNT=$((SCRIPTS_COUNT + 1))
    else
        log "ERRO ao atualizar $filename via API"
        ERRORS=$((ERRORS + 1))
    fi
done

log "============================================"
log "Sincronizacao concluida. Atualizados: $SCRIPTS_COUNT, Erros: $ERRORS"
[ $ERRORS -gt 0 ] && exit 1
exit 0
