-- Link do boleto (PDF) gerado pelo Bling quando a venda é paga em boleto.
ALTER TABLE fiscal_invoices ADD COLUMN IF NOT EXISTS link_boleto TEXT;
