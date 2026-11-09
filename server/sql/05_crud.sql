-- Soft-delete de produtos (desativa em vez de apagar; preserva vendas). Idempotente.
ALTER TABLE products ADD COLUMN IF NOT EXISTS ativo BOOLEAN NOT NULL DEFAULT TRUE;
