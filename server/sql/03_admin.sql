-- =============================================================================
-- Papel de administrador + usuários admin por empresa (idempotente).
-- Admin acessa o painel web; vendedor acessa o app. Senha demo: 123456.
-- =============================================================================

ALTER TABLE sellers
  ADD COLUMN IF NOT EXISTS role VARCHAR(20) NOT NULL DEFAULT 'vendedor';

-- Um administrador por empresa (ON CONFLICT no email único => idempotente).
INSERT INTO sellers (tenant_id, nome, email, cpf, senha_hash, role,
                     faixa_nosso_numero_inicio, faixa_nosso_numero_fim, nosso_numero_atual)
SELECT t.id, 'Administrador', m.email, '00000000000', 'demo$123456', 'admin', 9000, 9999, 9000
FROM tenants t
JOIN (VALUES
  ('Auto Pecas Veloz', 'admin@autopecas.com'),
  ('Oficina Boa',      'admin@oficinaboa.com'),
  ('Mercado Central',  'admin@demo.com')
) AS m(fantasia, email) ON m.fantasia = t.nome_fantasia
ON CONFLICT (email) DO NOTHING;
