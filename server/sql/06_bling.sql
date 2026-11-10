-- Tokens OAuth do Bling por empresa (tenant). Idempotente.
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS bling_access_token  TEXT;
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS bling_refresh_token TEXT;
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS bling_token_expira_em TIMESTAMPTZ;
