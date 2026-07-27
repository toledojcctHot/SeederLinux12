-- ============================================================================
-- Migration: Soft-delete de OMs + esclarecer CERTIFICATE_BUNDLE
-- ============================================================================
-- Corrige dois problemas:
--   1. Ao deletar uma OM (soft-delete via is_active=false) e tentar recriar
--      com a mesma sigla, o sistema retornava "Sigla ja cadastrada" porque
--      a constraint UNIQUE simples em organizations.acronym nao distinguia
--      OMs ativas de inativas. Substitui por um indice parcial unico que
--      so verifica duplicidade entre OMs ativas (is_active = true).
--   2. O campo CERTIFICATE_BUNDLE tinha descricao confusa e ficava na
--      categoria "certificados". Atualiza a descricao para algo mais claro
--      e move para a categoria "avancado" (uso nao rotineiro).
--
-- Idempotente: seguro para re-executar.
-- Execucao:
--   psql -U seeder -d seederlinux -f install/migration_soft_delete_acronym.sql
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. organizations.acronym: UNIQUE simples -> indice parcial (so ativos)
-- ---------------------------------------------------------------------------

-- Remover a constraint UNIQUE simples, se existir (nome padrao do PostgreSQL).
ALTER TABLE organizations DROP CONSTRAINT IF EXISTS organizations_acronym_key;

-- Remover qualquer indice antigo de mesmo nome que possa ter ficado.
DROP INDEX IF EXISTS organizations_acronym_key;

-- Criar o indice parcial unico: sigla so e unica entre OMs ativas.
-- Permite recriar uma OM com a sigla de uma OM anteriormente deletada.
CREATE UNIQUE INDEX IF NOT EXISTS idx_organizations_acronym_active
    ON organizations (acronym) WHERE is_active = TRUE;

-- ---------------------------------------------------------------------------
-- 2. CERTIFICATE_BUNDLE: descricao mais clara + categoria "avancado"
-- ---------------------------------------------------------------------------

UPDATE variable_definitions
SET
    description = 'URL para download do pacote de certificados CA institucionais (formato .tar.gz). Deixe vazio se nao houver certificados personalizados.',
    category = 'avancado'
WHERE name = 'CERTIFICATE_BUNDLE';
