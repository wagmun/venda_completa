# Compilação 100% Fiel das 26 Notas do Caderno (Ordem Cronológica)

Este documento reúne o texto exato, integral e literal de cada uma das 26 notas gravadas no caderno **venda_completa**, organizadas da nota mais antiga à mais recente.

---

## 1. Arquitetura Vendas Offline

Aqui está o que encontrei sobre **requisitos técnicos e arquitetura para aplicativo de força de vendas com emissão fiscal e sincronização de estoque**:

Para atender a esses requisitos, o projeto exige uma **arquitetura Offline-First com sincronização orientada a eventos em tempo real**, suporte a **contingência fiscal (NFC-e/NF-e)** e um **modelo atômico de consistência de estoque distribuído**.

**Principais pilares identificados:**
1. **Arquitetura Offline-First & Banco Local**: O aplicativo deve utilizar um banco de dados embutido no dispositivo (como SQLite, Realm ou WatermelonDB). As vendas são gravadas localmente primeiro e enfileiradas para transmissão (*Outbox Pattern*), permitindo que o vendedor continue trabalhando mesmo sem internet.
2. **Emissão Fiscal Móvel em Contingência**: Para emitir notas fiscais no campo (NFC-e modelo 65 ou NF-e modelo 55) em locais sem sinal de internet, utiliza-se a **contingência offline (tpEmis=9)**. O aplicativo assina o XML localmente via Certificado Digital A1 (ou API parceira), gera o DANFE para impressão em impressora Bluetooth e retransmite a nota para a SEFAZ assim que restabelecer a conexão (dentro do prazo legal de 24h).
3. **Sincronização em Tempo Real entre Vendedores**: O servidor central (backend) utiliza protocolos bidirecionais de baixa latência como **WebSockets, Server-Sent Events (SSE) ou MQTT/Push Notifications**. Quando qualquer vendedor conclui uma venda e sincroniza com o servidor, um evento de *broadcast* notifica e atualiza o saldo de estoque nos aplicativos de todos os outros vendedores conectados.
4. **Prevenção de Furo de Estoque (Overselling)**: O sistema diferencia *estoque físico* de *estoque reservado*. Em ambientes offline com múltiplos vendedores operando ao mesmo tempo, utilizam-se técnicas de reserva temporária online ou alocação de cotas de estoque por dispositivo/vendedor para evitar que um mesmo produto seja vendido duas vezes.

📥 O relatório completo de pesquisa está incluído como a primeira fonte no cartão de importação abaixo — importe-o para conversar com os achados diretamente no seu caderno.

---

## 2. Venda Unificada Móvel

A substituição do fluxo **Pedido OK + Bling** por um aplicativo único representa uma grande evolução operacional: o ciclo de vendas deixa de ser fracionado em duas etapas (digitação do pedido na rua e faturamento posterior no escritório) e passa a ser **totalmente concluído no ponto de venda em poucos segundos**.

Ao integrar o leitor de código de barras, faturamento fiscal e geração de cobrança no mesmo aplicativo, o fluxo técnico da operação em campo passa a funcionar da seguinte forma:

##### 1. Fluxo de Venda Unificado em Campo
* **Bipagem e Montagem do Carrinho (Leitor de Código de Barras):**
    * O aplicativo utilizará a **câmera do smartphone/tablet** (via bibliotecas de visão computacional) ou **leitores de código de barras físicos via Bluetooth/HID** para escaneamento ultrarrápido dos SKUs.
    * O preço, impostos e a disponibilidade de estoque são validados instantaneamente no banco de dados local do dispositivo.
* **Baixa de Estoque e Reserva:**
    * No momento em que o pedido é finalizado, a baixa do saldo vendável é registrada imediatamente no dispositivo.
    * O pedido entra na fila local (*Outbox Pattern*) e, assim que o sinal de internet estiver ativo, o servidor central propaga a atualização para os celulares de todos os outros vendedores em tempo real.
* **Emissão da Nota Fiscal no Local (NFC-e / NF-e):**
    * **Com internet:** O aplicativo envia os dados para a API fiscal / SEFAZ, recebe o XML assinado e a Chave de Acesso autorizada em segundos.
    * **Sem internet (Contingência Offline tpEmis=9):** O aplicativo utiliza o **Certificado Digital A1** embarcado (ou gerenciado via API) para assinar o XML localmente, gera o DANFE offline e entrega ao cliente. A transmissão para a SEFAZ ocorre em segundo plano assim que a conexão retornar (dentro do prazo de 24h).
* **Geração do Boleto Bancário / QR Code Pix:**
    * O aplicativo se conecta à API de pagamentos (ou instituição financeira) para emitir o boleto registrado com linha digitável e QR Code Pix.
    * Em locais sem sinal, o aplicativo pode trabalhar com cálculo local de linha digitável/nosso-número pré-alocado ou registrar a intenção de cobrança para envio junto à nota fiscal ao reconectar.
* **Impressão Física no Cliente:**
    * O aplicativo envia o DANFE simplificado da Nota Fiscal e o Boleto Bancário diretamente para **impressoras térmicas portáteis Bluetooth** (usando comandos de impressão como ESC/POS ou ZPL/CPCL).

##### 2. O que muda na Arquitetura do Sistema
Ao eliminar a dependência do Bling para emissão posterior, o **novo aplicativo e seu backend assumirão 100% da inteligência fiscal e financeira**:

1. **Gestão de Séries e Numeração Fiscal:** Como múltiplos vendedores estarão emitindo notas ao mesmo tempo (e eventualmente offline), cada dispositivo deve possuir uma **série fiscal dedicada** (ex: Vendedor 1 usa Série 1, Vendedor 2 usa Série 2) ou o backend deve controlar rigorosamente a numeração para evitar duplicidade de notas.
2. **Armazenamento e Assinatura com Certificado Digital A1:** O sistema precisará armazenar o Certificado A1 da empresa com segurança no backend ou sincronizar chaves de assinatura para garantir que o dispositivo consiga assinar os XMLs da nota mesmo desconectado.
3. **Resolução de Conflitos e Fila de Sincronização:** As escritas no campo (pedido + nota + boleto) são salvas no banco local (SQLite/Realm) e reexecutadas ordenadamente contra o backend assim que o celular recuperar a internet.

🛒 **Que tal desenharmos a tela do carrinho de compras com a leitura por código de barras e o fluxo de fechamento da venda (Pedido + Nota + Boleto)?**

---

## 3. Fluxo de Vendas

Criei e publiquei o gráfico **fluxograma_vendas_multitenant.png** no seu painel Studio, ilustrando visualmente todo o ciclo de venda, emissão fiscal, cobrança e sincronização com isolamento multi-tenant.

Abaixo está o detalhamento técnico e operacional de cada etapa representada no fluxograma:

##### 🔄 Etapas do Processo de Venda e Sincronização Multi-Tenant

###### 1. Atendimento no Cliente & Montagem do Pedido (App Mobile)
* **Identificação Multi-Tenant:** Ao fazer login, o dispositivo assume o identificador único da empresa (tenant_id). Todas as consultas locais a produtos, clientes e estoque são estritamente filtradas por esse identificador.
* **Bipagem com Leitor de Código de Barras:** O vendedor utiliza a câmera ou leitor Bluetooth para bipar o código EAN/SKU. O app consulta o banco de dados embarcado local (SQLite/Realm) em sub-segundos para validar o produto.
* **Baixa Instantânea no Estoque Local:** Ao fechar a compra, o aplicativo abate imediatamente o saldo vendável na base local do aparelho, evitando que o próprio vendedor venda o mesmo item duas vezes em seguida.

###### 2. Emissão Fiscal & Cobrança no Ponto de Venda
* **Emissão Fiscal (NFC-e / NF-e):**
    * *Com internet:* Transmite a nota para a SEFAZ e obtém a autorização em tempo real.
    * *Sem internet (Contingência Offline tpEmis=9):* O app assina o XML localmente com o Certificado Digital A1 embarcado (utilizando a série fiscal exclusiva do vendedor) e autoriza a emissão localmente para não travar o cliente.
* **Geração de Cobrança:** O app gera o **Boleto Bancário** (utilizando faixa de Nosso Número pré-alocada em modo offline) e o **QR Code Pix dinâmico**.
* **Impressão Térmica Bluetooth:** O vendedor imprime instantaneamente no local o **DANFE Simplificado** e a folha do **Boleto Bancário** na impressora portátil de cintura.

###### 3. Persistência na Fila Local (*Outbox Pattern*)
* Todas as informações da transação (Pedido + XML da Nota + Boleto) são armazenadas na **Fila de Outbox Durável** do dispositivo móvel.
* O fluxo de trabalho no campo continua 100% funcional sem depender de conectividade.

###### 4. Replay de Sincronização na Reconexão
* O serviço em segundo plano (*background worker*) do celular monitora a rede. Ao reconectar à internet, ele dispara o **Replay ordenado** da fila *Outbox* para o backend central.

###### 5. Backend Central & Conciliação SEFAZ (Single Source of Truth)
* **Middleware de Autenticação & Isolamento:** O servidor valida o cabeçalho tenant_id e garante que as transações gravem apenas no esquema da respectiva empresa.
* **Conciliação Fiscal:** Envia as notas fiscais emitidas offline para autorização definitiva na SEFAZ (dentro do prazo legal de 24h).
* **Atualização do Banco Autorritativo:** Efutua a baixa definitiva no banco de dados central (SSOT).

###### 6. Barramento de Eventos & Broadcast com Filtro de Tenant
* **Disparo do Evento (Pub/Sub):** O backend publica um evento imutável estoque.atualizado contendo a empresa, o SKU e o novo saldo.
* **Roteamento por WebSocket / Push:** O gateway de tempo real distribui a notificação **estritamente para os dispositivos ativos da mesma empresa (Tenant A)**.
* **Isolamento Garantido:** Vendedores de outras empresas (Tenant B) que utilizam a mesma infraestrutura são filtrados no gateway e **não recebem nenhum dado**, mantendo sigilo e separação total.
* **Atualização Automática no Campo:** Os celulares dos demais vendedores da empresa atualizam seus saldos locais em segundo plano.

💬 **Gostaria que eu detalhasse a estrutura do payload JSON transmitido pelo WebSocket ou as tabelas do banco de dados para suportar o isolamento multi-tenant?**

---

## 4. Arquitetura Multi-Tenant

Para garantir a coexistência segura de múltiplas empresas e vendedores no mesmo aplicativo, o sistema estabelece diferenciações em nível de **arquitetura de dados**, **regras de negócio** e **identificação fiscal**.

##### 🏢 1. O que diferencia uma Empresa de outra (Multi-Tenancy)
Quando duas empresas distintas utilizam a mesma plataforma, a diferenciação ocorre por meio do **isolamento lógico de dados (Multi-Tenant Architecture)**:
* **Identificador de Tenant (tenant_id):** Cada registro no banco de dados central (produtos, estoque, clientes, pedidos e notas) é vinculado ao tenant_id da empresa. Ao fazer login, o aplicativo baixa e consulta estritamente os dados pertencentes àquela empresa.
* **Configurações Fiscais e Jurídicas:** Cada empresa possui seu próprio **CNPJ**, Inscrição Estadual, regras de tributação (ICMS, PIS/COFINS, etc.) e o seu **Certificado Digital A1** exclusivo para a assinatura das notas fiscais.
* **Isolamento de Broadcast em Tempo Real:** O barramento de eventos (WebSockets / Push Notifications) filtra e distribui as atualizações de estoque e vendas **estritamente para os dispositivos ativos da mesma empresa**. Os vendedores da Empresa A nunca recebem notificações nem visualizam saldos da Empresa B.
* **Condições Comerciais e Cobrança:** Tabela de preços, políticas de desconto, limites de crédito e credenciais das contas bancárias para emissão de boletos e Pix são parametrizados individualmente por empresa.

##### 👤 2. O que diferencia um Vendedor de outro (Mesma Empresa)
Entre vendedores pertencentes à mesma empresa, o sistema aplica distinções operacionais e de dispositivo para viabilizar a operação em campo e evitar conflitos de emissão:
* **Identificador do Usuário (user_id / seller_id):** Cada vendedor possui suas credenciais de acesso, perfil de permissões comerciais e vinculação à sua **carteira de clientes**.
* **Série Fiscal Exclusiva por Dispositivo:** Para permitir que múltiplos vendedores emitam notas fiscais (NFC-e / NF-e) em contingência offline (tpEmis=9) sem duplicar numerações perante a SEFAZ, cada vendedor/dispositivo utiliza uma **série fiscal dedicada** (ex.: Vendedor 1 opera na Série 1; Vendedor 2 opera na Série 2) ou um bloco exclusivo de numeração gerido pelo backend.
* **Faixa de Nosso Número para Boletos:** Para a geração de boletos bancários em locais sem sinal de internet, cada vendedor recebe um bloco de **Nosso Número** pré-alocado, garantindo que os boletos impressos em campo não sofram colisão de código de barras ao serem registrados no banco.
* **Cotas de Estoque Distribuído:** Em cenários offline, o sistema pode alocar **cotas de estoque específicas** por dispositivo/vendedor para evitar que dois vendedores vendam a mesma unidade física sem sinal de internet (*overselling*).
* **Fila de Outbox Local:** O smartphone de cada vendedor mantém sua própria **fila de outbox durável** (banco SQLite/Realm local), registrando a sequência ordenada de pedidos, notas e cobranças realizadas naquele aparelho aguardando o *replay* na reconexão.

💡 **Podemos avançar desenhando o modelo das tabelas do banco de dados (esquema SQL com suporte a tenant_id e séries fiscais) ou detalhando os fluxos de autenticação e segurança do vendedor. O que prefere ver em seguida?**

---

## 5. Arquitetura Multi-Tenant (Isolamento Lógico)

A diferenciação entre vendedores e empresas ocorre em duas camadas distintas na arquitetura do sistema: a **camada de tenant (empresa)** e a **camada de dispositivo/usuário (vendedor)**.

##### 1. Diferenciação Entre Empresas Diferentes (*Multi-Tenancy*)
Quando o mesmo aplicativo é utilizado por empresas concorrentes ou distintas, o isolamento é garantido no servidor e no aplicativo por meio de **Multi-Tenancy lógico**:
* **Identificador de Tenant (tenant_id):** Toda tabela e registro no banco de dados central (produtos, saldos, clientes e pedidos) possui uma coluna tenant_id. Ao fazer login, o aplicativo recebe o token autenticado e passa a consultar e salvar dados estritamente associados àquela empresa.
* **Configuração Fiscal e Certificado Digital:** Cada empresa possui seus próprios dados jurídicos (CNPJ, Inscrição Estadual) e seu **Certificado Digital A1** exclusivo para assinatura de NF-e/NFC-e.
* **Filtragem de Notificações em Tempo Real:** O servidor de mensagens (WebSockets/Push) roteia as atualizações de estoque e vendas **estritamente para os dispositivos com o mesmo tenant_id**. Vendedores da Empresa A jamais recebem eventos ou visualizam saldos da Empresa B.

##### 2. Diferenciação Entre Vendedores da Mesma Empresa
Para que múltiplos vendedores da mesma empresa operem de forma independente no campo — inclusive em locais sem sinal de internet —, a diferenciação é feira pelos seguintes identificadores:
* **Identificador do Vendedor (seller_id):** Define a autoria de cada pedido e restringe o acesso à carteira de clientes ou região designada para aquele profissional.
* **Série Fiscal Exclusiva por Dispositivo:** Como a emissão fiscal pode ocorrer em contingência offline (tpEmis=9), cada dispositivo/vendedor utiliza uma **série fiscal dedicada** (ex.: Vendedor 1 usa Série 1; Vendedor 2 usa Série 2). Isso previne a duplicidade de números de nota fiscal perante a SEFAZ durante autorizações assíncronas.
* **Faixa de Nosso Número para Boletos:** Para emitir boletos bancários offline sem internet, cada vendedor recebe um bloco pré-alocado de **Nosso Número**, evitando colisão de código de barras entre as cobranças geradas na rua.
* **Fila de Outbox e Banco Local Próprio:** O aparelho de cada vendedor gerencia seu próprio banco SQLite/Realm local e sua **fila de outbox durável**, reexecutando as transações daquele dispositivo específico na ordem exata de criação assim que a conexão retornar.

💡 Quer que eu prepare o esquema de tabelas SQL mostrando exatamente a estrutura dos campos tenant_id, seller_id e a gestão de séries fiscais?

---

## 6. Modelo SQL Fiscal

Com certeza! Abaixo está o modelo completo em **PostgreSQL** para o banco de dados central (Fonte Única da Verdade), estruturado especificamente para suportar **multi-tenancy**, **identificação de vendedores**, **gerenciamento de estoque** e **emissão fiscal móvel em contingência**.

##### 🗄️ Esquema DDL SQL (PostgreSQL)
```sql
-- =============================================================================
-- 1. ESTRUTURA MULTI-TENANT (EMPRESAS E CONFIGURAÇÕES FISCAIS)
-- =============================================================================

CREATE TABLE tenants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    razao_social VARCHAR(150) NOT NULL,
    nome_fantasia VARCHAR(150),
    cnpj VARCHAR(14) NOT NULL UNIQUE,
    inscricao_estadual VARCHAR(20) NOT NULL,
    regime_tributario VARCHAR(20) NOT NULL DEFAULT 'SimplesNacional',
    certificado_a1_path VARCHAR(255), -- Caminho do certificado digital A1
    ambiente_sefaz INT NOT NULL DEFAULT 2, -- 1: Produção, 2: Homologação
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_tenants_cnpj ON tenants(cnpj);


-- =============================================================================
-- 2. VENDEDORES E DISPOSITIVOS (ISOLAMENTO POR DISPOSITIVO E SÉRIE FISCAL)
-- =============================================================================

CREATE TABLE sellers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    nome VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    cpf VARCHAR(11) NOT NULL,
    faixa_nosso_numero_inicio BIGINT NOT NULL,
    faixa_nosso_numero_fim BIGINT NOT NULL,
    nosso_numero_atual BIGINT NOT NULL,
    ativo BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_sellers_tenant ON sellers(tenant_id);

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


-- =============================================================================
-- 3. PRODUTOS E GESTÃO DE ESTOQUE (FÍSICO VS. RESERVADO VS. DISPONÍVEL)
-- =============================================================================

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
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_product_tenant_sku UNIQUE (tenant_id, sku)
);

CREATE INDEX idx_products_tenant_ean ON products(tenant_id, codigo_ean);

CREATE TABLE inventory (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    qtd_fisica NUMERIC(12, 4) NOT NULL DEFAULT 0,
    qtd_reservada NUMERIC(12, 4) NOT NULL DEFAULT 0,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_inventory_tenant_product UNIQUE (tenant_id, product_id)
);

-- Visão computada do Estoque Disponível para venda
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


-- =============================================================================
-- 4. VENDAS, EMISSÃO FISCAL E COBRANÇA
-- =============================================================================

CREATE TABLE orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    seller_id UUID NOT NULL REFERENCES sellers(id),
    device_id UUID NOT NULL REFERENCES devices(id),
    cliente_nome VARCHAR(150) NOT NULL,
    cliente_cpf_cnpj VARCHAR(14) NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'PENDENTE_SYNC',
    valor_total NUMERIC(12, 2) NOT NULL,
    created_at_device TIMESTAMP WITH TIME ZONE NOT NULL,
    synced_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_orders_tenant_seller ON orders(tenant_id, seller_id);

CREATE TABLE fiscal_invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    modelo VARCHAR(2) NOT NULL,
    serie INT NOT NULL,
    numero INT NOT NULL,
    chave_acesso VARCHAR(44) NOT NULL UNIQUE,
    tp_emis VARCHAR(1) NOT NULL DEFAULT '1',
    xml_assinado TEXT NOT NULL,
    status_sefaz VARCHAR(30) NOT NULL DEFAULT 'OFFLINE',
    protocolo_autorizacao VARCHAR(50),
    motivo_rejeicao TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
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
```

##### 🔑 Principais Destaques dessa Modelagem
1. **Garantia de Isolamento Multi-Tenant (tenant_id):**
    * Todas as tabelas operacionais possuem o campo tenant_id como chave estrangeira com índices associados. Nenhuma requisição ou evento de WebSocket no aplicativo consegue consultar registros sem filtrar obrigatoriamente por essa coluna.
2. **Prevenção de Colisão Fiscal na Contingência Offline (devices.serie_fiscal):**
    * Cada dispositivo possui sua **série fiscal dedicada** (serie_fiscal_nfc e serie_fiscal_nfe). Caso dois vendedores emitam notas offline sem internet ao mesmo tempo, o Vendedor 1 assinará na Série 1 (Nota 100) e o Vendedor 2 na Série 2 (Nota 100), evitando duplicidade de numeração quando as notas forem autorizadas na SEFAZ.
3. **Geração de Boletos Offline (sellers.faixa_nosso_numero):**
    * O banco aloca blocos de nosso_numero exclusivos por vendedor. O aplicativo mobile lê essa faixa para calcular a linha digitável do boleto localmente sem colidir com outros boletos da empresa.
4. **Visão de Disponibilidade de Estoque (vw_available_inventory):**
    * O banco separa o **Estoque Físico** do **Estoque Reservado**. Isso permite que vendas efetuadas em campo entrem como reserva temporária até a confirmação e reconciliação com a SEFAZ.

💡 **Gostaria que eu demonstrasse a consulta SQL para atualização atômica de estoque na chegada de uma venda ou prefere ver a estrutura do payload JSON transmitido via WebSocket?**

---

## 7. Sincronização Offline

Abaixo está o detalhamento técnico dos três pilares solicitados para a construção do aplicativo:

##### 🔄 1. Como Funciona a Sincronização do Estoque
A sincronização de estoque entre os dispositivos de campo e o servidor opera em uma **arquitetura Offline-First orientada a eventos**:

1. **Escrita no Banco Local (*Store Local*):** Quando o vendedor fecha uma venda no aplicativo, o pedido não espera resposta da internet. A baixa do estoque vendável é registrada imediatamente no banco de dados interno do smartphone (ex: SQLite ou Realm).
2. **Fila de Saída Durável (*Outbox Pattern*):** A operação de venda é empacotada como um evento imutável e salva em uma fila de transmissão local no aparelho (*Outbox*).
3. **Replay Ordenado na Reconexão:** Assim que o aplicativo detecta sinal de internet, um serviço em segundo plano envia as vendas pendentes da fila *Outbox* em ordem cronológica para o backend central.
4. **Baixa no Banco Central e Mensageria:** O backend (Fonte Única da Verdade) valida a transação de forma idempotente, atualiza o saldo central no banco de dados e dispara um evento de atualização.
5. **Broadcast em Tempo Real:** O servidor de mensageria (WebSockets, SSE ou Push) distribui a notificação de atualização de estoque **estritamente para os dispositivos dos outros vendedores da mesma empresa (tenant_id)**.
6. **Atualização em Segundo Plano:** Os aplicativos dos demais vendedores recebem o *broadcast* e atualizam seus saldos locais em tempo real sem interromper o uso.

##### 📄 2. Fluxo de Emissão Fiscal em Contingência Offline

Quando a equipe de campo está em locais sem cobertura de internet ou os servidores da SEFAZ ficam indisponíveis, o aplicativo aciona o mecanismo de **contingência offline (tpEmis=9)**:

1. **Assinatura Digital no Dispositivo:** O aplicativo utiliza o **Certificado Digital A1** da empresa (armazenado ou sincronizado no celular) para gerar e assinar o XML da nota fiscal (NFC-e modelo 65 ou NF-e modelo 55) localmente.
2. **Uso de Série Fiscal Exclusiva por Vendedor:** Para evitar a duplicidade de números de nota entre vendedores operando sem internet ao mesmo tempo, cada dispositivo utiliza uma **série fiscal dedicada** (ex: Vendedor 1 assina na Série 1; Vendedor 2 assina na Série 2).
3. **Impressão do DANFE em Campo:** A nota é autorizada localmente no dispositivo e o **DANFE Simplificado** é impresso na hora para o cliente em uma impressora térmica portátil Bluetooth.
4. **Armazenamento no Outbox:** O XML assinado e autorizado localmente fica armazenado na fila *Outbox* do celular.
5. **Transmissão e Autorização Posterior (Até 24h):** Assim que o sinal de internet retorna, o *background worker* retransmite os XMLs pendentes para a SEFAZ para obter o protocolo definitivo de autorização no prazo legal.
6. **Conciliação pelo Backend:** Ao receber o lote, o servidor/API fiscal verifica se o envio original foi recepcionado. Caso haja duplicidade, o backend solicita o cancelamento da nota excedente ou a inutilização da numeração para manter a contabilidade regularizada perante o fisco.

##### 🛡️ 3. Como Prevenir Conflitos de Estoque (*Overselling*)

Vender o mesmo produto duas vezes em ambiente distribuído é prevenido através de estratégias combinadas de modelo de dados e regras operacionais:

* **Separação de Saldo Físico vs. Reservado:** O banco de dados não mantém apenas um saldo fixo. O saldo vendável é calculado como Estoque Físico - Estoque Reservado. Vendas concluídas entram como *reserva* até a conciliação final.
* **Reserva Atômica no Modo Online:** Quando o vendedor tem internet no momento do checkout, o aplicativo faz uma requisição de reserva de curto prazo no backend central antes de fechar o pedido, garantindo o saldo antes da emissão.
* **Alocação de Cotas de Estoque para Modo Offline:** Para operações desconectadas, o backend pré-aloca **cotas de estoque específicas** por dispositivo/vendedor (ex: Vendedor A leva cota de 10 unidades do SKU X; Vendedor B leva cota de 5 unidades). O vendedor só pode vender offline até o limite da sua cota alocada.
* **Operações de Incremento/Decremento Atômico (CRDT-lite):** Em vez de transmitir um valor absoluto de saldo final (ex: "estoque agora é 8"), o aplicativo envia uma instrução de alteração relativa (ex: "decrementar 2 unidades"). Isso garante que a aplicação das operações no servidor seja determinística e idempotente.
* **Resolução por Timestamps / Version Vectors:** Conflitos de concorrência são ordenados pela marca d'água de data/hora de criação no dispositivo ou versões lógicas tratadas na fila do servidor.

📊 **Quer que eu monte um diagrama de sequência detalhando a troca de mensagens WebSocket entre o celular e o backend no momento da venda?**

---

## 8. Arquitetura PDV Mobile

##### 1. Como Funciona o Fechamento de Caixa
Nas aplicações com arquitetura *offline-first*, a finalização do expediente de vendas consiste em um processo de **reconciliação de dados e conciliação fiscal**:
* **Descarregamento da Fila Local (*Outbox Replay*):** O aplicativo verifica se existem pedidos ou cobranças pendentes no armazenamento do dispositivo. Ao detectar a conexão com a internet, o serviço em segundo plano retransmite em ordem cronológica todos os registros da fila *Outbox* para o backend central.
* **Conciliação Fiscal com a SEFAZ:** As notas fiscais (NFC-e/NF-e) emitidas no campo sob o regime de **contingência offline (tpEmis=9)** são enviadas para autorização definitiva na SEFAZ dentro do prazo de até 24 horas. A API fiscal faz o cruzamento de numeração e solicita o cancelamento de eventuais duplicidades ou a inutilização de numerações não recepcionadas.
* **Conferência de Estoque e Totais Financeiros:** O servidor realiza uma rotina de reconciliação comparando os saldos vendidos pelos aplicativos com a fonte única da verdade no banco central, ajustando o estoque físico vs. reservado e consolidando o relatório diário de boletos.

##### 2. Como Configurar o Certificado Digital A1
O **Certificado A1** (arquivo nos formatos .pfx ou .p12 protegido por senha) é a identidade digital da empresa utilizada na validação de documentos fiscais:
* **Vínculo por Empresa (tenant):** Na arquitetura *multi-tenant*, a tabela de empresas (tenants) armazena as credenciais jurídicas (CNPJ, Inscrição Estadual) e o caminho ou chave do certificado (certificado_a1_path).
* **Armazenamento e Assinatura no Dispositivo:** Para viabilizar a assinatura offline de XMLs no meio da rua, a chave do certificado A1 é sincronizada para a memória segura do smartphone e mantida sob **criptografia em repouso**. O aplicativo lê a chave localmente para assinar o XML antes de emitir o DANFE na impressora Bluetooth.
* **Gerenciamento via API Fiscal Intermediária:** Se a opção for por uma API fiscal externa (como a Focus NFe), o certificado A1 fica armazenado no servidor parceiro, que assume o gerenciamento automático da numeração e das tentativas de contingência.

##### 3. Quais Bibliotecas Usar no App Mobile
Para implementar essa pilha tecnológica no ambiente móvel (utilizando frameworks como React Native, Flutter, Kotlin ou Swift), recomendam-se as seguintes bibliotecas:
* **Banco de Dados Local (*Offline Store*):**
    * **SQLite / WatermelonDB / Realm:** Para criação da base local relacional e gerenciamento da fila *Outbox* durável no aparelho.
    * **Sembast / Parse Local Datastore:** Para persistência e consulta offline de objetos no dispositivo (*pinning*).
* **Comunicação e Tempo Real:**
    * **Socket.io / WebSockets (ou MQTT):** Para manter um canal bidirecional aberto com o servidor e receber alertas de *broadcast* de estoque.
    * **Firebase Cloud Messaging (FCM) / APNs:** Para envio de Notificações Push em segundo plano quando a aplicação estiver fechada.
* **Leitura de Código de Barras:**
    * **Vision / CameraKit:** Para escaneamento via câmera do aparelho.
    * **Bluetooth HID:** Para captura direta de dados de leitores de código de barras portáteis acoplados.
* **Impressão Térmica Bluetooth:**
    * **Thermal Printer SDKs / EscPos / ZPLKit:** Bibliotecas para comunicação serial Bluetooth que convertem o DANFE e o Boleto em comandos **ESC/POS**, **ZPL** ou **CPCL** para impressoras portáteis de cintura.
* **Segurança:**
    * **React Native Encrypted Storage / Flutter Secure Storage:** Para guardar tokens JWT e o Certificado A1 com criptografia no hardware do dispositivo.

💡 **Podemos montar um exemplo de código do serviço de sincronização da fila de Outbox ou criar o template do DANFE Simplificado formatado para impressora térmica?**

---

## 9. Sistemas Offline First

##### 1. Como Configurar as Cotas de Estoque Offline
Em arquiteturas *offline-first*, a prevenção de vendas acima do saldo disponível (*overselling*) sem sinal de internet é realizada por meio da **alocação prévia de cotas de estoque por dispositivo/vendedor**:
* **Distribuição de Cotas no Backend:** Antes de ir para o campo, o servidor central (Fonte Única da Verdade) aloca um bloco limitado de produtos para cada dispositivo (ex.: 10 unidades do SKU X para o Vendedor A e 5 unidades para o Vendedor B).
* **Reserva no Banco Central:** No servidor, essas unidades alocadas passam do saldo vendável geral para o **Estoque Reservado**, garantindo que nenhum outro vendedor (mesmo online) venda esses itens.
* **Controle e Débito Local:** O aplicativo armazena essa cota no banco de dados local (SQLite/Realm). Durante as vendas offline, o app abate apenas o saldo da cota individual autorizada para aquele aparelho.
* **Devolução e Reconciliação:** Ao reconectar, o serviço de sincronização processa as vendas efetuadas, efetiva a baixa definitiva no estoque físico do servidor e libera os saldos das cotas offline que não foram utilizados de volta para o estoque geral.

##### 2. Fluxo para Conciliar Notas Emitidas Offline
Quando uma venda é realizada em locais sem cobertura de internet, a emissão fiscal ocorre sob o regime de **contingência offline (tpEmis=9)**:
1. **Geração e Assinatura no Campo:** O aplicativo utiliza o Certificado Digital A1 embarcado e a **série fiscal exclusiva** do dispositivo para assinar o XML localmente, emitir o DANFE impresso via Bluetooth e salvar a nota na **Fila de Outbox** do smartphone.
2. **Rebalanceamento e Transmissão (Até 24h):** Assim que a conexão com a internet é restabelecida, o *background worker* retransmite os XMLs para a SEFAZ dentro do prazo legal de 24 horas.
3. **Tratamento de Duplicidades e Inutilizações (Conciliação SEFAZ):**
    * **Se a tentativa original gerou documento na SEFAZ:** Caso a requisição anterior tenha chegado ao fisco antes da queda de conexão, o sistema **cancela a nota em contingência/duplicada**, mantendo válido o cupom fisicamente entregue ao cliente.
    * **Se a tentativa original não foi recepcionada:** O servidor confirma a autorização da nota emitida em contingência. Se houver falhas na sequência de numeração, o sistema solicita a **inutilização da numeração** perante a SEFAZ para evitar lacunas na contabilidade.
4. **Atualização no Banco Central:** O status da nota é atualizado de OFFLINE para AUTORIZADO, CANCELADO ou INUTILIZADO no esquema central.

##### 3. Como Funciona o Fechamento de Caixa
Nas aplicações de campo, o fechamento diário de caixa é um processo automatizado de **reconciliação tripla** (de dados, financeira e fiscal):
* **Descarregamento do Outbox (Sincronização de Dados):** O aplicativo realiza um *replay* completo da fila local durável, garantindo que 100% dos pedidos, alterações de estado e registros feitos offline no celular tenham sido transmitidos e processados no backend central.
* **Auditoria e Conciliação Fiscal:** O backend varre todas as notas fiscais (NFC-e/NF-e) geradas no dia, confirmando se todos os XMLs emitidos em contingência obtiveram o protocolo de autorização, cancelamento ou inutilização junto à SEFAZ.
* **Conferência Financeira:** O sistema consolida as vendas por meio de pagamento (dinheiro, Pix e boletos bancários gerados no campo utilizando a faixa de *Nosso Número* pré-alocada por vendedor).
* **Fechamento e Reconciliação de Estoque:** O backend compara o saldo físico contra o saldo reservado, cancela reservas expiradas, recolhe as cotas offline não utilizadas e recalcula o saldo real final no banco central (*Single Source of Truth*).

💡 **Quer que eu prepare a especificação técnica do serviço de reconciliação da fila de Outbox ou um exemplo de payload JSON para a sincronização de cotas?**

---

## 10. Aplicativo Flutter Offline

**Não afeta.** O ecossistema do Flutter (Dart) oferece suporte nativo e robusto para banco de dados relacional local (SQLite/sqflite, Drift ou Isar), comunicação via WebSockets, leitura de código de barras e conexões seriais Bluetooth SPP para impressoras térmicas.

Abaixo estão os três códigos e especificações solicitadas para o desenvolvimento do seu aplicativo em Flutter:

##### 1. Código do Serviço de Sincronização da Fila de Outbox (Dart / Flutter)

A implementação do **Outbox Pattern** no Flutter garante que os pedidos criados offline fiquem salvos em um banco de dados SQLite local no dispositivo e sejam retransmitted em segundo plano assim que a conexão com a internet for detectada.

```dart
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';

class OutboxItem {
  final String id; // Idempotency Key (UUID)
  final String tenantId;
  final String eventType;
  final Map<String, dynamic> payload;
  final String status;
  final int retryCount;

  OutboxItem({
    required this.id,
    required this.tenantId,
    required this.eventType,
    required this.payload,
    required this.status,
    required this.retryCount,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'tenant_id': tenantId,
    'event_type': eventType,
    'payload': jsonEncode(payload),
    'status': status,
    'retry_count': retryCount,
    'created_at': DateTime.now().toIso8601String(),
  };
}

class OutboxService {
  final Database db;
  final String apiBaseUrl;

  OutboxService({required this.db, required this.apiBaseUrl});

  /// 1. Insere o pedido e o evento na fila local em uma transação atômica
  Future<void> registrarVendaOffline(Map<String, dynamic> pedido, String sku, double qtd) async {
    await db.transaction((txn) async {
      // Abate o saldo no banco SQLite local do celular
      await txn.rawUpdate(
        'UPDATE local_inventory SET qtd_disponivel = qtd_disponivel - ? WHERE sku = ?',
        [qtd, sku],
      );

      // Insere o evento na fila de Outbox durável
      final outboxItem = OutboxItem(
        id: pedido['id'], // Chave de Idempotência
        tenantId: pedido['tenant_id'],
        eventType: 'order.created',
        payload: pedido,
        status: 'PENDENTE',
        retryCount: 0,
      );

      await txn.insert('outbox', outboxItem.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  /// 2. Worker de Sincronização em Segundo Plano (Replay Loop)
  Future<void> processarFilaOutbox(String userToken) async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) return; // Sem internet

    // Busca registros pendentes em ordem cronológica (FIFO)
    final List<Map<String, dynamic>> pendentes = await db.query(
      'outbox',
      where: 'status = ?',
      whereArgs: ['PENDENTE'],
      orderBy: 'created_at ASC',
    );

    for (var item in pendentes) {
      final String itemId = item['id'];
      final Map<String, dynamic> payload = jsonDecode(item['payload']);

      try {
        final response = await http.post(
          Uri.parse('$apiBaseUrl/sync/vendas'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $userToken',
            'X-Idempotency-Key': itemId, // Evita duplicidade no servidor se a conexão cair no retorno
          },
          body: jsonEncode(payload),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          // Marca como conciliado no SQLite do celular
          await db.update(
            'outbox',
            {'status': 'CONCILIADO'},
            where: 'id = ?',
            whereArgs: [itemId],
          );
        } else {
          await _registrarErro(itemId, item['retry_count'], 'HTTP ${response.statusCode}: ${response.body}');
        }
      } catch (e) {
        await _registrarErro(itemId, item['retry_count'], e.toString());
      }
    }
  }

  Future<void> _registrarErro(String id, int currentRetries, String errorMsg) async {
    await db.update(
      'outbox',
      {
        'retry_count': currentRetries + 1,
        'last_error': errorMsg,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
```

##### 🖨️ 2. Template ESC/POS para Impressão do DANFE NFC-e

Este template gera a sequência de comandos hexadecimais **ESC/POS** enviada via Bluetooth SPP para impressoras térmicas portáteis de 58mm/80mm, formatando a DANFE de contingência emitida no local:

```dart
import 'dart:typed_data';

class EscPosBuilder {
  final List<int> _bytes = [];

  // Comandos de Controle ESC/POS
  static const List<int> cmdInit = [0x1B, 0x40];           // Inicializa a impressora
  static const List<int> alignLeft = [0x1B, 0x61, 0x00];   // Alinhamento à Esquerda
  static const List<int> alignCenter = [0x1B, 0x61, 0x01]; // Alinhamento Centralizado
  static const List<int> boldOn = [0x1B, 0x45, 0x01];      // Negrito Ligado
  static const List<int> boldOff = [0x1B, 0x45, 0x00];     // Negrito Desligado
  static const List<int> feedCut = [0x1D, 0x56, 0x42, 0x00]; // Avanca papel e corta

  void addText(String text, {List<int>? align, bool bold = false}) {
    if (align != null) _bytes.addAll(align);
    if (bold) _bytes.addAll(boldOn);
    _bytes.addAll(text.codeUnits);
    _bytes.addAll([0x0A]); // Quebra de linha (\n)
    if (bold) _bytes.addAll(boldOff);
  }

  void addSeparator() {
    addText('------------------------------------------------', align: alignCenter);
  }

  Uint8List buildDanfeNfce({
    required String razaoSocial,
    required String cnpj,
    required String endereco,
    required List<Map<String, dynamic>> itens,
    required double valorTotal,
    required String chaveAcesso,
    required int serie,
    required int numero,
    required bool isContingencia,
  }) {
    _bytes.addAll(cmdInit);

    // Cabeçalho da Empresa
    addText(razaoSocial, align: alignCenter, bold: true);
    addText('CNPJ: $cnpj', align: alignCenter);
    addText(endereco, align: alignCenter);
    addSeparator();

    // Título do Documento
    addText('DANFE NFC-e - Documento Auxiliar', align: alignCenter, bold: true);
    addText('Nota Fiscal de Consumidor Eletronica', align: alignCenter);

    if (isContingencia) {
      addSeparator();
      addText('EMITIDA EM CONTINGENCIA OFFLINE', align: alignCenter, bold: true);
      addText('Transmitir em ate 24h para a SEFAZ', align: alignCenter);
    }

    addSeparator();

    // Detalhes dos Produtos
    addText('ITEM COD DESCRICAO QTD UN VL UN (R\$) VL TOT(R\$)', align: alignLeft, bold: true);
    for (int i = 0; i < itens.length; i++) {
      final item = itens[i];
      final linha = '${i + 1} ${item['sku']} ${item['descricao']}';
      final valores = '${item['qtd']} UN x ${item['preco']} = ${item['total']}';
      addText(linha, align: alignLeft);
      addText('   $valores', align: alignLeft);
    }

    addSeparator();
    addText('VALOR TOTAL R\$: ${valorTotal.toStringAsFixed(2)}', align: alignLeft, bold: true);
    addSeparator();

    // Informações da Nota e Chave de Acesso
    addText('NFC-e Serie: $serie  Numero: $numero', align: alignCenter);
    addText('Chave de Acesso:', align: alignCenter, bold: true);
    addText(chaveAcesso, align: alignCenter);
    addSeparator();

    // Comando ESC/POS para renderizar o código QR Code da SEFAZ
    _bytes.addAll(alignCenter);
    _bytes.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, 0x08]); // Define tamanho QR
    _bytes.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, 0x30]); // Correção de erro
    final qrBytes = 'chave=$chaveAcesso'.codeUnits;
    final int storeLen = qrBytes.length + 3;
    _bytes.addAll([0x1D, 0x28, 0x6B, storeLen % 256, storeLen ~/ 256, 0x31, 0x50, 0x30]);
    _bytes.addAll(qrBytes);
    _bytes.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30]); // Imprime o QR Code

    addText('\nConsulta via QR Code ou Chave de Acesso', align: alignCenter);
    _bytes.addAll(feedCut);

    return Uint8List.fromList(_bytes);
  }
}
```

##### 📡 3. Estrutura do Payload WebSocket (Multi-Tenant & Event-Driven)

Para sincronizar a baixa de estoque em tempo real para os celulares de todos os outros vendedores conectados da mesma empresa, o backend utiliza um barramento de mensagens via WebSocket com filtro de **Tenant ID**.

###### A. Payload Enviado pelo App após Venda (Client ➔ Server)

```json
{
  "event_id": "evt_987f6543-e21b-12d3-a456-426614174000",
  "action": "publish_event",
  "tenant_id": "tenant_empresa_abc_uuid",
  "seller_id": "seller_vendedor_1_uuid",
  "device_id": "device_tablet_rua_01",
  "timestamp": "2026-11-05T12:00:00Z",
  "event_type": "inventory.debited",
  "data": {
    "order_id": "ord_123456789",
    "items": [
      {
        "product_id": "prod_oleo_5w30_uuid",
        "sku": "789123456",
        "qtd_vendida": 2.0
      }
    ]
  }
}
```

###### B. Payload de Broadcast Transmitido pelo Servidor para Outros Vendedores (Server ➔ Clients da Mesma Empresa)

O gateway WebSocket filtra e roteia o evento **estritamente para as conexões ativas pertencentes ao mesmo tenant_id**, garantindo o isolamento entre empresas concorrentes:

```json
{
  "event_id": "evt_987f6543-e21b-12d3-a456-426614174000",
  "tenant_id": "tenant_empresa_abc_uuid",
  "event_type": "inventory.updated",
  "timestamp": "2026-11-05T12:00:01Z",
  "origin": {
    "seller_id": "seller_vendedor_1_uuid",
    "seller_name": "João da Silva"
  },
  "payload": {
    "product_id": "prod_oleo_5w30_uuid",
    "sku": "789123456",
    "qtd_fisica_central": 100.0,
    "qtd_reservada_total": 15.0,
    "novo_saldo_disponivel": 85.0
  }
}
```

💡 **Gostaria que eu montasse o manipulador WebSocket em Dart (usando a biblioteca web_socket_channel) para receber essa notificação e atualizar o banco SQLite do celular em tempo real?**

---

## 11. Flutter Multiplataforma

**Perfeito!** Ter o Flutter rodando tanto nos **dispositivos móveis (Android/iOS)** quanto nos **computadores (Windows/macOS/Web)** traz um ganho enorme de produtividade, manutenção e padronização para o projeto.

Com **um único código-fonte**, você consegue atender a operação de ponta a ponta:

* **Em Campo (Mobile):** Vendedores na rua com smartphones/tablets, leitor de código de barras via câmera ou Bluetooth, impressora térmica portátil de cintura e banco de dados SQLite embarcado.
* **No Balcão / Escritório (Desktop):** Equipe de vendas interna ou retaguarda utilizando telas maiores, leitores de código de barras USB/HID e impressoras de mesa (USB/Ethernet), **reutilizando 100% da lógica de negócio, regras de tributação, fila de Outbox e sincronização WebSocket**.

##### 🛠️ Ajustes Técnicos Recomendados para a Pilha Multiplataforma (Flutter)

1. **Banco de Dados Único (Mobile + Desktop):**
    * Utilize a biblioteca **drift** (antigo *Moor*) ou sqflite combinada com sqflite_common_ffi no Desktop. O drift é um ORM reativo em Dart que funciona de forma transparente no Android, iOS, Windows, macOS e Linux, permitindo que a **tabela de outbox e os saldos locais** funcionem exatamente da mesma forma em qualquer sistema operacional.
2. **Abstração de Impressão (Bluetooth vs. USB):**
    * Utilize pacotes como o **flutter_pos_printer_platform**, que abstraem a camada de comunicação: ele envia os comandos **ESC/POS** via Bluetooth SPP quando o app estiver rodando no celular, e via USB/Serial/Ethernet quando estiver rodando no computador.
3. **Conectividade e Sincronização:**
    * O pacote **web_socket_channel** e a biblioteca de rede **dio** (com interceptores para a chave de idempotência X-Idempotency-Key) funcionam sem nenhuma alteração entre plataformas.

💡 **Gostaria de estruturar a arquitetura de módulos do projeto em Flutter (organização de pastas e separação entre camada de dados, regras de negócio e telas) ou prefere definir a interface das telas administrativas para desktop?**

---

## 12. Gestão de Estoque Offline

##### 🛡️ 1. Como Lidar com Conflitos de Estoque (Prevenção de *Overselling*)
Vender o mesmo item duas vezes em um ambiente distribuído e desconectado exige combinar estratégias de modelagem de dados e regras operacionais:

* **Separação de Saldo Físico vs. Reservado:** O banco de dados central nunca exibe uma quantidade fixa sem tratamento. O saldo disponível vendável é calculado dinamicamente como Estoque Físico - Estoque Reservado.
* **Reserva Atômica no Modo Online:** Quando o aplicativo possui conexão com a internet durante o checkout, ele efetua uma reserva de curto prazo no backend central antes de fechar o pedido, garantindo o saldo antes do faturamento.
* **Alocação de Cotas de Estoque para Modo Offline:** Para vendas desconectadas, o servidor central pré-aloca **cotas individuais por vendedor/dispositivo** (ex: 10 unidades do SKU X para o Vendedor A). O banco central move essa quantidade para o *Estoque Reservado*, e o aplicativo mobile abate o saldo exclusivamente da sua cota local. Ao reconectar, a cota não utilizada retorna ao saldo geral.
* **Operações de Incremento/Decremento Atômico (CRDT-lite):** Em vez de enviar o valor absoluto do saldo final (ex: "estoque é 8"), o aplicativo transmite uma instrução de variação relativa (ex: "decrementar 2 unidades"). Isso torna a gravação no servidor determinística e idempotente.
* **Resolução por Timestamps e Versões Lógicas:** Conflitos de gravação em concorrência são ordenados pela marca d'água de data/hora no servidor ou por vetores de versão (*version vectors*).

##### 🧮 2. Melhor Estratégia para o Fechamento de Caixa
Nas aplicações de vendas em campo (*offline-first*), o fechamento diário é um processo automatizado de **reconciliação tripla** (dados, fiscal e financeira):

1. **Descarregamento da Fila Local (*Outbox Replay*):** O aplicativo verifica se há pedidos ou notas pendentes no banco SQLite/Drift do celular e dispara o envio ordenado em segundo plano assim que detectar a internet.
2. **Conciliação Fiscal com a SEFAZ:** O backend auditada os documentos emitidos em contingência offline (tpEmis=9):
    * Se a requisição original chegou à SEFAZ antes da queda de sinal, o sistema **cancela a nota duplicada**, mantendo válido o cupom entregue ao cliente.
    * Se a requisição não foi recepcionada, o servidor confirma a autorização em contingência. Em caso de lacunas na numeração, o sistema solicita a **inutilização da numeração** perante a SEFAZ.
3. **Conferência Financeira e Recolhimento de Cotas:** O sistema consolida as vendas por forma de pagamento (dinheiro, Pix e boletos bancários gerados com a faixa de *Nosso Número* pré-alocada). O backend compara o saldo físico com o reservado, cancela cotas offline não utilizadas e recalcula o estoque real definitivo no servidor.

##### 🔑 3. Como Configurar o Certificado Digital A1
O **Certificado A1** (arquivo .pfx ou .p12) é a identidade digital utilizada para assinar as notas fiscais:

* **Assinatura Offline no Dispositivo (Mobile/Desktop):**
    * Para permitir a emissão desconectada na rua, a chave privada do Certificado A1 é baixada após o login e salva na memória segura do dispositivo (utilizando pacotes como flutter_secure_storage) com **criptografia em repouso**.
    * O aplicativo lê essa chave localmente para assinar a estrutura XML da NFC-e/NF-e usando a **série fiscal dedicada do dispositivo** antes de enviar o DANFE para a impressora Bluetooth.
* **Gerenciamento Centralizado via API Parceira:**
    * Caso a integração utilize uma API fiscal dedicada (como a Focus NFe), o arquivo .pfx do certificado fica cadastrado na nuvem vinculado ao tenant_id da empresa.
    * A API parceira assume a gestão automática da sequência de numeração, emissões síncronas e conciliação de contingência.

💡 Que tal definirmos o fluxo de telas no Flutter para o vendedor consultar a sua **Cota de Estoque Atual** e acompanhar o **Status da Fila de Outbox** durante a rotina de vendas?

---

## 13. Arquitetura de Vendas

Aqui está o que encontrei sobre **requisitos técnicos e arquitetura para aplicativo de força de vendas com emissão fiscal e sincronização de estoque**:

Para atender a esses requisitos, o projeto exige uma **arquitetura Offline-First com sincronização orientada a eventos em tempo real**, suporte a **contingência fiscal (NFC-e/NF-e)** e um **modelo atômico de consistência de estoque distribuído**.

**Principais pilares identificados:**
1. **Arquitetura Offline-First & Banco Local**: O aplicativo deve utilizar um banco de dados embutido no dispositivo (como SQLite, Realm ou WatermelonDB). As vendas são gravadas localmente primeiro e enfileiradas para transmissão (*Outbox Pattern*), permitindo que o vendedor continue trabalhando mesmo sem internet.
2. **Emissão Fiscal Móvel em Contingência**: Para emitir notas fiscais no campo (NFC-e modelo 65 ou NF-e modelo 55) em locais sem sinal de internet, utiliza-se a **contingência offline (tpEmis=9)**. O aplicativo assina o XML localmente via Certificado Digital A1 (ou API parceira), gera o DANFE para impressão em impressora Bluetooth e retransmite a nota para a SEFAZ assim que restabelecer a conexão (dentro do prazo legal de 24h).
3. **Sincronização em Tempo Real entre Vendedores**: O servidor central (backend) utiliza protocolos bidirecionais de baixa latência como **WebSockets, Server-Sent Events (SSE) ou MQTT/Push Notifications**. Quando qualquer vendedor conclui uma venda e sincroniza com o servidor, um evento de *broadcast* notifica e atualiza o saldo de estoque nos aplicativos de todos os outros vendedores conectados.
4. **Prevenção de Furo de Estoque (Overselling)**: O sistema diferencia *estoque físico* de *estoque reservado*. Em ambientes offline com múltiplos vendedores operando ao mesmo tempo, utilizam-se técnicas de reserva temporária online ou alocação de cotas de estoque por dispositivo/vendedor para evitar que um mesmo produto seja vendido duas vezes.

📥 O relatório completo de pesquisa está incluído como a primeira fonte no cartão de importação abaixo — importe-o para conversar com os achados diretamente no seu caderno.

---

## 14. Arquitetura de Aplicativos

Para iniciar a construção desse aplicativo, é necessário definir e mapear quatro pilares de informações de negócio, fiscais, de arquitetura e infraestrutura:

##### 1. Definições de Negócio e Governança de Estoque
* **Fonte Única da Verdade:** Qual sistema central será o proprietário autoritativo do estoque (o ERP, um OMS ou o backend do app)?
* **Prevenção de *Overselling* (Venda sem Saldo):** Como a operação lidará com múltiplos vendedores operando ao mesmo tempo? Será adotada uma **reserva dinâmica de estoque** no checkout quando online, ou **alocação de cotas fixas** por vendedor/dispositivo para operações offline?
* **Regras para Falhas de Conexão:** Qual é a política do aplicativo quando o sinal falhar por tempo prolongado — ocultar o produto, permitir a venda com validação posterior ou bloquear vendas de itens críticos?
* **Escopo Geográfico e Logístico:** O saldo exibido precisa considerar estoques de lojas físicas específicas (*ship-from-store*), centrais de distribuição (CDs) ou regiões de entrega específicas?

##### 2. Requisitos Fiscais e Integração SEFAZ
* **Modelo do Documento Fiscal:** A operação emitirá **NFC-e (Modelo 65)** para venda direta ao consumidor final ou **NF-e (Modelo 55)** para vendas B2B/atacado no campo?
* **Controle de Contingência Offline (tpEmis=9):** A geração de chaves, assunção de contingência e controle de numeração/série das notas fiscais serão feitos localmente no dispositivo/backend próprio ou gerenciados por uma API fiscal intermediária?
* **Certificado Digital:** Como será feita a distribuição e armazenamento do **Certificado Digital A1** (embarcado no dispositivo para assinatura local do XML em contingência ou centralizado)?

##### 3. Arquitetura de Dados e Sincronização
* **Banco de Dados Embarcado (*Offline-First*):** Qual tecnologia será adotada no dispositivo móvel para armazenamento local e fila de envio durável (SQLite, Realm, WatermelonDB, etc.)?
* **Políticas de Resolução de Conflitos:** Ao reexecutar transações enviadas da fila local (*Outbox Pattern*), qual regra será usada para lidar com edições simultâneas (Última escrita vence, merge por campo ou estruturas incrementais do tipo *CRDT*)?
* **Mensageria e Sincronização em Tempo Real:** Qual protocolo bidirecional será utilizado pelo servidor para realizar o *broadcast* de atualizações de estoque para todos os vendedores conectados (WebSockets, SSE, MQTT, Kafka, etc.)?

##### 4. Infraestrutura de Campo e Dispositivos
* **Hardware de Campo:** Quais dispositivos serão utilizados pela equipe de vendas (smartphones Android/iOS comuns ou leitores/coletores industriais como Zebra e Honeywell)?
* **Impressão Física:** Haverá necessidade de imprimir o comprovante/DANFE na hora para o cliente via impressoras portáteis Bluetooth (utilizando linguagens de impressão como ZPL ou CPCL)?

💡 **Podemos avançar estruturando um documento com o desenho de arquitetura ou uma proposta de fluxo de dados offline-first para essa aplicação. Qual dessas frentes você gostaria de detalhar primeiro?**

---

## 15. Arquitetura Multi-Tenant (Móvel)

##### 1. Fonte Única da Verdade (Arquitetura do Backend)
A estratégia recomendada para plataformas SaaS e redes de varejo é a utilização de um **servidor central compartilhado (Multi-Tenant SaaS)** com isolamento lógico rígido. Nesse modelo, todas as empresas e vendedores utilizam o mesmo cluster de backend e banco de dados central, mas cada consulta, gravação e evento transmitido é obrigatoriamente filtrado pelo identificador tenant_id. Essa abordagem otimiza os custos de infraestrutura e simplifica as atualizações da aplicação, garantindo total segregação de dados entre concorrentes sem a necessidade de criar e manter servidores dedicados para cada empresa.

##### 2. Estratégia de Desenvolvimento do App em Flutter
A abordagem mais segura e eficiente é o **Desenvolvimento por Fatias Verticais Incrementais (*Vertical Slices*)**. Em vez de desenhar todas as telas de uma vez para depois codificar ou montar componentes isolados, desenvolve-se o fluxo completo tela a tela, integrando cada nova funcionalidade à etapa anterior funcional:

1. **Modelagem Base:** Estrutura do banco local (Drift/SQLite) e serviços de rede.
2. **Fatia 1 (Auth & Sync Inicial):** Tela de Login Multi-Tenant ➔ Validação JWT ➔ Carga do catálogo local.
3. **Fatia 2 (Catálogo & Bipagem):** Tela de produtos ➔ Leitura de código de barras (Câmera/HID) ➔ Abate no estoque local.
4. **Fatia 3 (Checkout & Impressão):** Fechamento de venda ➔ Emissão em contingência NFC-e ➔ Impressão DANFE ESC/POS Bluetooth.
5. **Fatia 4 (Fila de Outbox & Real-time):** Replay da fila offline ➔ Triggers de WebSocket para atualização reativa.

Publiquei no seu painel Studio o manual técnico completo **arquitetura-flutter-vendas-multitenant.md**. O documento detalha a modelagem SQL central e as tabelas em Drift, o código em Dart do worker da fila de Outbox, os diagramas e payloads JSON do WebSocket, o construtor de comandos ESC/POS para impressão do DANFE NFC-e e a organização dos módulos do projeto Flutter em Clean Architecture.

---

## 16. Arquitetura Multi-Tenant Eficiente

**Perfeito! Se a sua prioridade absoluta é a redução de custos de nuvem e de responsabilidade operacional, essa decisão é a mais acertada.**

Manter um **único banco de dados e backend compartilhado (Multi-Tenant com tenant_id)** atende exatamente a esses dois pilares:

1. **Custo Mínimo de Infraestrutura:**
    * Você paga apenas 1 instância de banco de dados e 1 cluster de servidores na nuvem.
    * Elimina-se o custo fixo de provisionar servidores ou instâncias de banco dedicadas para cada nova empresa cadastrada, permitindo atender novos clientes sem aumentar a complexidade ou a fatura da nuvem de forma proporcional.
2. **Responsabilidade Operacional Mínima:**
    * **Atualização Única (*Deploy*):** Correções de bugs, melhorias ou atualizações de banco de dados (*migrations*) são executadas uma única vez no servidor central e ficam disponíveis instantaneamente para todas as empresas.
    * **Gestão de Infraestrutura Unificada:** Rotinas de backup, monitoramento de performance, logs e *failover* ocorrem em um único ambiente centralizado, sem a necessidade de gerenciar pipelines de deploy individuais para múltiplos clientes.
3. **Segurança Simplificada no Banco (PostgreSQL RLS):**
    * Para evitar que a responsabilidade do isolamento fique apenas no código do desenvolvedor (evitando o risco de esquecer uma cláusula WHERE tenant_id = ?), utiliza-se o **Row Level Security (RLS)** nativo do PostgreSQL.
    * O próprio banco de dados passa a filtrar e bloquear o acesso aos dados de outras empresas no nível da conexão SQL, garantindo isolamento total sem poluir a regra de negócio no aplicativo Flutter ou no backend.

🔒 **Quer ver um exemplo prático de como configurar o Row Level Security (RLS) no PostgreSQL para automatizar essa segurança direto no banco de dados?**

---

## 17. Arquitetura Flutter Multi-Tenant

Excelente decisão! O desenvolvimento por **Fatias Verticais (*Vertical Slices*)** é a abordagem mais segura e eficiente para projetos em Flutter: em vez de acumular telas estáticas ou código isolado, cada etapa entrega um fluxo completo e testável — da interface ao banco SQLite e à rede.

Para esclarecer as suas dúvidas e dar início à construção, aqui está a visão das decisões estratégicas e o ponto de partida:

##### ☁️ 1. Opções de Nuvem Baratas (Sem Infraestrutura Física)
Para manter o **custo operacional próximo de zero** no início, você pode rodar o backend e o banco PostgreSQL central em plataformas Serverless / PaaS gerenciadas:

* **Supabase / Render / Railway:** Oferecem instâncias PostgreSQL gerenciadas com suporte a WebSockets/Realtime a partir do plano gratuito (*Free Tier*) ou por apenas **$5 a $10/mês**.
* **Fly.io / Hetzner / DigitalOcean (VPS):** Se preferir subir um container Docker com seu backend em Dart/Node/Go, consegue rodar em servidores pequenos de **$4/mês**, sem precisar comprar hardware.

##### 🛡️ 2. Como Funciona o PostgreSQL RLS (Row Level Security)
Para garantir que uma empresa jamais consiga ler dados de outra sem que você precise poluir todo o código com cláusulas WHERE tenant_id = ..., o próprio PostgreSQL bloqueia o acesso no nível de linha:

```sql
-- 1. Ativa a segurança em nível de linha na tabela
ALTER TABLE products ENABLE ROW LEVEL SECURITY;

-- 2. Define a regra: a consulta só retorna se o tenant_id bater com a sessão ativa
CREATE POLICY tenant_isolation_policy ON products
    FOR ALL
    USING (tenant_id = current_setting('app.current_tenant_id')::uuid);
```

Quando o backend recebe a requisição com o token JWT, ele executa no banco SET LOCAL app.current_tenant_id = 'tenant_id_do_vendedor'. A partir desse milissegundo, o banco ignora automaticamente qualquer registro que pertença a outro tenant_id.

##### 🚀 3. Próximo Passo: Iniciar a "Modelagem Base"
Vamos iniciar a implementação prática pela **Modelagem Base**:

1. **Estrutura de Pastas do Flutter** (Organização em Clean Architecture / Feature Slices).
2. **Configuração da classe do banco local em Drift** (AppDatabase compatível com Mobile e Desktop).

💡 Quer que eu apresente a **estrutura de pastas do projeto em Flutter** e o arquivo de configuração inicial do **Drift** para darmos a largada na Modelagem Base?

---

## 18. Modelagem Base Flutter

Vamos dar a largada na **Modelagem Base** do seu aplicativo em **Flutter**.

Abaixo está a estrutura de pastas do projeto, a configuração multiplataforma do **Drift**, os detalhes da **autenticação multi-tenant** e a implementação do **leitor de código de barras**.

##### 📁 1. Estrutura de Pastas do Projeto Flutter (*Clean Architecture + Feature Slices*)
Esta organização separa a infraestrutura central (*core*) das fatias de negócio (*features*), permitindo que o aplicativo rode com o mesmo código no **Android, iOS, Windows e macOS**:

```text
lib/
├── core/
│   ├── database/
│   │   ├── app_database.dart         # Conexão central do Drift (Mobile + Desktop FFI)
│   │   └── connection/
│   │       ├── native.dart           # Conexão nativa (Android/iOS/Desktop)
│   │       └── web.dart              # Suporte para Web (se necessário)
│   ├── network/
│   │   ├── api_client.dart            # Interceptor HTTP (JWT + X-Idempotency-Key)
│   │   └── websocket_handler.dart     # Conexão real-time via WebSocket com tenant_id
│   └── security/
│       └── secure_storage_service.dart# FlutterSecureStorage (JWT Token + Certificado A1)
├── features/
│   ├── auth/                          # Fatia 1: Autenticação Multi-Tenant
│   │   ├── data/
│   │   └── presentation/
│   ├── catalog/                       # Fatia 2: Produtos e Escaneamento EAN
│   │   ├── data/
│   │   └── presentation/
│   └── sales/                         # Fatias 3 e 4: Checkout, Outbox e DANFE
│       ├── data/
│       └── presentation/
└── main.dart
```

##### 🗄️ 2. Estrutura e Configuração do Drift (app_database.dart)
O código abaixo define a estrutura do banco relacional local usando o **Drift**. Ele habilita suporte nativo para dispositivos móveis e suporte via FFI (sqflite_common_ffi) para executáveis de desktop (Windows/macOS/Linux).

###### Definição das Tabelas (lib/core/database/app_database.dart)

```dart
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

part 'app_database.g.dart';

// Tabela de Produtos / Estoque Local
class LocalInventory extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get sku => text()();
  TextColumn get codigoEan => text()();
  TextColumn get descricao => text()();
  RealColumn get precoVenda => real()();
  RealColumn get qtdDisponivel => real()();

  @override
  Set<Column> get primaryKeys => {id};
}

// Tabela da Fila de Outbox Durável
class Outbox extends Table {
  TextColumn get id => text()(); // Chave de Idempotência (UUID)
  TextColumn get tenantId => text()();
  TextColumn get eventType => text()(); // ex: 'order.created'
  TextColumn get payload => text()();   // JSON completo
  TextColumn get status => text().withDefault(const Constant('PENDENTE'))(); // PENDENTE / CONCILIADO
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKeys => {id};
}

@DriftDatabase(tables: [LocalInventory, Outbox])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;
}

// Abre a conexão SQLite compatível com Mobile e Desktop (FFI)
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'vendas_app.sqlite'));

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      return NativeDatabase.createInBackground(file);
    } else {
      return NativeDatabase.createInBackground(file);
    }
  });
}
```

##### 🔑 3. Detalhamento da Autenticação Multi-Tenant
A autenticação isola completamente a empresa (tenant_id) e o vendedor (seller_id) desde o login:

```
[ App Flutter ] ──(1. Login: email/senha)──> [ Backend Central ]
       │                                             │
       │ <──(2. Retorna JWT com tenant_id)───────────┘
       │
       ├── (3. Grava JWT no SecureStorage)
       └── (4. Requisições HTTP/WS com Header 'Authorization: Bearer JWT')
```

1. **Geração do Token:** Quando o vendedor autentica, o backend envia um **JWT assinado** contendo:

```json
{
  "sub": "seller_vendedor_1_uuid",
  "tenant_id": "tenant_empresa_abc_uuid",
  "device_id": "device_tablet_rua_01",
  "role": "vendedor",
  "exp": 1793880000
}
```

2. **Armazenamento Seguro:** O token é gravado no dispositivo usando flutter_secure_storage (criptografia por hardware via Keystore/Keychain).
3. **Isolamento de Banco Central (PostgreSQL RLS):** A cada requisição enviada ao backend, a API lê o tenant_id contido no JWT e executa no banco central:

```sql
SET LOCAL app.current_tenant_id = 'tenant_empresa_abc_uuid';
```

Com essa linha, o **Row Level Security (RLS)** do PostgreSQL impede automaticamente qualquer vazamento de dados entre concorrentes.

##### 📷 4. Leitor de Código de Barras (Câmera + Leitor Óptico HID)
O escaneamento suporta a **câmera do celular (Mobile)** e **leitores físicos USB/Bluetooth (Desktop & Mobile)**:

###### A. Escaneamento via Câmera (Mobile)
Utiliza o pacote mobile_scanner:

```dart
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class CameraBarcodeScannerWidget extends StatelessWidget {
  final Function(String ean) onEanScanned;

  const CameraBarcodeScannerWidget({Key? key, required this.onEanScanned}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MobileScanner(
      onDetect: (capture) {
        for (final barcode in capture.barcodes) {
          if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
            onEanScanned(barcode.rawValue!);
            break;
          }
        }
      },
    );
  }
}
```

###### B. Escaneamento via Leitor Físico USB/Bluetooth (Desktop e Mobile - Modo HID)
Captura a digitação de leitores ópticos pareados como teclado:

```dart
import 'package:flutter/services.dart';

class PhysicalBarcodeScannerListener {
  final StringBuffer _buffer = StringBuffer();

  void handleKeyEvent(KeyEvent event, Function(String ean) onScanned) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.enter) {
        final code = _buffer.toString().trim();
        if (code.isNotEmpty) {
          onScanned(code); // Dispara a busca do produto pelo EAN
          _buffer.clear();
        }
      } else if (event.character != null) {
        _buffer.write(event.character);
      }
    }
  }
}
```

🚀 **A infraestrutura da Modelagem Base está pronta! Quer que eu implemente o código completo da Fatia 1 (Tela de Login Multi-Tenant com validação do JWT e download inicial do catálogo local)?**

---

## 19. Sincronização e Login

A criação da pasta no seu ambiente de desenvolvimento (/Users/wagnermunhe/AndroidStudioProjects/venda_completa) está no tempo exato. A estrutura de fatias verticais que adotamos permite construir o projeto arquivo por arquivo diretamente dentro dessa pasta.

Abaixo está o desenvolvimento completo da **Fatia 1 (Autenticação Multi-Tenant & Download Inicial do Catálogo)**.

##### 🔑 Como Funciona o Fluxo da Fatia 1
1. **Credenciais & JWT** : O vendedor informa e-mail/CPF e senha na tela de login. O servidor central autentica as credenciais e devolve um token **JWT** assinado contendo a declaração de tenant_id da empresa e o seller_id do usuário.
2. **Armazenamento Seguro** : O app salva esse JWT no **FlutterSecureStorage** (Keystore no Android / Keychain no iOS) com criptografia em repouso.
3. **Carga Inicial (*Initial Pull*)** : Após salvar a sessão, o app dispara um *download* inicial via API para buscar todos os produtos e tabelas de preço pertencentes estritamente àquele tenant_id.
4. **Persistência no Banco Local (Drift)** : O catálogo baixado é gravado em lote no banco de dados SQLite local (LocalInventory), deixando a vitrine de vendas pronta para consulta instantânea e operação offline.

##### 🛠️ Código Completo da Fatia 1
Todos os arquivos abaixo devem ser inseridos dentro da estrutura da sua pasta venda_completa/lib/.

###### 1. Camada de Segurança: Armazenamento Seguro (lib/core/security/secure_storage_service.dart)
Gerencia o armazenamento criptografado do token JWT e do tenant_id no hardware do aparelho.

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const String _keyJwtToken = 'jwt_token';
  static const String _keyTenantId = 'tenant_id';
  static const String _keySellerId = 'seller_id';

  Future<void> saveSession({
    required String token,
    required String tenantId,
    required String sellerId,
  }) async {
    await _storage.write(key: _keyJwtToken, value: token);
    await _storage.write(key: _keyTenantId, value: tenantId);
    await _storage.write(key: _keySellerId, value: sellerId);
  }

  Future<String?> getToken() async => await _storage.read(key: _keyJwtToken);
  Future<String?> getTenantId() async => await _storage.read(key: _keyTenantId);
  Future<String?> getSellerId() async => await _storage.read(key: _keySellerId);

  Future<void> clearSession() async {
    await _storage.deleteAll();
  }
}
```

###### 2. Cliente HTTP & Serviço de Carga do Catálogo (lib/features/auth/data/catalog_sync_service.dart)
Faz a chamada síncrona à API do backend, autentica com a chave de autorização JWT e grava os produtos diretamente na tabela do Drift.

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';
import '../../../core/security/secure_storage_service.dart';

class CatalogSyncService {
  final http.Client client;
  final AppDatabase db;
  final SecureStorageService storage;
  final String apiBaseUrl;

  CatalogSyncService({
    required this.client,
    required this.db,
    required this.storage,
    required this.apiBaseUrl,
  });

  /// Realiza o download inicial dos produtos da empresa e persiste no SQLite local
  Future<bool> executeInitialCatalogPull() async {
    final token = await storage.getToken();
    final tenantId = await storage.getTenantId();

    if (token == null || tenantId == null) return false;

    final uri = Uri.parse('$apiBaseUrl/sync/catalog');
    final response = await client.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'X-Tenant-ID': tenantId, // Injeta o tenant_id no cabeçalho
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      
      // Converte o payload JSON para objetos de tabela do Drift
      final items = jsonList.map((json) {
        return LocalInventoryCompanion(
          id: Value(json['id']),
          tenantId: Value(tenantId),
          sku: Value(json['sku']),
          codigoEan: Value(json['codigo_ean']),
          descricao: Value(json['descricao']),
          precoVenda: Value((json['preco_venda'] as num).toDouble()),
          qtdDisponivel: Value((json['qtd_disponivel'] as num).toDouble()),
        );
      }).toList();

      // Executa a escrita em lote atômica no banco SQLite local
      await db.batch((batch) {
        batch.insertAllOnConflictUpdate(db.localInventory, items);
      });

      return true;
    }
    return false;
  }
}
```

###### 3. Controladora da Autenticação (lib/features/auth/presentation/auth_controller.dart)
Coordena o fluxo de login, o decodificador das afirmações do JWT (*claims*) e a chamada imediata da carga do catálogo.

```dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/security/secure_storage_service.dart';
import '../data/catalog_sync_service.dart';

enum AuthState { idle, loading, success, error }

class AuthController extends ChangeNotifier {
  final SecureStorageService storage;
  final CatalogSyncService catalogSync;
  final String apiBaseUrl;

  AuthController({
    required this.storage,
    required this.catalogSync,
    required this.apiBaseUrl,
  });

  AuthState _state = AuthState.idle;
  AuthState get state => _state;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  Future<bool> login(String email, String password) async {
    _state = AuthState.loading;
    _errorMessage = '';
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String token = data['access_token'];

        // Extrai tenant_id e seller_id de dentro da estrutura do JWT
        final payloadJson = _parseJwtPayload(token);
        final String tenantId = payloadJson['tenant_id'];
        final String sellerId = payloadJson['sub'];

        // 1. Salva a sessão no SecureStorage
        await storage.saveSession(
          token: token,
          tenantId: tenantId,
          sellerId: sellerId,
        );

        // 2. Dispara a carga inicial do catálogo local no Drift
        final syncSuccess = await catalogSync.executeInitialCatalogPull();

        if (syncSuccess) {
          _state = AuthState.success;
          notifyListeners();
          return true;
        } else {
          _errorMessage = 'Falha ao sincronizar o catálogo local.';
          _state = AuthState.error;
          notifyListeners();
          return false;
        }
      } else {
        _errorMessage = 'Credenciais inválidas ou empresa não encontrada.';
        _state = AuthState.error;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Erro de rede ao conectar com o servidor: $e';
      _state = AuthState.error;
      notifyListeners();
      return false;
    }
  }

  Map<String, dynamic> _parseJwtPayload(String token) {
    final parts = token.split('.');
    if (parts.length != 3) throw Exception('Token JWT inválido.');
    final payload = String.fromCharCodes(
      base64Url.decode(base64Url.normalize(parts[9])),
    );
    return jsonDecode(payload);
  }
}
```

###### 4. Interface Gráfica da Tela de Login (lib/features/auth/presentation/login_screen.dart)
Interface responsiva que atende **dispositivos móveis e computadores desktop**.

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_controller.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();

    return Scaffold(
      backgroundColor: Colors.grey[12],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420), // Tamanho ideal para Desktop e Tablet
            padding: const EdgeInsets.all(32.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.0),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 12.0,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.storefront, size: 64, color: Colors.blueAccent),
                  const SizedBox(height: 16),
                  const Text(
                    'Venda Completa',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Acesse sua conta para sincronizar o catálogo',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'E-mail / Usuário',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Informe seu e-mail' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Senha',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Informe sua senha' : null,
                  ),
                  const SizedBox(height: 24),
                  if (authController.state == AuthState.error) ...[
                    Text(
                      authController.errorMessage,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                  ],
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: authController.state == AuthState.loading
                        ? null
                        : () async {
                            if (_formKey.currentState!.validate()) {
                              final success = await authController.login(
                                _emailController.text.trim(),
                                _passwordController.text.trim(),
                              );
                              if (success && mounted) {
                                Navigator.of(context).pushReplacementNamed('/catalog');
                              }
                            }
                          },
                    child: authController.state == AuthState.loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('ENTRAR E SINCRONIZAR', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

##### 📦 Dependências Necessárias no pubspec.yaml
Adicione as bibliotecas no arquivo pubspec.yaml da raiz do projeto Flutter:

```yaml
dependencies:
  flutter:
    sdk: flutter
  drift: ^2.15.0
  sqflite_common_ffi: ^2.3.0
  path_provider: ^2.1.2
  path: ^1.9.0
  flutter_secure_storage: ^9.0.0
  http: ^1.2.0
  provider: ^6.1.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  drift_dev: ^2.15.0
  build_runner: ^2.4.8
```

Após salvar o pubspec.yaml, execute no terminal para gerar o código do Drift:

```bash
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

📱 **A Fatia 1 está completa! Queremos partir para a Fatia 2 (Catálogo de Produtos, Lista com Busca por Nome/EAN e Leitura por Câmera / Leitor Óptico HID)?**

---

## 20. Estrutura Flutter

**Não é possível me dar acesso direto ao seu computador.** Por motivos de segurança, privacidade e pela própria arquitetura da plataforma, eu opero em um ambiente virtual isolado na nuvem e não tenho permissão para me conectar à sua máquina, acessar seu terminal ou criar arquivos direto no seu disco rígido.

No entanto, montar o projeto no seu computador é um processo bem simples! Basta seguir estes passos:

1. **Criar a estrutura inicial** : Abra o terminal do seu Mac e rode o comando:

```bash
cd /Users/wagnermunhe/AndroidStudioProjects
flutter create venda_completa
```

2. **Abrir o projeto** : Abra a pasta venda_completa no seu editor (VS Code ou Android Studio).
3. **Criar os arquivos** : Dentro da pasta lib/, vá criando as subpastas e arquivos (ex: lib/core/database/app_database.dart) conforme avançamos nas fatias e cole o código que eu estruturar para você.

Quer que a gente já passe para a **Fatia 3** (Carrinho de compras, checkout com baixa atômica no SQLite local e geração da impressão do DANFE NFC-e via Bluetooth)?

---

## 21. Arquitetura Híbrida

**Sim, vale a pena marcar o Linux!** E sobre a **Web**, a resposta ideal é uma **estratégia híbrida**.

Abaixo, detalho o porquê de cada decisão para a arquitetura do seu sistema:

##### 🐧 1. Por que habilitar o Linux?
**Vale muito a pena incluir o Linux!**

* **Redução de Custo em Lojas Físicas:** Muitos varejistas usam mini-PCs ou computadores de balcão rodando distribuições Linux (como Ubuntu ou Mint) para não pagar licenças de Windows.
* **Custo Zero de Adaptação no Flutter:** Como já configuramos o **Drift** com sqflite_common_ffi para Desktop (Windows e macOS), o mesmo código roda no Linux sem precisar alterar absolutamente nada. Basta manter a opção **Linux** marcada no assistente do Flutter.

##### 🌐 2. E se o App rodasse 100% na Web sem instalar?

A Web tem a enorme vantagem de **não precisar de instalação** (basta abrir uma URL). No entanto, para a **operação de vendas e frente de caixa offline-first**, a versão Web pura enfrenta limitações técnicas graves:

| Recurso | App Instalado (Nativo Mobile / Desktop) | Versão Web (Navegador) |
| ------ | ------ | ------ |
| **Funcionamento Offline** | **100% confiável.** O banco SQLite (Drift) grava direto no disco rígido e roda em modo avião. | **Limitado.** Se o sinal cair e a aba for fechada ou recarregada, a aplicação não abre sem internet. |
| **Fila de Outbox (Sync em Segundo Plano)** | **Garantido.** O *Background Worker* continua retransmitindo pedidos mesmo com a tela bloqueada. | **Frágil.** Se o usuário fechar a aba do navegador, a sincronização é interrompida imediatamente. |
| **Impressora Bluetooth (ESC/POS)** | **Acesso nativo total.** Abre conexões seriais (SPP) rápidas com impressoras de cintura. | **Restrito.** A API de Web Bluetooth dos navegadores tem limitações de compatibilidade e segurança. |
| **Certificado A1 & Criptografia Fiscal** | **Seguro.** O token e a chave do certificado ficam no armazenamento seguro do hardware (*Keystore/Keychain*). | **Vulnerável.** O armazenamento de navegadores (*IndexedDB/LocalStorage*) pode ser limpo pelo sistema. |

##### 💡 A Estratégia Híbrida Perfeita para a sua Plataforma

Como o Flutter gera instaladores nativos e versão Web a partir do **mesmo código**, a melhor divisão operacional é:

1. **App Instalado (Android, iOS, Windows, macOS e Linux):**
    * **Para quem:** Vendedores externos na rua e operadores de caixa no balcão.
    * **Por quê:** Garante vendas offline sem travamento, bipagem rápida por leitor óptico, assinatura de notas fiscais e impressão Bluetooth/USB nativa.
2. **Versão Web (Navegador):**
    * **Para quem:** Donos da empresa, gerentes e administradores.
    * **Por quê:** Permite acessar relatórios de vendas, gerenciar cotas de estoque e cadastrar produtos de qualquer lugar pelo navegador do computador ou tablet, sem precisar instalar nada.

No Android Studio, você pode marcar todas as caixas: **Android, iOS, Windows, macOS, Linux e Web**.

Podemos voltar para o Android Studio e avançar na criação das pastas da **Modelagem Base**?

---

## 22. Arquitetura Flutter Híbrida

**Sim, vale a pena marcar o Linux!** E sobre a **Web**, a resposta ideal é uma **estratégia híbrida**.

Abaixo, detalho o porquê de cada decisão para a arquitetura do seu sistema:

##### 🐧 1. Por que habilitar o Linux?
**Vale muito a pena incluir o Linux!**

* **Redução de Custo em Lojas Físicas:** Muitos varejistas usam mini-PCs ou computadores de balcão rodando distribuições Linux (como Ubuntu ou Mint) para não pagar licenças de Windows.
* **Custo Zero de Adaptação no Flutter:** Como já configuramos o **Drift** com sqflite_common_ffi para Desktop (Windows e macOS), o mesmo código roda no Linux sem precisar alterar absolutamente nada. Basta manter a opção **Linux** marcada no assistente do Flutter.

##### 🌐 2. E se o App rodasse 100% na Web sem instalar?

A Web tem a enorme vantagem de **não precisar de instalação** (basta abrir uma URL). No entanto, para a **operação de vendas e frente de caixa offline-first**, a versão Web pura enfrenta limitações técnicas graves:

| Recurso | App Instalado (Nativo Mobile / Desktop) | Versão Web (Navegador) |
| ------ | ------ | ------ |
| **Funcionamento Offline** | **100% confiável.** O banco SQLite (Drift) grava direto no disco rígido e roda em modo avião. | **Limitado.** Se o sinal cair e a aba for fechada ou recarregada, a aplicação não abre sem internet. |
| **Fila de Outbox (Sync em Segundo Plano)** | **Garantido.** O *Background Worker* continua retransmitindo pedidos mesmo com a tela bloqueada. | **Frágil.** Se o usuário fechar a aba do navegador, a sincronização é interrompida imediatamente. |
| **Impressora Bluetooth (ESC/POS)** | **Acesso nativo total.** Abre conexões seriais (SPP) rápidas com impressoras de cintura. | **Restrito.** A API de Web Bluetooth dos navegadores tem limitações de compatibilidade e segurança. |
| **Certificado A1 & Criptografia Fiscal** | **Seguro.** O token e a chave do certificado ficam no armazenamento seguro do hardware (*Keystore/Keychain*). | **Vulnerável.** O armazenamento de navegadores (*IndexedDB/LocalStorage*) pode ser limpo pelo sistema. |

##### 💡 A Estratégia Híbrida Perfeita para a sua Plataforma

Como o Flutter gera instaladores nativos e versão Web a partir do **mesmo código**, a melhor divisão operacional é:

1. **App Instalado (Android, iOS, Windows, macOS e Linux):**
    * **Para quem:** Vendedores externos na rua e operadores de caixa no balcão.
    * **Por quê:** Garante vendas offline sem travamento, bipagem rápida por leitor óptico, assinatura de notas fiscais e impressão Bluetooth/USB nativa.
2. **Versão Web (Navegador):**
    * **Para quem:** Donos da empresa, gerentes e administradores.
    * **Por quê:** Permite acessar relatórios de vendas, gerenciar cotas de estoque e cadastrar produtos de qualquer lugar pelo navegador do computador ou tablet, sem precisar instalar nada.

No Android Studio, você pode marcar todas as caixas: **Android, iOS, Windows, macOS, Linux e Web**.

Podemos voltar para o Android Studio e avançar na criação das pastas da **Modelagem Base**?

---

## 23. Arquitetura Flutter Clean

**Não se preocupe, a estrutura continua exatamente a mesma!** Apenas encaixamos a pasta widgets dentro de core/ para guardar os componentes genéricos que serão usados por mais de uma tela.

No modelo de **Clean Architecture com Feature Slices**, a pasta lib/core/ serve justamente para abrigar tudo o que é **compartilhado** entre as telas (banco de dados, rede, segurança e componentes visuais genéricos).

A estrutura completa e combinada fica assim:
```text
lib/
├── core/
│   ├── database/
│   │   ├── app_database.dart         # Conexão central do Drift (Mobile + Desktop FFI)
│   │   └── connection/
│   │       ├── native.dart           # Conexão nativa (Android/iOS/Desktop)
│   │       └── web.dart              # Suporte para Web
│   ├── network/
│   │   ├── api_client.dart            # Interceptor HTTP (JWT + X-Idempotency-Key)
│   │   └── websocket_handler.dart     # Conexão real-time via WebSocket com tenant_id
│   ├── security/
│   │   └── secure_storage_service.dart# FlutterSecureStorage (JWT Token + Certificado A1)
│   └── widgets/                       # 👈 Componentes compartilhados de Hardware/UI
│       ├── camera_barcode_scanner_widget.dart
│       └── physical_barcode_scanner_listener.dart
├── features/
│   ├── auth/                          # Fatia 1: Autenticação Multi-Tenant
│   │   ├── data/
│   │   │   └── catalog_sync_service.dart
│   │   └── presentation/
│   │       ├── auth_controller.dart
│   │       └── login_screen.dart
│   ├── catalog/                       # Fatia 2: Produtos e Escaneamento EAN
│   │   ├── data/
│   │   │   └── catalog_repository.dart
│   │   └── presentation/
│   │       ├── catalog_controller.dart
│   │       └── catalog_screen.dart
│   └── sales/                         # Fatias 3 e 4: Checkout, Outbox e DANFE
│       ├── data/
│       └── presentation/
└── main.dart
```

Dessa forma, os leitores de código de barras em core/widgets/ ficam disponíveis para serem chamados tanto na **Fatia 2 (Catálogo)** quanto na **Fatia 3 (Carrinho / Checkout)** sem precisar duplicar código!

💡 **Quer que eu liste agora os arquivos da Fatia 1 (Login e Carga do Catálogo) com seus respectivos caminhos dentro dessa árvore?**

---

## 24. Contrato de Dados

**Você está totalmente coberto de razão.**

O erro que desencadeou tudo aconteceu alguns passos antes: **eu criei inicialmente uma tabela simplificada no banco (qtdDisponivel) e, logo em seguida, escrevi arquivos de sincronização e telas assumindo que o banco já tinha campos mais avançados (ncm, cest, qtdFisica, qtdReservada, cotaOffline).**

Ao tentar "consertar" o banco no meio do caminho para adaptar ao código que escrevi, o esquema mudou e quebrou o projeto inteiro em cascata. Esse desalinhamento de contrato foi uma falha de sequenciamento minha.

##### 🛡️ O que vamos fazer para evitar que esse erro anterior se repita:

1. **Definição Prévia do Contrato de Dados (Data First)** Antes de escrevermos qualquer Controller ou Tela de uma nova funcionalidade, congelamos primeiro o modelo do banco de dados (as tabelas do Drift). Não haverá adição de campos "surpresa" no meio do código da regra de negócio.
2. **Verificação de Dependências Cruzadas** Antes de te entregar um arquivo para copiar e colar, garanto que todas as variáveis, métodos e propriedades usados nele **já existem** e estão declarados nos arquivos das camadas inferiores (Repositório e Banco).
3. **Mudanças de Esquema em Passos Isolados** Se em algum momento futuro for estritamente necessário alterar uma tabela do SQLite, isso será tratado como uma etapa única e isolada:
    * Atualizamos a tabela ➡️ Rodamos o build_runner ➡️ Validamos o banco ➡️ SÓ ENTÃO tocamos no código das telas.

Essa transparência e esse controle de etapas trazem a segurança que você precisa para continuarmos?

---

## 25. Correção do Carrinho

Não há desculpa. **A responsabilidade é totalmente minha** por ter violado a estratégia de entregas e ter te enviado quatro arquivos de uma vez só.

Vou te explicar **exatamente o motivo técnico desse colapso de erros** e como vamos corrigir isso de forma definitiva agora mesmo:

##### 🔍 O que causou esses erros em cascata?
Todos os 7 erros que você recebeu foram provocados por **uma única falha principal**:

1. A classe CartItem é a base de todo o módulo de carrinho.
2. Ao enviar os 4 arquivos juntos usando caminhos relativos (../domain/cart_item.dart), o Dart não encontrou a classe CartItem ao compilar o CartRepository e o CartController.
3. **Efeito dominó:** Como o Dart não reconheceu o tipo CartItem, ele perdeu a referência dos tipos da lista (List<CartItem>). Sem saber o tipo, ele assumiu que propriedades como .total, .quantity e .toJson() não existiam ou podiam ser nulas, gerando todos os outros erros de tipo (double vs int, receiver can be null, etc.).

##### 🛡️ O ajuste definitivo a partir de agora:
1. **Entregaremos estritamente UM arquivo por vez.**
2. **Usaremos imports absolutos do pacote (package:venda_completa/...)** em vez de caminhos relativos (../). Isso impede que o Dart se perca nas pastas.
3. Você salva o arquivo, confirma que ficou sem erro, e só então passamos para o próximo.

##### 📍 PASSO 1: Criar a classe base do Carrinho (cart_item.dart)

Crie a pasta domain dentro de lib/features/cart/ (ficando lib/features/cart/domain/) e cole este arquivo **100% completo**:

📍 **Caminho exato:** lib/features/cart/domain/cart_item.dart

```dart
import 'package:venda_completa/core/database/app_database.dart';

class CartItem {
  final LocalInventoryData product;
  int quantity;

  CartItem({
    required this.product,
    this.quantity = 1,
  });

  double get total => product.precoVenda * quantity;

  CartItem copyWith({
    LocalInventoryData? product,
    int? quantity,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': product.id,
      'sku': product.sku,
      'codigo_ean': product.codigoEan,
      'descricao': product.descricao,
      'ncm': product.ncm,
      'unidade_medida': product.unidadeMedida,
      'preco_unitario': product.precoVenda,
      'quantidade': quantity,
      'total': total,
    };
  }
}
```

##### 💻 Ação:
1. Crie o arquivo em lib/features/cart/domain/cart_item.dart e salve.
2. Me avise se esse arquivo ficou **sem nenhum erro no Android Studio**. Assim que me confirmar, te envio o repositório (CartRepository).

---

## 26. Arquitetura Bottom-Up

Sua observação é **perfeita e cirúrgica**. O motivo exato de os erros acontecerem foi a geração de código **de cima para baixo (Top-Down)**: criar primeiro as Telas e Controllers que usavam componentes, widgets ou modelos que ainda não tinham sido fisicamente criados no seu projeto (como CartItem, CameraBarcodeScannerWidget ou PhysicalBarcodeScannerListener).

Quando uma Tela depende de um Widget ou classe que não existe, o Dart não consegue resolver as referências e dispara dezenas de erros de compilação em cascata.

##### 🛡️ Como vamos corrigir isso de forma definitiva?
Para eliminar o risco de "widgets e classes fantasmas", adotaremos um **Protocolo Rigoroso de Construção de Baixo para Cima (Bottom-Up)**:

###### 1. Ordem Inversa e Rígida de Dependência
Nunca mais entregaremos uma Tela antes de suas fundações. A ordem de criação de qualquer funcionalidade será **sempre**:

1. **Modelos de Domínio** (ex: CartItem)
2. **Widgets Auxiliares & Utilitários** (qualquer componente visual reutilizável que a tela vá usar)
3. **Repositório de Dados** (ex: CartRepository)
4. **Controller / Gerenciador de Estado** (ex: CartController)
5. **Tela final (UI)** (ex: CartScreen) — *só é enviada quando 100% das suas dependências já estiverem salvas e sem erros no seu projeto.*

###### 2. Eliminação de Widgets "Fantasmas"
Se a tela precisar de algum elemento específico (como scanner de câmera ou leitor físico), o código desse widget auxiliar será entregue e validado **antes** da tela ser escrita, ou usaremos exclusivamente os widgets nativos do próprio SDK do Flutter.

###### 3. Validação Atômica (Arquivo por Arquivo)
Continuamos no nosso pacto de entregar **estritamente 1 arquivo completo por mensagem**. Você cola, salva e valida no Android Studio. Assim que confirmar que o arquivo está "limpo", passamos para o nível seguinte da cadeia.

##### 🟢 Situação Atual do Projeto
Neste momento, ajustamos os arquivos de base do Carrinho:

* lib/features/cart/domain/cart_item.dart
* lib/features/cart/data/cart_repository.dart

Seu Android Studio está **100% sem erros** no CartRepository agora? Assim que me me der o ok, seguimos a ordem e te envio o **CartController**!

---

# Continuação — Estado de Implementação (atualizado em 07/11/2026)

Esta seção registra o que foi **efetivamente construído e decidido** depois das 26 notas acima. As notas 1–26 são o registro histórico do planejamento; o código real no disco evoluiu e, em alguns pontos, diverge das notas (ex.: o `AuthController` real).

## 🏗️ Arquitetura consolidada

- **Vendedor → app instalado (Flutter nativo)**; **Admin → painel web (navegador)**. Estratégia híbrida mantida. A operação de venda de rua NÃO é web (offline, impressora Bluetooth, fiscal offline); a administração é web.
- **Multi-tenant de banco único**: um só PostgreSQL, isolamento lógico por `tenant_id` (modelo escolhido por custo). Cada cliente (empresa) gerencia os próprios dados pelo painel; o `tenant_id` vem dentro do JWT e filtra tudo no servidor.
- **Papéis**: `admin` (painel web, gerencia produtos/vendedores da empresa) e `vendedor` (app, vende). Coluna `sellers.role`.

## ✅ Status das 4 fatias

- **Fatia 1 (Auth & Sync):** ✅ Login real contra o backend. O vendedor informa **só e-mail + senha** — NUNCA a empresa; o servidor resolve o tenant pelo cadastro do usuário e devolve no JWT. Fallback de modo demo offline quando não há servidor.
- **Fatia 2 (Catálogo & Bipagem):** ✅ Catálogo vindo do PostgreSQL, busca, leitura por câmera/HID, seletor de quantidade no toque do produto (diálogo, sem trocar de tela), carrinho com badge. Catálogo **reativo** (atualiza na hora).
- **Fatia 3 (Checkout & Impressão):** 🟢 Base comum FEITA. Emissão NFC-e em **contingência (tpEmis=9)** no app: `FiscalKeyGenerator` (chave 44 díg + DV mód.11), `FiscalService` (aloca série/número local, monta a nota), `DanfeEscPosBuilder` (bytes ESC/POS + QR). A nota vai no payload da venda e é gravada em `fiscal_invoices` (status OFFLINE) no servidor. Impressão via `PrinterService` (hoje `LoggingPrinterService` stub). **A pré-visualização do DANFE é um PORTÃO DE CONFIRMAÇÃO ANTES de efetivar a venda** (`DanfeTextBuilder` → `FiscalResult.previewText`): fluxo em 2 fases — `prepareSale` (monta a prévia espiando o número via `peekNfceNumero`, SEM baixar estoque nem consumir número) e `confirmSale` (consome `commitNfceNumero`, baixa estoque, Outbox, imprime). "Cancelar" na prévia aborta sem efeito (estoque/numeração intactos). Terminologia das telas (ambas exibem o MESMO DANFE): passo 3 (antes de efetivar, portão) = **"Confira o DANFE antes de emitir"**; passo 4 (após efetivar, visualização) = **"DANFE — pré-nota (não transmitida)"**. Independe de impressora. Impressão via botão **Imprimir** (sempre visível): `LoggingPrinterService` agora é uma **impressora SIMULADA** (`isAvailable=true`, `printBytes` conclui com sucesso e registra os bytes ESC/POS) — o botão é funcional no fluxo; trocar pelo pacote Bluetooth real num aparelho. Quando a nota é AUTORIZADA, o corpo do DANFE é regerado sem o aviso de contingência e com **"NFC-e AUTORIZADA pela SEFAZ / Protocolo: X"** (DanfeTextBuilder c/ `protocolo`; `CartController.danfePreview`). FALTA: **cancelamento/estorno de venda JÁ efetivada** + **impressão Bluetooth real**.

###### Retorno de transmissão no app
- Após confirmar, o app **transmite e consulta o status** (`GET /fiscal/status/<orderId>`, acessível ao vendedor; `CartRepository.processCheckout` retorna o orderId; `OutboxService.fetchFiscalStatus`). A tela pós-venda mostra faixa colorida + título dinâmico: **AUTORIZADA · protocolo X** (verde), **Pendente — envia ao reconectar** (laranja, offline) ou **REJEITADA**. `CartController.transmissionStatus` / `lastSaleAuthorized`.

###### Impressão do DANFE
- **Dois modos** no diálogo "Imprimir DANFE": (1) **Impressora do sistema (PDF)** — `DanfePdfBuilder` gera PDF (80mm, itens/total/chave/QR) e `Printing.layoutPdf` manda ao driver do SO; funciona em **laser/comum** (ex.: HP LaserJet CP1025nw, testado OK). (2) **Térmica de rede (ESC/POS)** — `ThermalPrinterService` envia por socket TCP porta 9100; **descoberta automática** (`PrinterDiscoveryService` varre a sub-rede /24 na 9100) + IP manual de reserva. ESC/POS só funciona em térmica de cupom, não em laser.

###### Transmissão à SEFAZ (simulada) + Painel de Notas
- **SefazService** (`server/lib/sefaz_service.dart`): interface `transmitir()` + `FakeSefazService` (MOCK: autoriza sempre, protocolo simulado; NÃO assina A1 nem fala com SEFAZ real). Injetado em `server.dart` como `final SefazService _sefaz = FakeSefazService();` — **trocar por `RealSefazService` é a ÚNICA linha a mudar** para produção.
- Fluxo fiel ao real: a nota nasce **OFFLINE** na transação; após o commit, o servidor chama `_sefaz.transmitir()` (fora da tx) e atualiza para **AUTORIZADO** + protocolo (ou REJEITADO/motivo). Se a transmissão falhar, fica OFFLINE para nova conciliação.
- **Painel admin → aba "Notas fiscais"** (`GET /admin/invoices`): lista as notas com Nº, Status (AUTORIZADO/OFFLINE), Protocolo, Valor, Chave e botão **"Ver XML"**.
- **Geração do XML da NFC-e** (`server/lib/nfce_xml_builder.dart`): monta o XML layout 4.00 (ide, emit c/ CNPJ/IE/UF reais, det c/ produtos/NCM/CFOP, imposto ICMSSN102/Simples, total, transp, pag). No `/sync/vendas` o XML é gerado e salvo em `fiscal_invoices.xml_assinado`; consultável via `GET /admin/invoices/<chave>/xml`. **NÃO assinado com A1** (sem `<Signature>`), endereço/cMun como placeholder — vira XML válido só com A1 + SEFAZ reais (RealSefazService).

###### Conceitos fiscais (esclarecidos nesta conversa)
- **Nota fiscal** = o XML autorizado pela SEFAZ (documento legal). **DANFE (nota auxiliar)** = representação visual/impressa que aponta para a nota (sem valor fiscal próprio). **Pré-nota** = termo informal p/ documento ainda não autorizado. O que o app emite hoje é, juridicamente, uma **pré-nota** (contingência não transmitida de verdade), virando "nota" só com assinatura A1 + autorização SEFAZ reais.
- **Correção de erro:** antes de confirmar → "Cancelar" na prévia (sem efeito). Depois de confirmada → precisa de **cancelamento** (dentro do prazo) ou **devolução/nota complementar** — fluxo a construir, junto da SEFAZ real. NFC-e geralmente NÃO aceita CC-e.
- **Fatia 4 (Outbox & Tempo Real):** ✅ Replay da Outbox **automático** (no início + na reconexão via connectivity_plus + timer 20s). WebSocket: servidor faz broadcast `inventory.updated` por tenant ao concluir venda; app atualiza o estoque local em tempo real. Testado entre dois vendedores da mesma empresa.

## 🖥️ Backend (novo — não existia nas notas)

- **Dart + Shelf** em `server/` (escolha: Shelf, não Serverpod). PostgreSQL via **Postgres.app v16** (não Homebrew — macOS 14 Intel não tem bottles).
- **Banco:** `venda_completa`. Schema + seed em `server/sql/` (`01_schema.sql`, `02_seed.sql`, `03_admin.sql`), idempotentes.
- **Endpoints:**
  - `POST /auth/login` — resolve empresa pelo cadastro, devolve JWT (com `role` e `tenant_id`).
  - `GET /sync/catalog` — produtos+estoque do tenant.
  - `POST /sync/vendas` — grava pedido (idempotente por `client_order_id`), baixa estoque, dispara broadcast WS.
  - `GET /ws?token=` — WebSocket, broadcast de estoque filtrado por tenant.
  - `GET /admin` — página HTML do painel.
  - `GET/POST /admin/products`, `PUT /admin/products/<id>`, `GET/POST /admin/sellers` — CRUD (exige role=admin).
  - `POST /admin/products/import` — **importação de catálogo por CSV** (upsert em lote por SKU; parser próprio que aceita separador `;`/`,` e decimal vírgula; devolve relatório criados/atualizados/erros, pulando linhas inválidas). Painel tem "Baixar modelo" + upload.

## 🔑 Credenciais demo (senha de todos: `123456`)

- Admins: `admin@autopecas.com`, `admin@oficinaboa.com`, `admin@demo.com`.
- Vendedores: `joao@autopecas.com`, `maria@gmail.com` (mesma empresa — Auto Peças), `ana@oficinaboa.com`, `demo@demo.com`.

## ▶️ Como rodar (dev local)

1. Abrir o **Postgres.app** (v16) — ligado sob demanda.
2. Servidor: `cd server && dart run bin/server.dart` (PATH do psql: `/Applications/Postgres.app/Contents/Versions/16/bin`). Sobe em `http://localhost:3000`.
3. App: `flutter run -d macos` (ou `fvm flutter run`). `kApiBaseUrl = http://localhost:3000` (macOS/web; emulador Android usaria `10.0.2.2`).
4. Painel: abrir `http://localhost:3000/admin` no navegador.

## ⚠️ Gotchas resolvidos (macOS/Drift)

- **CocoaPods "not installed" no 1º Run pela IDE:** o `pod install` do 1º build não achava o `pod`. Rodar pelo terminal resolve; definitivo = `sudo launchctl config user path` + reboot.
- **Keychain -34018 (flutter_secure_storage):** usar `MacOsOptions(useDataProtectionKeyChain: false)` (keychain tradicional, sem exigir entitlement/certificado). Debug entitlements SEM sandbox.
- **Drift "Table has no primary key":** o getter certo é `primaryKey` (singular), não `primaryKeys`. Sempre rodar `dart run build_runner build` após mexer em tabela. Migração `schemaVersion` 1→2 recria tabelas antigas.

## 📋 Pendências (backlog priorizado)

1. ~~Importação de catálogo por planilha CSV~~ ✅ FEITO (endpoint + painel; upsert por SKU; aceita `;`/`,` e decimal vírgula).
2. **Fatia 3 fiscal:** emissão NFC-e tpEmis=9 + builder ESC/POS DANFE + impressão Bluetooth.
3. **Hospedagem + distribuição:** servidor em nuvem com HTTPS/domínio; builds de produção + publicação (Play Store/App Store) ou MDM.
4. **Config. fiscal no painel:** CNPJ, IE, certificado A1, séries fiscais.
5. **Segurança produção:** hash de senha real (bcrypt — hoje é esquema demo `demo$<senha>`); ativar **RLS** no PostgreSQL.
6. **Remover a ÁREA DE TESTE** do login (seletor empresa×funcionário em `test_login_picker.dart` + bloco em `login_screen.dart`) antes de produção.
7. Transversais: captura de cliente na venda; provisionamento de empresa em 1 clique; indicador de pendências do Outbox na UI.

## 🔄 Processo completo — do contrato à operação

Situação: ✅ pronto · 🔨 a construir.

| # | Etapa (o que faz) | Quem faz | Onde faz | Como faz | Quando faz | Situação |
|---|---|---|---|---|---|---|
| **FASE 1 — Contrato e provisionamento** |||||||
| 1 | Fecha o contrato | Você / comercial | Reunião ou online | Negociação + assinatura | Início | ✅ (negócio) |
| 2 | Cria a empresa (tenant) + 1º admin | Você (plataforma) | Servidor/banco | Script SQL (`03_admin`) ou endpoint | Após o contrato | ✅ manual · 🔨 1-clique |
| 3 | Entrega credenciais do admin | Você | E-mail/canal seguro | Envia e-mail + senha inicial | Após provisionar | 🔨 manual |
| **FASE 2 — Configuração pelo cliente** |||||||
| 4 | Acessa o painel | Admin do cliente | Navegador (`/admin`) | Login e-mail/senha | 1º acesso | ✅ |
| 5 | Configura dados fiscais (CNPJ, IE, Certificado A1, séries) | Admin (ou você) | Painel | Formulário + upload do A1 | Antes de emitir nota | 🔨 |
| 6 | Importa o catálogo | Admin | Painel (Produtos) | Upload CSV (modelo/export Bling) | Config. inicial | ✅ |
| 7 | Cadastra os vendedores | Admin | Painel (Vendedores) | Formulário | Config. inicial | ✅ |
| 8 | Aloca série fiscal / Nosso Número por vendedor | Sistema / Admin | Servidor | Automático ao criar vendedor | Ao cadastrar | 🔨 (hoje fixo) |
| **FASE 3 — Distribuição do app** |||||||
| 9 | Gera builds do app (assinados) | Você / dev | Máquina de build/CI | `flutter build` + assinatura | Antes do go-live | 🔨 |
| 10 | Publica/distribui o app | Você / TI do cliente | Play/App Store, MDM, APK | Publicação ou push MDM | Antes do go-live | 🔨 |
| 11 | Instala no aparelho do vendedor | Vendedor ou TI | Celular/tablet | Baixa da loja / MDM | Antes de operar | 🔨 |
| **FASE 4 — Operação diária (campo)** |||||||
| 12 | Login + carga inicial do catálogo | Vendedor | App | e-mail/senha → baixa p/ SQLite | 1º uso e logins | ✅ |
| 13 | Monta a venda (bipagem + quantidade) | Vendedor | App | Câmera/HID + seletor de quantidade | Durante a venda | ✅ |
| 14 | Emite nota fiscal + cobrança | App / Vendedor | App | NFC-e (online/contingência) + Pix/boleto | No fechamento | 🔨 (Fatia 3) |
| 15 | Imprime DANFE/comprovante | App / Vendedor | Impressora Bluetooth | Comandos ESC/POS | Na venda | 🔨 (stub) |
| 16 | Baixa estoque local + grava Outbox | App | Dispositivo (SQLite) | Transação local atômica | Na venda | ✅ |
| 17 | Sincroniza com o servidor | App (worker) | Dispositivo → servidor | Replay Outbox (início+reconexão+timer) | Com internet | ✅ |
| 18 | Atualiza estoque em tempo real nos outros | Servidor → apps | WebSocket | Broadcast por tenant | A cada venda sync | ✅ |
| 19 | Concilia nota com SEFAZ (contingência 24h) | Servidor / API fiscal | Backend | Retransmite/cancela/inutiliza | Após reconexão / fim do dia | 🔨 |
| 20 | Fecha o caixa | Vendedor / Admin | App / Painel | Reconciliação dados+fiscal+financeira | Fim do expediente | 🔨 parcial |
| **FASE 5 — Gestão contínua** |||||||
| 21 | Atualiza catálogo/preços/estoque | Admin | Painel | Editar ou reimportar CSV | Quando precisar | ✅ |
| 22 | Gerencia vendedores (novo/editar/inativar) | Admin | Painel | Formulário | Quando precisar | ✅ criar · 🔨 editar/inativar |
| 23 | Consulta relatórios de vendas | Admin | Painel | Telas de relatório | Rotineiro | 🔨 |
| 24 | Mantém a infraestrutura (backup, uptime, updates, segurança) | Você | Servidor/nuvem | Rotinas de ops | Contínuo | 🔨 |

**Por responsável:** Você → provisiona (2,3), publica o app (9,10), mantém infra (24). Admin → configura/abastece (4–8) e gere (21–23). Vendedor → opera a venda (12–16); sync e tempo real (17,18) são automáticos.

**Bloqueios para rodar 100% end-to-end:** (a) Fatia 3 fiscal (14,15,19); (b) hospedagem + distribuição (9,10,11,24); (c) config fiscal no painel (5,8) e relatórios (23).
