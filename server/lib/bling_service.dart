import 'dart:convert';
import 'dart:io';

/// Tokens OAuth do Bling.
class BlingTokens {
  final String accessToken;
  final String refreshToken;
  final int expiresIn; // segundos
  BlingTokens(this.accessToken, this.refreshToken, this.expiresIn);
}

/// Integração com a API do Bling (v3). OAuth2 + puxar produtos/estoque +
/// empurrar venda. client_id/secret/redirect vêm de variáveis de ambiente.
///
/// NOTA: os nomes de campos do JSON do Bling (produtos/estoque/pedido) devem
/// ser validados contra uma conta real; o parsing aqui é defensivo.
class BlingService {
  static const _authBase = 'https://www.bling.com.br/Api/v3';
  static const _apiBase = 'https://api.bling.com.br/Api/v3';

  String get clientId => Platform.environment['BLING_CLIENT_ID'] ?? '';
  String get clientSecret => Platform.environment['BLING_CLIENT_SECRET'] ?? '';
  String get redirectUri => Platform.environment['BLING_REDIRECT_URI'] ?? '';

  bool get configurado => clientId.isNotEmpty && clientSecret.isNotEmpty;

  /// URL para o admin autorizar o acesso ao Bling dele (state = tenant_id).
  String authorizeUrl(String state) =>
      '$_authBase/oauth/authorize?response_type=code&client_id=$clientId'
      '&state=$state&redirect_uri=${Uri.encodeComponent(redirectUri)}';

  /// Troca o code (do callback) por tokens.
  Future<BlingTokens> exchangeCode(String code) => _token({
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': redirectUri,
      });

  /// Renova o access token usando o refresh token.
  Future<BlingTokens> refresh(String refreshToken) => _token({
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
      });

  Future<BlingTokens> _token(Map<String, String> form) async {
    final basic = base64Encode(utf8.encode('$clientId:$clientSecret'));
    final res = await _send(
      'POST',
      '$_authBase/oauth/token',
      headers: {
        'Authorization': 'Basic $basic',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: form.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&'),
    );
    final j = jsonDecode(res) as Map<String, dynamic>;
    return BlingTokens(
      (j['access_token'] ?? '').toString(),
      (j['refresh_token'] ?? '').toString(),
      int.tryParse('${j['expires_in'] ?? 21600}') ?? 21600,
    );
  }

  /// Puxa produtos (e saldo, se vier) do Bling. Retorna lista normalizada.
  Future<List<Map<String, dynamic>>> getProducts(String accessToken) async {
    final res = await _send(
      'GET',
      '$_apiBase/produtos?limite=100',
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    final j = jsonDecode(res) as Map<String, dynamic>;
    final data = (j['data'] as List?) ?? const [];
    return data.map<Map<String, dynamic>>((p) {
      final m = p as Map<String, dynamic>;
      final estoque = m['estoque'];
      final saldo = estoque is Map ? estoque['saldoVirtualTotal'] : null;
      return {
        'sku': (m['codigo'] ?? m['id'] ?? '').toString(),
        'descricao': (m['nome'] ?? '').toString(),
        'preco': _toDouble(m['preco']),
        'codigo_ean': (m['gtin'] ?? '').toString(),
        'ncm': (m['tributacao']?['ncm'] ?? '00000000').toString(),
        'unidade_medida': (m['unidade'] ?? 'UN').toString(),
        'qtd_fisica': _toDouble(saldo),
      };
    }).toList();
  }

  /// Empurra uma venda para o Bling (cria pedido de venda).
  Future<void> createSale(
    String accessToken, {
    required String clienteNome,
    required String clienteDoc,
    required List<Map<String, dynamic>> itens, // {descricao, sku, quantidade, valor}
  }) async {
    final payload = {
      'contato': {'nome': clienteNome, 'numeroDocumento': clienteDoc},
      'itens': itens
          .map((i) => {
                'descricao': i['descricao'],
                'codigo': i['sku'],
                'quantidade': i['quantidade'],
                'valor': i['valor'],
              })
          .toList(),
    };
    await _send(
      'POST',
      '$_apiBase/pedidos/vendas',
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );
  }

  /// Busca o contato (destinatário) no Bling pelo documento (CPF/CNPJ).
  /// Retorna o mapa do contato (com id, ie, endereço) ou null se não achar.
  Future<Map<String, dynamic>?> buscarContato(
      String accessToken, String documento) async {
    final doc = documento.replaceAll(RegExp(r'[^0-9]'), '');
    if (doc.isEmpty) return null;
    try {
      final res = await _send(
        'GET',
        '$_apiBase/contatos?numeroDocumento=$doc',
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      final j = jsonDecode(res) as Map<String, dynamic>;
      final data = (j['data'] as List?) ?? const [];
      if (data.isEmpty) return null;
      return data.first as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Identidade da empresa dona do token Bling (nome + CNPJ). Usado pra mostrar
  /// no painel DE QUEM é o Bling conectado. Parsing defensivo (nomes variam).
  Future<Map<String, String>> dadosEmpresa(String accessToken) async {
    final res = await _send(
      'GET',
      '$_apiBase/empresas/me/dados-basicos',
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    final j = jsonDecode(res) as Map<String, dynamic>;
    final d = (j['data'] as Map<String, dynamic>?) ?? j;
    final fiscais = (d['dadosFiscais'] as Map<String, dynamic>?) ?? const {};
    String pick(List<dynamic> vs) {
      for (final v in vs) {
        if (v != null && v.toString().trim().isNotEmpty) return v.toString();
      }
      return '';
    }
    return {
      'nome': pick([d['nomeFantasia'], d['fantasia'], d['nome'], d['razaoSocial']]),
      'cnpj': pick([d['cnpj'], d['numeroDocumento'], fiscais['cnpj'], fiscais['numeroDocumento']]),
    };
  }

  /// Lista os contatos (clientes) do Bling para seleção na venda.
  /// [pesquisa] filtra por nome/documento. Retorna lista normalizada.
  Future<List<Map<String, dynamic>>> listarContatos(String accessToken,
      {String pesquisa = ''}) async {
    final q = pesquisa.trim().isEmpty
        ? '?limite=100'
        : '?limite=100&pesquisa=${Uri.encodeComponent(pesquisa.trim())}';
    final res = await _send(
      'GET',
      '$_apiBase/contatos$q',
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    final j = jsonDecode(res) as Map<String, dynamic>;
    final data = (j['data'] as List?) ?? const [];
    return data.map<Map<String, dynamic>>((e) {
      final m = e as Map<String, dynamic>;
      return {
        'id': m['id'],
        'nome': (m['nome'] ?? '').toString(),
        'numero_documento': (m['numeroDocumento'] ?? '').toString(),
        'tipo_pessoa': (m['tipoPessoa'] ?? '').toString(),
      };
    }).toList();
  }

  /// Busca o link do boleto (conta a receber) gerado para a NF-e, se houver.
  /// Best-effort: procura a conta a receber vinculada e devolve o link.
  Future<String> buscarLinkBoleto(String accessToken, int idNota) async {
    try {
      final res = await _send(
        'GET',
        '$_apiBase/nfe/$idNota',
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      final j = jsonDecode(res) as Map<String, dynamic>;
      final d = (j['data'] as Map<String, dynamic>?) ?? const {};
      // alguns retornos trazem o link do boleto direto na nota
      final link = (d['linkBoleto'] ?? d['linkPDFBoleto'] ?? '').toString();
      return link;
    } catch (_) {
      return '';
    }
  }

  /// Lista as naturezas de operação ativas do Bling (id + descrição).
  Future<List<Map<String, dynamic>>> listarNaturezas(String accessToken) async {
    final res = await _send(
      'GET',
      '$_apiBase/naturezas-operacoes?situacao=1',
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    final j = jsonDecode(res) as Map<String, dynamic>;
    final data = (j['data'] as List?) ?? const [];
    return data
        .map<Map<String, dynamic>>((e) => {
              'id': (e as Map)['id'],
              'descricao': (e['descricao'] ?? '').toString(),
            })
        .toList();
  }

  /// Lista as formas de pagamento do Bling (id + descrição).
  Future<List<Map<String, dynamic>>> listarFormasPagamento(
      String accessToken) async {
    final res = await _send(
      'GET',
      '$_apiBase/formas-pagamentos',
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    final j = jsonDecode(res) as Map<String, dynamic>;
    final data = (j['data'] as List?) ?? const [];
    return data
        .map<Map<String, dynamic>>((e) => {
              'id': (e as Map)['id'],
              'descricao': (e['descricao'] ?? '').toString(),
            })
        .toList();
  }

  /// Cria a NF-e modelo 55 no Bling (situação pendente). Retorna o id da nota.
  /// [naturezaOperacaoId] e [lojaId] vêm da conta Bling do cliente (env/config).
  Future<int> createNfe(
    String accessToken, {
    required Map<String, dynamic> destinatario, // nome, tipoPessoa, numeroDocumento, ie, endereco
    required List<Map<String, dynamic>> itens, // codigo, descricao, unidade, quantidade, valor, classificacaoFiscal
    required List<Map<String, dynamic>> parcelas, // data, valor, formaPagamento:{id}
    int? naturezaOperacaoId,
    int? lojaId,
    String? observacoes,
  }) async {
    final hoje = DateTime.now();
    final dataOperacao =
        '${hoje.year.toString().padLeft(4, '0')}-${hoje.month.toString().padLeft(2, '0')}-${hoje.day.toString().padLeft(2, '0')}';
    final payload = <String, dynamic>{
      'tipo': 1, // saída
      'finalidade': 1, // normal
      'dataOperacao': dataOperacao,
      'contato': destinatario,
      'itens': itens,
      'parcelas': parcelas,
      if (naturezaOperacaoId != null) 'naturezaOperacao': {'id': naturezaOperacaoId},
      if (lojaId != null) 'loja': {'id': lojaId},
      if (observacoes != null && observacoes.isNotEmpty) 'observacoes': observacoes,
    };
    final res = await _send(
      'POST',
      '$_apiBase/nfe',
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );
    final j = jsonDecode(res) as Map<String, dynamic>;
    final id = (j['data']?['id']);
    final parsed = id is int ? id : int.tryParse('$id');
    if (parsed == null) {
      throw HttpException('Bling createNfe: id da nota ausente -> $res');
    }
    return parsed;
  }

  /// Envia a NF-e à SEFAZ (autoriza). Retorna o corpo da resposta.
  Future<Map<String, dynamic>> enviarNfe(String accessToken, int idNota) async {
    final res = await _send(
      'POST',
      '$_apiBase/nfe/$idNota/enviar',
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    return jsonDecode(res) as Map<String, dynamic>;
  }

  /// Consulta a NF-e no Bling. Normaliza situação/chave/link do DANFE.
  Future<Map<String, dynamic>> getNfe(String accessToken, int idNota) async {
    final res = await _send(
      'GET',
      '$_apiBase/nfe/$idNota',
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    final j = jsonDecode(res) as Map<String, dynamic>;
    final d = (j['data'] as Map<String, dynamic>?) ?? const {};
    final situacao = int.tryParse('${d['situacao'] ?? 0}') ?? 0;
    return {
      'situacao': situacao,
      'status': _situacaoNfe(situacao),
      'chave_acesso': (d['chaveAcesso'] ?? '').toString(),
      'numero': (d['numero'] ?? '').toString(),
      'serie': (d['serie'] ?? '').toString(),
      'link_danfe': (d['linkDanfe'] ?? d['linkPDF'] ?? '').toString(),
      'motivo': (d['xmlMotivo'] ?? d['motivo'] ?? '').toString(),
    };
  }

  /// Mapeia a situação numérica da NF-e do Bling para o status do nosso domínio.
  static String _situacaoNfe(int s) => switch (s) {
        5 || 6 || 7 => 'AUTORIZADO', // autorizada / danfe emitida / registrada
        4 => 'REJEITADO',
        2 => 'CANCELADO',
        _ => 'PROCESSANDO', // 1 pendente, 3 aguardando recibo, etc.
      };

  Future<String> _send(String method, String url,
      {Map<String, String>? headers, String? body}) async {
    final client = HttpClient();
    try {
      final req = await client.openUrl(method, Uri.parse(url));
      headers?.forEach(req.headers.set);
      if (body != null) req.write(body);
      final res = await req.close();
      final text = await res.transform(utf8.decoder).join();
      if (res.statusCode >= 400) {
        throw HttpException('Bling $method $url -> ${res.statusCode}: $text');
      }
      return text;
    } finally {
      client.close(force: true);
    }
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }
}
