-- =============================================================================
-- Seed de dados fictícios — venda_completa
-- 3 empresas, vendedores, dispositivos, clientes, produtos, estoque e pedidos.
-- Idempotente: limpa os dados antes de inserir (mantém o schema).
-- Os e-mails dos vendedores batem com o diretório demo do app.
-- Senha de todos (demo): "123456".
-- =============================================================================

TRUNCATE bank_slips, fiscal_invoices, order_items, orders, customers,
         inventory, products, devices, sellers, tenants RESTART IDENTITY CASCADE;

-- -----------------------------------------------------------------------------
-- EMPRESA 1: Auto Peças Veloz  (tenant lógico "empresa_autopecas")
-- -----------------------------------------------------------------------------
WITH t AS (
  INSERT INTO tenants (razao_social, nome_fantasia, cnpj, inscricao_estadual, regime_tributario, ambiente_sefaz)
  VALUES ('Auto Pecas Veloz LTDA', 'Auto Pecas Veloz', '11222333000181', '110420482', 'SimplesNacional', 2)
  RETURNING id
),
s1 AS (
  INSERT INTO sellers (tenant_id, nome, email, cpf, senha_hash, faixa_nosso_numero_inicio, faixa_nosso_numero_fim, nosso_numero_atual)
  SELECT id, 'Joao da Silva', 'joao@autopecas.com', '12345678901', 'demo$123456', 1000, 1999, 1000 FROM t
  RETURNING id, tenant_id
),
s2 AS (
  INSERT INTO sellers (tenant_id, nome, email, cpf, senha_hash, faixa_nosso_numero_inicio, faixa_nosso_numero_fim, nosso_numero_atual)
  SELECT id, 'Maria Souza', 'maria@gmail.com', '98765432100', 'demo$123456', 2000, 2999, 2000 FROM t
  RETURNING id, tenant_id
),
d1 AS (
  INSERT INTO devices (tenant_id, seller_id, device_uuid, serie_fiscal_nfc, serie_fiscal_nfe)
  SELECT tenant_id, id, 'device-autopecas-joao-01', 1, 1 FROM s1
  RETURNING id
),
d2 AS (
  INSERT INTO devices (tenant_id, seller_id, device_uuid, serie_fiscal_nfc, serie_fiscal_nfe)
  SELECT tenant_id, id, 'device-autopecas-maria-02', 2, 2 FROM s2
  RETURNING id
),
cli AS (
  INSERT INTO customers (tenant_id, nome, cpf_cnpj, email, telefone, cidade, uf)
  SELECT id, c.nome, c.doc, c.email, c.fone, c.cidade, 'SP'
  FROM t, (VALUES
    ('Oficina do Ze', '22333444000199', 'contato@oficinadoze.com', '11988887777', 'Sao Paulo'),
    ('Carlos Mecanico', '33444555667', 'carlos@email.com', '11977776666', 'Guarulhos'),
    ('Transportadora Rapida', '44555666000177', 'fiscal@rapida.com', '1133334444', 'Osasco')
  ) AS c(nome, doc, email, fone, cidade)
  RETURNING id
),
prod AS (
  INSERT INTO products (tenant_id, codigo_ean, sku, descricao, preco_venda, ncm, unidade_medida)
  SELECT id, p.ean, p.sku, p.descricao, p.preco, p.ncm, 'UN'
  FROM t, (VALUES
    ('7891000200101','AP-001','Oleo de Motor 5W30 Sintetico 1L',54.90,'27101932'),
    ('7891000200118','AP-002','Oleo de Motor 15W40 Semissint. 1L',38.50,'27101932'),
    ('7891000200125','AP-003','Filtro de Oleo Automotivo',29.90,'84212300'),
    ('7891000200132','AP-004','Filtro de Ar Esportivo',89.90,'84213100'),
    ('7891000200149','AP-005','Fluido de Freio DOT4 500ml',19.50,'38190000'),
    ('7891000200156','AP-006','Aditivo Radiador Concentrado 1L',24.00,'38200000'),
    ('7891000200163','AP-007','Palheta Limpador Para-brisa 20pol',39.90,'85122021'),
    ('7891000200170','AP-008','Lampada Farol H4 12V 60/55W',15.75,'85392990'),
    ('7891000200187','AP-009','Pastilha de Freio Dianteira par',119.90,'87083090'),
    ('7891000200194','AP-010','Vela de Ignicao Iridium',44.90,'85111000'),
    ('7891000200200','AP-011','Correia Dentada Reforcada',78.00,'40103500'),
    ('7891000200217','AP-012','Bateria 60Ah Selada',389.90,'85071000'),
    ('7891000200224','AP-013','Amortecedor Dianteiro',229.90,'87088000'),
    ('7891000200231','AP-014','Disco de Freio Ventilado',159.90,'87083090')
  ) AS p(ean, sku, descricao, preco, ncm)
  RETURNING id, tenant_id
)
INSERT INTO inventory (tenant_id, product_id, qtd_fisica, qtd_reservada, cota_offline)
SELECT tenant_id, id, (40 + (random()*60)::int), 0, 0 FROM prod;

-- -----------------------------------------------------------------------------
-- EMPRESA 2: Oficina Boa Ferramentas  (tenant lógico "empresa_oficina_boa")
-- -----------------------------------------------------------------------------
WITH t AS (
  INSERT INTO tenants (razao_social, nome_fantasia, cnpj, inscricao_estadual, regime_tributario, ambiente_sefaz)
  VALUES ('Oficina Boa Ferramentas ME', 'Oficina Boa', '55666777000155', '220530111', 'SimplesNacional', 2)
  RETURNING id
),
s1 AS (
  INSERT INTO sellers (tenant_id, nome, email, cpf, senha_hash, faixa_nosso_numero_inicio, faixa_nosso_numero_fim, nosso_numero_atual)
  SELECT id, 'Ana Pereira', 'ana@oficinaboa.com', '11122233344', 'demo$123456', 1000, 1999, 1000 FROM t
  RETURNING id, tenant_id
),
d1 AS (
  INSERT INTO devices (tenant_id, seller_id, device_uuid, serie_fiscal_nfc, serie_fiscal_nfe)
  SELECT tenant_id, id, 'device-oficina-ana-01', 1, 1 FROM s1
  RETURNING id
),
cli AS (
  INSERT INTO customers (tenant_id, nome, cpf_cnpj, email, telefone, cidade, uf)
  SELECT id, c.nome, c.doc, c.email, c.fone, c.cidade, 'RJ'
  FROM t, (VALUES
    ('Serralheria Forte', '66777888000133', 'vendas@forte.com', '2122223333', 'Rio de Janeiro'),
    ('Pedro Marceneiro', '55666777889', 'pedro@email.com', '21999998888', 'Niteroi')
  ) AS c(nome, doc, email, fone, cidade)
  RETURNING id
),
prod AS (
  INSERT INTO products (tenant_id, codigo_ean, sku, descricao, preco_venda, ncm, unidade_medida)
  SELECT id, p.ean, p.sku, p.descricao, p.preco, p.ncm, 'UN'
  FROM t, (VALUES
    ('7892000300101','OF-001','Chave de Fenda Phillips 1/4pol',12.90,'82054000'),
    ('7892000300118','OF-002','Jogo de Soquetes 1/2pol 10 pecas',149.90,'82041100'),
    ('7892000300125','OF-003','Alicate Universal 8pol',34.90,'82032000'),
    ('7892000300132','OF-004','Martelo Unha 25mm Cabo Fibra',42.00,'82055900'),
    ('7892000300149','OF-005','Graxa de Litio 500g',21.90,'34031900'),
    ('7892000300156','OF-006','Desengripante Spray 300ml',17.50,'27101259'),
    ('7892000300163','OF-007','Estopa Branca Pacote 1kg',14.90,'63109000'),
    ('7892000300170','OF-008','Luva de Raspa Reforcada par',11.90,'42032910'),
    ('7892000300187','OF-009','Disco de Corte 7pol Inox',8.90,'68042290'),
    ('7892000300194','OF-010','Trena 5m Emborrachada',24.90,'90178010'),
    ('7892000300200','OF-011','Parafusadeira Furadeira 12V',299.90,'84672100'),
    ('7892000300217','OF-012','Oculos de Protecao Incolor',9.90,'90049000'),
    ('7892000300224','OF-013','Fita Isolante 19mm x 20m',6.50,'39191010')
  ) AS p(ean, sku, descricao, preco, ncm)
  RETURNING id, tenant_id
)
INSERT INTO inventory (tenant_id, product_id, qtd_fisica, qtd_reservada, cota_offline)
SELECT tenant_id, id, (30 + (random()*100)::int), 0, 0 FROM prod;

-- -----------------------------------------------------------------------------
-- EMPRESA 3: Mercado Central  (tenant lógico "empresa_demo")
-- -----------------------------------------------------------------------------
WITH t AS (
  INSERT INTO tenants (razao_social, nome_fantasia, cnpj, inscricao_estadual, regime_tributario, ambiente_sefaz)
  VALUES ('Mercado Central Comercio LTDA', 'Mercado Central', '77888999000122', '330640222', 'SimplesNacional', 2)
  RETURNING id
),
s1 AS (
  INSERT INTO sellers (tenant_id, nome, email, cpf, senha_hash, faixa_nosso_numero_inicio, faixa_nosso_numero_fim, nosso_numero_atual)
  SELECT id, 'Vendedor Demo', 'demo@demo.com', '00011122233', 'demo$123456', 1000, 1999, 1000 FROM t
  RETURNING id, tenant_id
),
d1 AS (
  INSERT INTO devices (tenant_id, seller_id, device_uuid, serie_fiscal_nfc, serie_fiscal_nfe)
  SELECT tenant_id, id, 'device-demo-01', 1, 1 FROM s1
  RETURNING id
),
cli AS (
  INSERT INTO customers (tenant_id, nome, cpf_cnpj, email, telefone, cidade, uf)
  SELECT id, c.nome, c.doc, c.email, c.fone, c.cidade, 'MG'
  FROM t, (VALUES
    ('Consumidor Final', '00000000000', NULL, NULL, 'Belo Horizonte'),
    ('Padaria Pao Quente', '88999000000111', 'padaria@email.com', '3133334444', 'Contagem')
  ) AS c(nome, doc, email, fone, cidade)
  RETURNING id
),
prod AS (
  INSERT INTO products (tenant_id, codigo_ean, sku, descricao, preco_venda, ncm, unidade_medida)
  SELECT id, p.ean, p.sku, p.descricao, p.preco, p.ncm, 'UN'
  FROM t, (VALUES
    ('7893000400101','DM-001','Agua Mineral sem Gas 500ml',2.50,'22011000'),
    ('7893000400118','DM-002','Refrigerante Cola Lata 350ml',4.50,'22021000'),
    ('7893000400125','DM-003','Cafe Torrado e Moido 500g',18.90,'09012100'),
    ('7893000400132','DM-004','Biscoito Recheado Chocolate',3.90,'19053100'),
    ('7893000400149','DM-005','Arroz Branco Tipo 1 5kg',27.90,'10063021'),
    ('7893000400156','DM-006','Feijao Carioca 1kg',8.90,'07133319'),
    ('7893000400163','DM-007','Oleo de Soja 900ml',7.50,'15079011'),
    ('7893000400170','DM-008','Sabao em Po 1kg',12.90,'34022000'),
    ('7893000400187','DM-009','Detergente Neutro 500ml',2.90,'34022000'),
    ('7893000400194','DM-010','Papel Higienico 12 rolos',21.90,'48180910'),
    ('7893000400200','DM-011','Leite UHT Integral 1L',5.20,'04012010'),
    ('7893000400217','DM-012','Acucar Refinado 1kg',4.80,'17019900')
  ) AS p(ean, sku, descricao, preco, ncm)
  RETURNING id, tenant_id
)
INSERT INTO inventory (tenant_id, product_id, qtd_fisica, qtd_reservada, cota_offline)
SELECT tenant_id, id, (50 + (random()*150)::int), 0, 0 FROM prod;
