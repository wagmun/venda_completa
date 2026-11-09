-- =============================================================================
-- Schema do banco central (Fonte Única da Verdade) — venda_completa
-- PostgreSQL 16. Baseado na nota 6 do documento + tabelas de clientes/itens.
-- Idempotente: pode rodar várias vezes (DROP + CREATE).
-- =============================================================================

DROP TABLE IF EXISTS bank_slips CASCADE;
DROP TABLE IF EXISTS fiscal_invoices CASCADE;
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS inventory CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS devices CASCADE;
DROP TABLE IF EXISTS sellers CASCADE;
DROP TABLE IF EXISTS tenants CASCADE;

-- -----------------------------------------------------------------------------
-- 1. Empresas (tenants) e configuração fiscal
-- -----------------------------------------------------------------------------
CREATE TABLE tenants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    razao_social VARCHAR(150) NOT NULL,
    nome_fantasia VARCHAR(150),
    cnpj VARCHAR(14) NOT NULL UNIQUE,
    inscricao_estadual VARCHAR(20) NOT NULL,
    uf VARCHAR(2) NOT NULL DEFAULT 'SP',
    regime_tributario VARCHAR(20) NOT NULL DEFAULT 'SimplesNacional',
    certificado_a1_path VARCHAR(255),
    ambiente_sefaz INT NOT NULL DEFAULT 2, -- 1: Produção, 2: Homologação
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_tenants_cnpj ON tenants(cnpj);

-- -----------------------------------------------------------------------------
-- 2. Vendedores e dispositivos
-- -----------------------------------------------------------------------------
CREATE TABLE sellers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    nome VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    cpf VARCHAR(11) NOT NULL,
    senha_hash VARCHAR(255) NOT NULL,
    role VARCHAR(20) NOT NULL DEFAULT 'vendedor', -- 'admin' (painel web) ou 'vendedor' (app)
    faixa_nosso_numero_inicio BIGINT NOT NULL DEFAULT 1,
    faixa_nosso_numero_fim BIGINT NOT NULL DEFAULT 1000,
    nosso_numero_atual BIGINT NOT NULL DEFAULT 1,
    ativo BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_sellers_tenant ON sellers(tenant_id);
CREATE INDEX idx_sellers_email ON sellers(email);

CREATE TABLE devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    seller_id UUID NOT NULL REFERENCES sellers(id) ON DELETE CASCADE,
    device_uuid VARCHAR(100) NOT NULL UNIQUE,
    serie_fiscal_nfc INT NOT NULL,
    serie_fiscal_nfe INT NOT NULL,
    proximo_numero_nfc INT NOT NULL DEFAULT 1,
    proximo_numero_nfe INT NOT NULL DEFAULT 1,
    ativo BOOLEAN DEFAULT TRUE
);
CREATE INDEX idx_devices_tenant_seller ON devices(tenant_id, seller_id);

-- -----------------------------------------------------------------------------
-- 3. Produtos e estoque (físico vs. reservado vs. cota offline)
-- -----------------------------------------------------------------------------
CREATE TABLE products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    codigo_ean VARCHAR(14) NOT NULL,
    sku VARCHAR(50) NOT NULL,
    descricao VARCHAR(150) NOT NULL,
    preco_venda NUMERIC(12, 2) NOT NULL,
    ncm VARCHAR(8) NOT NULL,
    cest VARCHAR(7),
    unidade_medida VARCHAR(6) DEFAULT 'UN',
    ativo BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_product_tenant_sku UNIQUE (tenant_id, sku)
);
CREATE INDEX idx_products_tenant_ean ON products(tenant_id, codigo_ean);

CREATE TABLE inventory (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    qtd_fisica NUMERIC(12, 4) NOT NULL DEFAULT 0,
    qtd_reservada NUMERIC(12, 4) NOT NULL DEFAULT 0,
    cota_offline NUMERIC(12, 4) NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_inventory_tenant_product UNIQUE (tenant_id, product_id)
);

CREATE VIEW vw_available_inventory AS
SELECT
    i.tenant_id,
    i.product_id,
    p.sku,
    p.descricao,
    i.qtd_fisica,
    i.qtd_reservada,
    (i.qtd_fisica - i.qtd_reservada) AS qtd_disponivel
FROM inventory i
JOIN products p ON p.id = i.product_id;

-- -----------------------------------------------------------------------------
-- 4. Clientes
-- -----------------------------------------------------------------------------
CREATE TABLE customers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    nome VARCHAR(150) NOT NULL,
    cpf_cnpj VARCHAR(14) NOT NULL,
    email VARCHAR(100),
    telefone VARCHAR(20),
    cidade VARCHAR(100),
    uf VARCHAR(2),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_customer_tenant_doc UNIQUE (tenant_id, cpf_cnpj)
);
CREATE INDEX idx_customers_tenant ON customers(tenant_id);

-- -----------------------------------------------------------------------------
-- 5. Pedidos, itens, notas fiscais e boletos
-- -----------------------------------------------------------------------------
CREATE TABLE orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_order_id VARCHAR(60) UNIQUE, -- id gerado no app (ORD-...) p/ idempotência
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    seller_id UUID NOT NULL REFERENCES sellers(id),
    device_id UUID REFERENCES devices(id),
    customer_id UUID REFERENCES customers(id),
    cliente_nome VARCHAR(150) NOT NULL,
    cliente_cpf_cnpj VARCHAR(14) NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'SINCRONIZADO',
    forma_pagamento VARCHAR(30) NOT NULL DEFAULT 'DINHEIRO',
    valor_total NUMERIC(12, 2) NOT NULL,
    created_at_device TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    synced_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_orders_tenant_seller ON orders(tenant_id, seller_id);

CREATE TABLE order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id),
    sku VARCHAR(50) NOT NULL,
    descricao VARCHAR(150) NOT NULL,
    quantidade NUMERIC(12, 4) NOT NULL,
    preco_unitario NUMERIC(12, 2) NOT NULL,
    total NUMERIC(12, 2) NOT NULL
);
CREATE INDEX idx_order_items_order ON order_items(order_id);

CREATE TABLE fiscal_invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    modelo VARCHAR(2) NOT NULL,
    serie INT NOT NULL,
    numero INT NOT NULL,
    chave_acesso VARCHAR(44) NOT NULL UNIQUE,
    tp_emis VARCHAR(1) NOT NULL DEFAULT '1',
    xml_assinado TEXT,
    status_sefaz VARCHAR(30) NOT NULL DEFAULT 'AUTORIZADO',
    protocolo_autorizacao VARCHAR(50),
    motivo_rejeicao TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_invoices_tenant_status ON fiscal_invoices(tenant_id, status_sefaz);

CREATE TABLE bank_slips (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    nosso_numero VARCHAR(30) NOT NULL,
    linha_digitavel VARCHAR(60) NOT NULL,
    qr_code_pix TEXT,
    valor NUMERIC(12, 2) NOT NULL,
    data_vencimento DATE NOT NULL,
    status VARCHAR(20) DEFAULT 'EMITIDO'
);
