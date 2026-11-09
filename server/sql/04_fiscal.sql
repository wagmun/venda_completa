-- =============================================================================
-- UF da empresa (para montar a chave de acesso / cUF). Idempotente.
-- =============================================================================
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS uf VARCHAR(2) NOT NULL DEFAULT 'SP';

UPDATE tenants SET uf = 'SP' WHERE nome_fantasia = 'Auto Pecas Veloz';
UPDATE tenants SET uf = 'RJ' WHERE nome_fantasia = 'Oficina Boa';
UPDATE tenants SET uf = 'MG' WHERE nome_fantasia = 'Mercado Central';
