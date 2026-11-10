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
