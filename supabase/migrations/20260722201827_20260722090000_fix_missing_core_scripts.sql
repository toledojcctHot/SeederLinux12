-- Fix core_network.sh: rename to core_dns.sh and set correct order
UPDATE scripts SET filename = 'core_dns.sh', name = 'Configuracao de DNS', execution_order = 1 WHERE filename = 'core_network.sh' AND is_core = TRUE;
