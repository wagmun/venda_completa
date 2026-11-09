/// Dados fictícios de catálogo por empresa (tenant), usados no modo
/// demonstração enquanto o backend não existe. Cada empresa tem um catálogo
/// distinto para evidenciar o isolamento multi-tenant.
library;

/// Produto fictício de demonstração (antes de virar linha no SQLite).
class DemoProduct {
  final String sku;
  final String ean; // 13 dígitos
  final String descricao;
  final String ncm; // 8 dígitos
  final double preco;
  final double estoque;

  const DemoProduct(
    this.sku,
    this.ean,
    this.descricao,
    this.ncm,
    this.preco,
    this.estoque,
  );
}

/// Catálogo por empresa. A chave é o tenant_id resolvido no login.
const Map<String, List<DemoProduct>> kDemoCatalogByTenant = {
  // ---------------------------------------------------------------------------
  // Empresa 1: Auto peças
  // ---------------------------------------------------------------------------
  'empresa_autopecas': [
    DemoProduct('AP-001', '7891000200101', 'Óleo de Motor 5W30 Sintético 1L', '27101932', 54.90, 40),
    DemoProduct('AP-002', '7891000200118', 'Óleo de Motor 15W40 Semissint. 1L', '27101932', 38.50, 55),
    DemoProduct('AP-003', '7891000200125', 'Filtro de Óleo Automotivo', '84212300', 29.90, 25),
    DemoProduct('AP-004', '7891000200132', 'Filtro de Ar Esportivo', '84213100', 89.90, 12),
    DemoProduct('AP-005', '7891000200149', 'Fluido de Freio DOT4 500ml', '38190000', 19.50, 60),
    DemoProduct('AP-006', '7891000200156', 'Aditivo Radiador Concentrado 1L', '38200000', 24.00, 35),
    DemoProduct('AP-007', '7891000200163', 'Palheta Limpador Para-brisa 20"', '85122021', 39.90, 18),
    DemoProduct('AP-008', '7891000200170', 'Lâmpada Farol H4 12V 60/55W', '85392990', 15.75, 80),
    DemoProduct('AP-009', '7891000200187', 'Pastilha de Freio Dianteira (par)', '87083090', 119.90, 22),
    DemoProduct('AP-010', '7891000200194', 'Vela de Ignição Iridium', '85111000', 44.90, 48),
    DemoProduct('AP-011', '7891000200200', 'Correia Dentada Reforçada', '40103500', 78.00, 15),
    DemoProduct('AP-012', '7891000200217', 'Bateria 60Ah Selada', '85071000', 389.90, 8),
    DemoProduct('AP-013', '7891000200224', 'Amortecedor Dianteiro', '87088000', 229.90, 10),
    DemoProduct('AP-014', '7891000200231', 'Disco de Freio Ventilado', '87083090', 159.90, 14),
  ],

  // ---------------------------------------------------------------------------
  // Empresa 2: Oficina / ferramentas e consumíveis
  // ---------------------------------------------------------------------------
  'empresa_oficina_boa': [
    DemoProduct('OF-001', '7892000300101', 'Chave de Fenda Phillips 1/4"', '82054000', 12.90, 70),
    DemoProduct('OF-002', '7892000300118', 'Jogo de Soquetes 1/2" 10 peças', '82041100', 149.90, 16),
    DemoProduct('OF-003', '7892000300125', 'Alicate Universal 8"', '82032000', 34.90, 40),
    DemoProduct('OF-004', '7892000300132', 'Martelo Unha 25mm Cabo Fibra', '82055900', 42.00, 28),
    DemoProduct('OF-005', '7892000300149', 'Graxa de Lítio 500g', '34031900', 21.90, 50),
    DemoProduct('OF-006', '7892000300156', 'Desengripante Spray 300ml', '27101259', 17.50, 65),
    DemoProduct('OF-007', '7892000300163', 'Estopa Branca Pacote 1kg', '63109000', 14.90, 45),
    DemoProduct('OF-008', '7892000300170', 'Luva de Raspa Reforçada (par)', '42032910', 11.90, 90),
    DemoProduct('OF-009', '7892000300187', 'Disco de Corte 7" Inox', '68042290', 8.90, 120),
    DemoProduct('OF-010', '7892000300194', 'Trena 5m Emborrachada', '90178010', 24.90, 33),
    DemoProduct('OF-011', '7892000300200', 'Parafusadeira Furadeira 12V', '84672100', 299.90, 9),
    DemoProduct('OF-012', '7892000300217', 'Óculos de Proteção Incolor', '90049000', 9.90, 110),
    DemoProduct('OF-013', '7892000300224', 'Fita Isolante 19mm x 20m', '39191010', 6.50, 150),
  ],

  // ---------------------------------------------------------------------------
  // Empresa 3: Loja geral / conveniência (tenant padrão de demonstração)
  // ---------------------------------------------------------------------------
  'empresa_demo': [
    DemoProduct('DM-001', '7893000400101', 'Água Mineral sem Gás 500ml', '22011000', 2.50, 200),
    DemoProduct('DM-002', '7893000400118', 'Refrigerante Cola Lata 350ml', '22021000', 4.50, 180),
    DemoProduct('DM-003', '7893000400125', 'Café Torrado e Moído 500g', '09012100', 18.90, 60),
    DemoProduct('DM-004', '7893000400132', 'Biscoito Recheado Chocolate', '19053100', 3.90, 150),
    DemoProduct('DM-005', '7893000400149', 'Arroz Branco Tipo 1 5kg', '10063021', 27.90, 40),
    DemoProduct('DM-006', '7893000400156', 'Feijão Carioca 1kg', '07133319', 8.90, 75),
    DemoProduct('DM-007', '7893000400163', 'Óleo de Soja 900ml', '15079011', 7.50, 90),
    DemoProduct('DM-008', '7893000400170', 'Sabão em Pó 1kg', '34022000', 12.90, 55),
    DemoProduct('DM-009', '7893000400187', 'Detergente Neutro 500ml', '34022000', 2.90, 130),
    DemoProduct('DM-010', '7893000400194', 'Papel Higiênico 12 rolos', '48180910', 21.90, 48),
    DemoProduct('DM-011', '7893000400200', 'Leite UHT Integral 1L', '04012010', 5.20, 160),
    DemoProduct('DM-012', '7893000400217', 'Açúcar Refinado 1kg', '17019900', 4.80, 95),
  ],
};

/// Catálogo padrão para tenants sem mapeamento específico.
const List<DemoProduct> kDemoDefaultCatalog = [
  DemoProduct('GEN-001', '7899000500101', 'Produto de Exemplo A', '00000000', 10.00, 50),
  DemoProduct('GEN-002', '7899000500118', 'Produto de Exemplo B', '00000000', 20.00, 50),
  DemoProduct('GEN-003', '7899000500125', 'Produto de Exemplo C', '00000000', 30.00, 50),
];

/// Retorna o catálogo demo de um tenant (ou o catálogo padrão).
List<DemoProduct> demoCatalogFor(String tenantId) {
  return kDemoCatalogByTenant[tenantId] ?? kDemoDefaultCatalog;
}
