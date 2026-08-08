-- Fix execution_order for all core scripts
-- core_legados.sh and core_apps.sh need internet, must run BEFORE core_domain.sh
UPDATE scripts SET execution_order = 4 WHERE filename = 'core_legados.sh';
UPDATE scripts SET execution_order = 5 WHERE filename = 'core_apps.sh';
UPDATE scripts SET execution_order = 6 WHERE filename = 'core_domain.sh';
UPDATE scripts SET execution_order = 7 WHERE filename = 'core_ssh.sh';
UPDATE scripts SET execution_order = 8 WHERE filename = 'core_browser.sh';
UPDATE scripts SET execution_order = 9 WHERE filename = 'core_inventory.sh';
UPDATE scripts SET execution_order = 10 WHERE filename = 'core_printers.sh';
UPDATE scripts SET execution_order = 11 WHERE filename = 'core_vnc.sh';
UPDATE scripts SET execution_order = 12 WHERE filename = 'core_conky.sh';
UPDATE scripts SET execution_order = 13 WHERE filename = 'core_config.sh';
UPDATE scripts SET execution_order = 14 WHERE filename = 'core_branding.sh';
UPDATE scripts SET execution_order = 15 WHERE filename = 'core_logon.sh';
UPDATE scripts SET execution_order = 16 WHERE filename = 'core_password_change.sh';
UPDATE scripts SET execution_order = 17 WHERE filename = 'core_logoff.sh';
UPDATE scripts SET execution_order = 18 WHERE filename = 'core_session_lightdm.sh';
UPDATE scripts SET execution_order = 19 WHERE filename = 'core_session_gdm3.sh';
UPDATE scripts SET execution_order = 20 WHERE filename = 'core_session_sddm.sh';
UPDATE scripts SET execution_order = 21 WHERE filename = 'core_agent.sh';
UPDATE scripts SET execution_order = 22 WHERE filename = 'core_proxy.sh';

-- Ensure scripts that were missing are active
UPDATE scripts SET is_active = true WHERE filename IN ('core_ssh.sh', 'core_agent.sh', 'core_password_change.sh');
