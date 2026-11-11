-- NF-e 55 emitida via Bling: id da nota no Bling + link do DANFE.
-- A chave de acesso só existe após autorização, então passa a aceitar NULL.
ALTER TABLE fiscal_invoices ADD COLUMN IF NOT EXISTS bling_nota_id BIGINT;
ALTER TABLE fiscal_invoices ADD COLUMN IF NOT EXISTS link_danfe TEXT;
ALTER TABLE fiscal_invoices ALTER COLUMN chave_acesso DROP NOT NULL;

-- Configuração fiscal por empresa para a emissão no Bling.
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS bling_natureza_operacao_id BIGINT;
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS bling_loja_id BIGINT;
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS bling_forma_pagamento_boleto_id BIGINT;
