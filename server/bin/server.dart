import 'dart:convert';
import 'dart:io';

import 'package:postgres/postgres.dart' show Sql, ServerException;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:venda_completa_server/auth.dart';
import 'package:venda_completa_server/db.dart';
import 'package:venda_completa_server/nfce_xml_builder.dart';
import 'package:venda_completa_server/sefaz_service.dart';

/// Transmissão fiscal. Troque por uma implementação real (provedor/SEFAZ)
/// para produção — é o único ponto a mudar.
final SefazService _sefaz = FakeSefazService();

/// Conexões WebSocket ativas, agrupadas por empresa (tenant_id). O broadcast
/// de estoque é roteado ESTRITAMENTE para os clientes do mesmo tenant.
final Map<String, Set<WebSocketChannel>> _wsClients = {};

void _wsRegister(String tenantId, WebSocketChannel ch) {
  _wsClients.putIfAbsent(tenantId, () => <WebSocketChannel>{}).add(ch);
}

void _wsUnregister(String tenantId, WebSocketChannel ch) {
  _wsClients[tenantId]?.remove(ch);
  if (_wsClients[tenantId]?.isEmpty ?? false) _wsClients.remove(tenantId);
}

/// Envia um evento de estoque atualizado a todos os clientes do tenant.
void _broadcastInventory(String tenantId, List<Map<String, dynamic>> items) {
  final channels = _wsClients[tenantId];
  if (channels == null || channels.isEmpty) return;
  final msg = jsonEncode({
    'event_type': 'inventory.updated',
    'tenant_id': tenantId,
    'items': items,
  });
  for (final ch in channels.toList()) {
    try {
      ch.sink.add(msg);
    } catch (_) {/* conexão caindo — ignora */}
  }
}

/// Converte valores vindos do Postgres (NUMERIC pode vir como String) em double.
double _toDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}

/// POST /auth/login  { email, password }
/// Resolve a empresa pelo cadastro do vendedor e devolve o JWT com o tenant_id.
Future<Response> _login(Request req) async {
  final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
  final email = (body['email'] ?? '').toString().trim().toLowerCase();
  final password = (body['password'] ?? '').toString();

  if (email.isEmpty || password.isEmpty) {
    return _json(400, {'error': 'Informe e-mail e senha.'});
  }

  final rows = await Db.query(
    '''
    SELECT s.id AS seller_id, s.nome AS seller_name, s.senha_hash, s.role,
           t.id AS tenant_id, t.nome_fantasia AS tenant_name,
           t.razao_social, t.cnpj, t.uf
    FROM sellers s
    JOIN tenants t ON t.id = s.tenant_id
    WHERE lower(s.email) = @email AND s.ativo = true
    ''',
    params: {'email': email},
  );

  if (rows.isEmpty) {
    return _json(401, {'error': 'Credenciais inválidas.'});
  }

  final seller = rows.first;
  if (!Auth.verifyPassword(password, seller['senha_hash'].toString())) {
    return _json(401, {'error': 'Credenciais inválidas.'});
  }

  final sellerId = seller['seller_id'].toString();
  final tenantId = seller['tenant_id'].toString();
  final role = (seller['role'] ?? 'vendedor').toString();
  final token = Auth.signToken(
    sellerId: sellerId,
    tenantId: tenantId,
    role: role,
  );

  return _json(200, {
    'access_token': token,
    'token_type': 'Bearer',
    'seller_id': sellerId,
    'seller_name': seller['seller_name'],
    'tenant_id': tenantId,
    'tenant_name': seller['tenant_name'],
    'razao_social': seller['razao_social'],
    'cnpj': seller['cnpj'],
    'uf': seller['uf'],
    'role': role,
  });
}

/// GET /sync/catalog  (Authorization: Bearer <jwt>)
/// Retorna os produtos + estoque da empresa do token.
Future<Response> _catalog(Request req) async {
  final authHeader = req.headers['authorization'] ?? '';
  final token = authHeader.startsWith('Bearer ')
      ? authHeader.substring(7)
      : authHeader;
  final claims = Auth.verifyToken(token);
  if (claims == null) {
    return _json(401, {'error': 'Token inválido ou expirado.'});
  }

  final tenantId = claims['tenant_id'].toString();

  final rows = await Db.query(
    '''
    SELECT p.id, p.sku, p.codigo_ean, p.descricao, p.ncm, p.cest,
           p.unidade_medida, p.preco_venda,
           i.qtd_fisica, i.qtd_reservada, i.cota_offline
    FROM products p
    JOIN inventory i ON i.product_id = p.id
    WHERE p.tenant_id = @tid AND p.ativo = true
    ORDER BY p.descricao
    ''',
    params: {'tid': tenantId},
  );

  final catalog = rows.map((r) {
    return {
      'id': r['id'].toString(),
      'sku': r['sku'],
      'codigo_ean': r['codigo_ean'],
      'descricao': r['descricao'],
      'ncm': r['ncm'],
      'cest': r['cest'],
      'unidade_medida': r['unidade_medida'],
      'preco_venda': _toDouble(r['preco_venda']),
      'qtd_fisica': _toDouble(r['qtd_fisica']),
      'qtd_reservada': _toDouble(r['qtd_reservada']),
      'cota_offline': _toDouble(r['cota_offline']),
    };
  }).toList();

  return _json(200, catalog);
}

/// POST /sync/vendas  (Authorization: Bearer <jwt>)
/// Recebe um pedido da fila Outbox do app, grava no banco central (orders +
/// order_items) e baixa o estoque, tudo numa transação. Idempotente pelo
/// client_order_id (reenvios do mesmo pedido não duplicam).
Future<Response> _syncVenda(Request req) async {
  final authHeader = req.headers['authorization'] ?? '';
  final token =
      authHeader.startsWith('Bearer ') ? authHeader.substring(7) : authHeader;
  final claims = Auth.verifyToken(token);
  if (claims == null) {
    return _json(401, {'error': 'Token inválido ou expirado.'});
  }

  final tenantId = claims['tenant_id'].toString();
  final sellerId = claims['sub'].toString();

  final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
  final clientOrderId = (body['order_id'] ?? '').toString();
  if (clientOrderId.isEmpty) {
    return _json(400, {'error': 'order_id ausente.'});
  }

  // Idempotência: pedido já conciliado antes → responde OK sem duplicar.
  final existing = await Db.query(
    'SELECT id FROM orders WHERE client_order_id = @cid',
    params: {'cid': clientOrderId},
  );
  if (existing.isNotEmpty) {
    return _json(200, {'status': 'already_synced', 'order_id': clientOrderId});
  }

  final items = (body['items'] as List).cast<Map<String, dynamic>>();
  final formaPagamento = (body['payment_method'] ?? 'DINHEIRO').toString();
  final valorTotal = _toDouble(body['total_amount']);
  final clienteNome = (body['cliente_nome'] ?? 'Consumidor Final').toString();
  final clienteDoc = (body['cliente_cpf_cnpj'] ?? '00000000000').toString();

  try {
    await Db.connection.runTx((tx) async {
      final inserted = await tx.execute(
        Sql.named('''
          INSERT INTO orders (client_order_id, tenant_id, seller_id,
            cliente_nome, cliente_cpf_cnpj, status, forma_pagamento, valor_total)
          VALUES (@cid, @tid, @sid, @nome, @doc, 'SINCRONIZADO', @pag, @total)
          RETURNING id
        '''),
        parameters: {
          'cid': clientOrderId,
          'tid': tenantId,
          'sid': sellerId,
          'nome': clienteNome,
          'doc': clienteDoc,
          'pag': formaPagamento,
          'total': valorTotal,
        },
      );
      final orderId = inserted.first.first.toString();

      for (final item in items) {
        final productId = (item['product_id'] ?? '').toString();
        final qtd = _toDouble(item['quantidade']);
        await tx.execute(
          Sql.named('''
            INSERT INTO order_items (tenant_id, order_id, product_id, sku,
              descricao, quantidade, preco_unitario, total)
            VALUES (@tid, @oid, @pid, @sku, @desc, @qtd, @preco, @total)
          '''),
          parameters: {
            'tid': tenantId,
            'oid': orderId,
            'pid': productId,
            'sku': (item['sku'] ?? '').toString(),
            'desc': (item['descricao'] ?? '').toString(),
            'qtd': qtd,
            'preco': _toDouble(item['preco_unitario']),
            'total': _toDouble(item['total']),
          },
        );
        await tx.execute(
          Sql.named('''
            UPDATE inventory SET qtd_fisica = qtd_fisica - @qtd,
              updated_at = CURRENT_TIMESTAMP
            WHERE tenant_id = @tid AND product_id = @pid
          '''),
          parameters: {'qtd': qtd, 'tid': tenantId, 'pid': productId},
        );
      }

      // Nota fiscal emitida no app em contingência. Ao chegar ao servidor,
      // simulamos a transmissão à SEFAZ: ela "autoriza" e devolve o protocolo.
      final fiscal = body['fiscal'];
      if (fiscal is Map) {
        await tx.execute(
          Sql.named('''
            INSERT INTO fiscal_invoices (tenant_id, order_id, modelo, serie,
              numero, chave_acesso, tp_emis, status_sefaz)
            VALUES (@t, @o, @mod, @s, @n, @chave, @tp, 'OFFLINE')
            ON CONFLICT (chave_acesso) DO NOTHING
          '''),
          parameters: {
            't': tenantId,
            'o': orderId,
            'mod': (fiscal['modelo'] ?? '65').toString(),
            's': int.tryParse('${fiscal['serie'] ?? 1}') ?? 1,
            'n': int.tryParse('${fiscal['numero'] ?? 0}') ?? 0,
            'chave': (fiscal['chave_acesso'] ?? '').toString(),
            'tp': (fiscal['tp_emis'] ?? '9').toString(),
          },
        );
      }
    });
  } catch (e) {
    return _json(500, {'error': 'Falha ao gravar a venda: $e'});
  }

  // Transmissão à SEFAZ (fora da transação — é rede/assíncrono). Troque a
  // injeção de `_sefaz` por uma implementação real para produção.
  final fiscal = body['fiscal'];
  if (fiscal is Map) {
    try {
      final chave = (fiscal['chave_acesso'] ?? '').toString();

      // Monta o XML da NFC-e (dados do emitente + itens da venda).
      final emit = await Db.query(
        'SELECT razao_social, cnpj, inscricao_estadual, uf FROM tenants WHERE id = @t',
        params: {'t': tenantId},
      );
      String? xml;
      if (emit.isNotEmpty) {
        final e = emit.first;
        xml = NfceXmlBuilder.build(
          chave: chave,
          razaoSocial: (e['razao_social'] ?? '').toString(),
          cnpj: (e['cnpj'] ?? '').toString(),
          inscricaoEstadual: (e['inscricao_estadual'] ?? '').toString(),
          uf: (e['uf'] ?? 'SP').toString(),
          serie: int.tryParse('${fiscal['serie'] ?? 1}') ?? 1,
          numero: int.tryParse('${fiscal['numero'] ?? 0}') ?? 0,
          tpEmis: (fiscal['tp_emis'] ?? '9').toString(),
          itens: items,
          valorTotal: valorTotal,
          formaPagamento: formaPagamento,
        );
      }

      // Transmite (mock). RealSefazService assinaria o XML e enviaria à SEFAZ.
      final r = await _sefaz.transmitir(
        chaveAcesso: chave,
        modelo: (fiscal['modelo'] ?? '65').toString(),
        serie: int.tryParse('${fiscal['serie'] ?? 1}') ?? 1,
        numero: int.tryParse('${fiscal['numero'] ?? 0}') ?? 0,
        tpEmis: (fiscal['tp_emis'] ?? '9').toString(),
      );
      await Db.connection.execute(
        Sql.named('''
          UPDATE fiscal_invoices
          SET status_sefaz = @s, protocolo_autorizacao = @p, motivo_rejeicao = @m,
              xml_assinado = @xml
          WHERE tenant_id = @t AND chave_acesso = @c
        '''),
        parameters: {
          's': r.status,
          'p': r.protocolo,
          'm': r.motivo,
          'xml': xml,
          't': tenantId,
          'c': chave,
        },
      );
    } catch (_) {/* fica OFFLINE para nova tentativa de conciliação */}
  }

  // Broadcast de estoque em tempo real para os outros vendedores do tenant.
  try {
    final affected = <Map<String, dynamic>>[];
    for (final item in items) {
      final pid = (item['product_id'] ?? '').toString();
      final r = await Db.query(
        '''
        SELECT p.sku, i.qtd_fisica, i.qtd_reservada
        FROM inventory i JOIN products p ON p.id = i.product_id
        WHERE i.tenant_id = @tid AND i.product_id = @pid
        ''',
        params: {'tid': tenantId, 'pid': pid},
      );
      if (r.isNotEmpty) {
        affected.add({
          'product_id': pid,
          'sku': r.first['sku'],
          'qtd_fisica': _toDouble(r.first['qtd_fisica']),
          'qtd_reservada': _toDouble(r.first['qtd_reservada']),
        });
      }
    }
    if (affected.isNotEmpty) _broadcastInventory(tenantId, affected);
  } catch (_) {/* broadcast é best-effort, não afeta a venda */}

  return _json(201, {'status': 'synced', 'order_id': clientOrderId});
}

/// GET /ws?token=<jwt>
/// Autentica pela query (headers não são confiáveis em WS de navegador),
/// faz o upgrade e registra a conexão no tenant do token.
Future<Response> _wsHandler(Request req) async {
  final token = req.url.queryParameters['token'] ?? '';
  final claims = Auth.verifyToken(token);
  if (claims == null) {
    return Response.forbidden('Token inválido.');
  }
  final tenantId = claims['tenant_id'].toString();

  final handler = webSocketHandler((WebSocketChannel ch, _) {
    _wsRegister(tenantId, ch);
    ch.stream.listen(
      (_) {}, // não esperamos mensagens do cliente por enquanto
      onDone: () => _wsUnregister(tenantId, ch),
      onError: (_) => _wsUnregister(tenantId, ch),
    );
  });

  return await handler(req);
}

// =============================================================================
// PAINEL ADMINISTRATIVO — exige papel 'admin', escopo pelo tenant do token.
// =============================================================================

/// Serve a página HTML do painel administrativo.
Future<Response> _adminPage(Request req) async {
  final file = File('web/admin.html');
  if (!await file.exists()) {
    return Response.notFound('Página do painel não encontrada.');
  }
  return Response.ok(
    await file.readAsString(),
    headers: {'content-type': 'text/html; charset=utf-8'},
  );
}

/// Valida o token (qualquer papel) e devolve as claims, ou null.
Map<String, dynamic>? _authClaims(Request req) {
  final auth = req.headers['authorization'] ?? '';
  final token = auth.startsWith('Bearer ') ? auth.substring(7) : auth;
  return Auth.verifyToken(token);
}

/// GET /fiscal/status/<orderId> — status fiscal (SEFAZ) de um pedido do app.
Future<Response> _fiscalStatus(Request req, String orderId) async {
  final claims = _authClaims(req);
  if (claims == null) return _json(401, {'error': 'Token inválido.'});
  final tenantId = claims['tenant_id'].toString();
  final rows = await Db.query(
    '''
    SELECT fi.status_sefaz, fi.protocolo_autorizacao, fi.chave_acesso
    FROM fiscal_invoices fi
    JOIN orders o ON o.id = fi.order_id
    WHERE o.tenant_id = @t AND o.client_order_id = @c
    ''',
    params: {'t': tenantId, 'c': orderId},
  );
  if (rows.isEmpty) {
    return _json(200, {'status_sefaz': 'PENDENTE'});
  }
  return _json(200, {
    'status_sefaz': rows.first['status_sefaz'],
    'protocolo': rows.first['protocolo_autorizacao'],
    'chave_acesso': rows.first['chave_acesso'],
  });
}

/// Valida o token e exige papel admin. Retorna as claims ou null.
Map<String, dynamic>? _adminClaims(Request req) {
  final auth = req.headers['authorization'] ?? '';
  final token = auth.startsWith('Bearer ') ? auth.substring(7) : auth;
  final claims = Auth.verifyToken(token);
  if (claims == null || claims['role'] != 'admin') return null;
  return claims;
}

Future<Response> _adminListProducts(Request req) async {
  final claims = _adminClaims(req);
  if (claims == null) return _json(403, {'error': 'Acesso restrito ao administrador.'});
  final tenantId = claims['tenant_id'].toString();
  final rows = await Db.query(
    '''
    SELECT p.id, p.sku, p.codigo_ean, p.descricao, p.ncm, p.cest,
           p.unidade_medida, p.preco_venda, i.qtd_fisica, i.qtd_reservada
    FROM products p JOIN inventory i ON i.product_id = p.id
    WHERE p.tenant_id = @t AND p.ativo = true ORDER BY p.descricao
    ''',
    params: {'t': tenantId},
  );
  return _json(200, rows.map((r) => {
        'id': r['id'].toString(),
        'sku': r['sku'],
        'codigo_ean': r['codigo_ean'],
        'descricao': r['descricao'],
        'ncm': r['ncm'],
        'cest': r['cest'],
        'unidade_medida': r['unidade_medida'],
        'preco_venda': _toDouble(r['preco_venda']),
        'qtd_fisica': _toDouble(r['qtd_fisica']),
        'qtd_reservada': _toDouble(r['qtd_reservada']),
      }).toList());
}

Future<Response> _adminCreateProduct(Request req) async {
  final claims = _adminClaims(req);
  if (claims == null) return _json(403, {'error': 'Acesso restrito ao administrador.'});
  final tenantId = claims['tenant_id'].toString();
  final b = jsonDecode(await req.readAsString()) as Map<String, dynamic>;

  final sku = (b['sku'] ?? '').toString().trim();
  final descricao = (b['descricao'] ?? '').toString().trim();
  if (sku.isEmpty || descricao.isEmpty || b['preco_venda'] == null) {
    return _json(400, {'error': 'sku, descricao e preco_venda são obrigatórios.'});
  }

  try {
    await Db.connection.runTx((tx) async {
      final res = await tx.execute(
        Sql.named('''
          INSERT INTO products (tenant_id, codigo_ean, sku, descricao,
            preco_venda, ncm, cest, unidade_medida)
          VALUES (@t, @ean, @sku, @desc, @preco, @ncm, @cest, @un)
          RETURNING id
        '''),
        parameters: {
          't': tenantId,
          'ean': (b['codigo_ean'] ?? '').toString(),
          'sku': sku,
          'desc': descricao,
          'preco': _toDouble(b['preco_venda']),
          'ncm': (b['ncm'] ?? '00000000').toString(),
          'cest': b['cest']?.toString(),
          'un': (b['unidade_medida'] ?? 'UN').toString(),
        },
      );
      final pid = res.first.first.toString();
      await tx.execute(
        Sql.named('''
          INSERT INTO inventory (tenant_id, product_id, qtd_fisica)
          VALUES (@t, @p, @q)
        '''),
        parameters: {'t': tenantId, 'p': pid, 'q': _toDouble(b['qtd_fisica'])},
      );
    });
  } on ServerException catch (e) {
    if (e.code == '23505') {
      return _json(409, {'error': 'Já existe um produto com esse SKU.'});
    }
    return _json(500, {'error': 'Falha ao criar produto: ${e.message}'});
  } catch (e) {
    return _json(500, {'error': 'Falha ao criar produto: $e'});
  }
  return _json(201, {'status': 'created'});
}

Future<Response> _adminUpdateProduct(Request req, String id) async {
  final claims = _adminClaims(req);
  if (claims == null) return _json(403, {'error': 'Acesso restrito ao administrador.'});
  final tenantId = claims['tenant_id'].toString();
  final b = jsonDecode(await req.readAsString()) as Map<String, dynamic>;

  try {
    await Db.connection.runTx((tx) async {
      await tx.execute(
        Sql.named('''
          UPDATE products SET
            descricao = @desc, preco_venda = @preco, codigo_ean = @ean,
            ncm = @ncm, cest = @cest, unidade_medida = @un
          WHERE id = @id AND tenant_id = @t
        '''),
        parameters: {
          'id': id,
          't': tenantId,
          'desc': (b['descricao'] ?? '').toString(),
          'preco': _toDouble(b['preco_venda']),
          'ean': (b['codigo_ean'] ?? '').toString(),
          'ncm': (b['ncm'] ?? '00000000').toString(),
          'cest': b['cest']?.toString(),
          'un': (b['unidade_medida'] ?? 'UN').toString(),
        },
      );
      if (b['qtd_fisica'] != null) {
        await tx.execute(
          Sql.named('''
            UPDATE inventory SET qtd_fisica = @q, updated_at = CURRENT_TIMESTAMP
            WHERE product_id = @id AND tenant_id = @t
          '''),
          parameters: {'q': _toDouble(b['qtd_fisica']), 'id': id, 't': tenantId},
        );
      }
    });
  } catch (e) {
    return _json(500, {'error': 'Falha ao atualizar produto: $e'});
  }
  return _json(200, {'status': 'updated'});
}

/// Parser CSV (RFC4180-ish): trata aspas, aspas escapadas ("") e CRLF.
List<List<String>> _parseCsv(String input, String delim) {
  final rows = <List<String>>[];
  var field = StringBuffer();
  var row = <String>[];
  var inQuotes = false;
  for (var i = 0; i < input.length; i++) {
    final c = input[i];
    if (inQuotes) {
      if (c == '"') {
        if (i + 1 < input.length && input[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        field.write(c);
      }
    } else if (c == '"') {
      inQuotes = true;
    } else if (c == delim) {
      row.add(field.toString());
      field = StringBuffer();
    } else if (c == '\n') {
      row.add(field.toString());
      rows.add(row);
      row = <String>[];
      field = StringBuffer();
    } else if (c != '\r') {
      field.write(c);
    }
  }
  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    rows.add(row);
  }
  return rows;
}

/// Converte número aceitando vírgula decimal (BR) e ponto de milhar.
double? _parseNum(String s) {
  var v = s.trim();
  if (v.isEmpty) return null;
  if (v.contains(',')) v = v.replaceAll('.', '').replaceAll(',', '.');
  return double.tryParse(v);
}

/// POST /admin/products/import  (corpo = texto CSV)
/// Importa/atualiza produtos em lote por SKU. Pula linhas inválidas e
/// devolve um relatório {total, criados, atualizados, erros:[...]}.
Future<Response> _adminImportProducts(Request req) async {
  final claims = _adminClaims(req);
  if (claims == null) return _json(403, {'error': 'Acesso restrito ao administrador.'});
  final tenantId = claims['tenant_id'].toString();

  final text = await req.readAsString();
  if (text.trim().isEmpty) return _json(400, {'error': 'Arquivo vazio.'});

  // Detecta separador pela primeira linha (; comum no Excel BR).
  final firstLine = text.split('\n').first;
  final delim = firstLine.split(';').length > firstLine.split(',').length ? ';' : ',';

  final rows = _parseCsv(text, delim);
  if (rows.isEmpty) return _json(400, {'error': 'Sem linhas.'});

  // Cabeçalho -> índice das colunas (nomes flexíveis).
  final header = rows.first.map((h) => h.trim().toLowerCase()).toList();
  int col(List<String> names) =>
      header.indexWhere((h) => names.contains(h));
  final iSku = col(['sku', 'codigo', 'código']);
  final iEan = col(['codigo_ean', 'ean', 'gtin']);
  final iDesc = col(['descricao', 'descrição', 'nome']);
  final iPreco = col(['preco_venda', 'preco', 'preço', 'valor']);
  final iNcm = col(['ncm']);
  final iUn = col(['unidade_medida', 'unidade', 'un']);
  final iQtd = col(['qtd_fisica', 'estoque', 'quantidade', 'qtd']);

  if (iSku < 0 || iDesc < 0 || iPreco < 0) {
    return _json(400, {
      'error':
          'Cabeçalho precisa conter ao menos: sku, descricao, preco_venda.'
    });
  }

  var criados = 0, atualizados = 0;
  final erros = <Map<String, dynamic>>[];

  String cell(List<String> r, int idx) =>
      (idx >= 0 && idx < r.length) ? r[idx].trim() : '';

  for (var ln = 1; ln < rows.length; ln++) {
    final r = rows[ln];
    if (r.every((c) => c.trim().isEmpty)) continue; // linha em branco
    final sku = cell(r, iSku);
    final desc = cell(r, iDesc);
    final preco = _parseNum(cell(r, iPreco));
    if (sku.isEmpty || desc.isEmpty || preco == null) {
      erros.add({'linha': ln + 1, 'motivo': 'sku/descricao/preco inválidos'});
      continue;
    }
    try {
      final res = await Db.connection.runTx((tx) async {
        final up = await tx.execute(
          Sql.named('''
            INSERT INTO products (tenant_id, codigo_ean, sku, descricao,
              preco_venda, ncm, unidade_medida)
            VALUES (@t, @ean, @sku, @desc, @preco, @ncm, @un)
            ON CONFLICT (tenant_id, sku) DO UPDATE SET
              codigo_ean = EXCLUDED.codigo_ean, descricao = EXCLUDED.descricao,
              preco_venda = EXCLUDED.preco_venda, ncm = EXCLUDED.ncm,
              unidade_medida = EXCLUDED.unidade_medida, ativo = true
            RETURNING id, (xmax = 0) AS inserted
          '''),
          parameters: {
            't': tenantId,
            'ean': cell(r, iEan),
            'sku': sku,
            'desc': desc,
            'preco': preco,
            'ncm': cell(r, iNcm).isEmpty ? '00000000' : cell(r, iNcm),
            'un': cell(r, iUn).isEmpty ? 'UN' : cell(r, iUn),
          },
        );
        final pid = up.first[0].toString();
        final inserted = up.first[1] as bool;
        final qtd = _parseNum(cell(r, iQtd)) ?? 0;
        await tx.execute(
          Sql.named('''
            INSERT INTO inventory (tenant_id, product_id, qtd_fisica)
            VALUES (@t, @p, @q)
            ON CONFLICT (tenant_id, product_id) DO UPDATE SET
              qtd_fisica = EXCLUDED.qtd_fisica, updated_at = CURRENT_TIMESTAMP
          '''),
          parameters: {'t': tenantId, 'p': pid, 'q': qtd},
        );
        return inserted;
      });
      if (res) {
        criados++;
      } else {
        atualizados++;
      }
    } catch (e) {
      erros.add({'linha': ln + 1, 'motivo': e.toString()});
    }
  }

  return _json(200, {
    'total': criados + atualizados,
    'criados': criados,
    'atualizados': atualizados,
    'erros': erros,
  });
}

/// GET /admin/invoices — lista as notas fiscais da empresa (status + protocolo).
Future<Response> _adminListInvoices(Request req) async {
  final claims = _adminClaims(req);
  if (claims == null) return _json(403, {'error': 'Acesso restrito ao administrador.'});
  final tenantId = claims['tenant_id'].toString();
  final rows = await Db.query(
    '''
    SELECT fi.chave_acesso, fi.modelo, fi.serie, fi.numero, fi.tp_emis,
           fi.status_sefaz, fi.protocolo_autorizacao,
           o.valor_total, o.cliente_nome, fi.created_at
    FROM fiscal_invoices fi
    JOIN orders o ON o.id = fi.order_id
    WHERE fi.tenant_id = @t
    ORDER BY fi.created_at DESC
    ''',
    params: {'t': tenantId},
  );
  return _json(200, rows.map((r) => {
        'chave_acesso': r['chave_acesso'],
        'modelo': r['modelo'],
        'serie': r['serie'],
        'numero': r['numero'],
        'tp_emis': r['tp_emis'],
        'status_sefaz': r['status_sefaz'],
        'protocolo': r['protocolo_autorizacao'],
        'valor_total': _toDouble(r['valor_total']),
        'cliente_nome': r['cliente_nome'],
        'created_at': r['created_at'].toString(),
      }).toList());
}

/// GET /admin/invoices/<chave>/xml — devolve o XML da NFC-e.
Future<Response> _adminInvoiceXml(Request req, String chave) async {
  final claims = _adminClaims(req);
  if (claims == null) return _json(403, {'error': 'Acesso restrito ao administrador.'});
  final tenantId = claims['tenant_id'].toString();
  final rows = await Db.query(
    'SELECT xml_assinado FROM fiscal_invoices WHERE tenant_id = @t AND chave_acesso = @c',
    params: {'t': tenantId, 'c': chave},
  );
  if (rows.isEmpty || rows.first['xml_assinado'] == null) {
    return _json(404, {'error': 'XML não encontrado.'});
  }
  return Response.ok(
    rows.first['xml_assinado'].toString(),
    headers: {'content-type': 'application/xml; charset=utf-8'},
  );
}

/// DELETE /admin/products/<id> — desativa o produto (soft-delete).
Future<Response> _adminDeleteProduct(Request req, String id) async {
  final claims = _adminClaims(req);
  if (claims == null) return _json(403, {'error': 'Acesso restrito ao administrador.'});
  final tenantId = claims['tenant_id'].toString();
  final r = await Db.connection.execute(
    Sql.named('UPDATE products SET ativo = false WHERE id = @id AND tenant_id = @t'),
    parameters: {'id': id, 't': tenantId},
  );
  if (r.affectedRows == 0) return _json(404, {'error': 'Produto não encontrado.'});
  return _json(200, {'status': 'deleted'});
}

/// PUT /admin/sellers/<id> — edita um vendedor (e ativa/inativa).
Future<Response> _adminUpdateSeller(Request req, String id) async {
  final claims = _adminClaims(req);
  if (claims == null) return _json(403, {'error': 'Acesso restrito ao administrador.'});
  final tenantId = claims['tenant_id'].toString();
  final b = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
  final senha = (b['senha'] ?? '').toString();
  try {
    await Db.connection.execute(
      Sql.named('''
        UPDATE sellers SET nome = @nome, email = @email, cpf = @cpf,
          ativo = @ativo${senha.isNotEmpty ? ', senha_hash = @hash' : ''}
        WHERE id = @id AND tenant_id = @t AND role = 'vendedor'
      '''),
      parameters: {
        'id': id,
        't': tenantId,
        'nome': (b['nome'] ?? '').toString(),
        'email': (b['email'] ?? '').toString().trim().toLowerCase(),
        'cpf': (b['cpf'] ?? '').toString(),
        'ativo': b['ativo'] == null ? true : b['ativo'] == true,
        if (senha.isNotEmpty) 'hash': 'demo\$$senha',
      },
    );
  } on ServerException catch (e) {
    if (e.code == '23505') return _json(409, {'error': 'E-mail já em uso.'});
    return _json(500, {'error': 'Falha ao atualizar vendedor: ${e.message}'});
  }
  return _json(200, {'status': 'updated'});
}

/// DELETE /admin/sellers/<id> — inativa o vendedor (bloqueia login; preserva vendas).
Future<Response> _adminDeleteSeller(Request req, String id) async {
  final claims = _adminClaims(req);
  if (claims == null) return _json(403, {'error': 'Acesso restrito ao administrador.'});
  final tenantId = claims['tenant_id'].toString();
  final r = await Db.connection.execute(
    Sql.named("UPDATE sellers SET ativo = false WHERE id = @id AND tenant_id = @t AND role = 'vendedor'"),
    parameters: {'id': id, 't': tenantId},
  );
  if (r.affectedRows == 0) return _json(404, {'error': 'Vendedor não encontrado.'});
  return _json(200, {'status': 'inactivated'});
}

Future<Response> _adminListSellers(Request req) async {
  final claims = _adminClaims(req);
  if (claims == null) return _json(403, {'error': 'Acesso restrito ao administrador.'});
  final tenantId = claims['tenant_id'].toString();
  final rows = await Db.query(
    '''
    SELECT id, nome, email, cpf, ativo
    FROM sellers WHERE tenant_id = @t AND role = 'vendedor'
    ORDER BY nome
    ''',
    params: {'t': tenantId},
  );
  return _json(200, rows.map((r) => {
        'id': r['id'].toString(),
        'nome': r['nome'],
        'email': r['email'],
        'cpf': r['cpf'],
        'ativo': r['ativo'],
      }).toList());
}

Future<Response> _adminCreateSeller(Request req) async {
  final claims = _adminClaims(req);
  if (claims == null) return _json(403, {'error': 'Acesso restrito ao administrador.'});
  final tenantId = claims['tenant_id'].toString();
  final b = jsonDecode(await req.readAsString()) as Map<String, dynamic>;

  final nome = (b['nome'] ?? '').toString().trim();
  final email = (b['email'] ?? '').toString().trim().toLowerCase();
  final senha = (b['senha'] ?? '').toString();
  if (nome.isEmpty || email.isEmpty || senha.isEmpty) {
    return _json(400, {'error': 'nome, email e senha são obrigatórios.'});
  }

  try {
    await Db.connection.execute(
      Sql.named('''
        INSERT INTO sellers (tenant_id, nome, email, cpf, senha_hash, role,
          faixa_nosso_numero_inicio, faixa_nosso_numero_fim, nosso_numero_atual)
        VALUES (@t, @nome, @email, @cpf, @hash, 'vendedor', @ini, @fim, @ini)
      '''),
      parameters: {
        't': tenantId,
        'nome': nome,
        'email': email,
        'cpf': (b['cpf'] ?? '00000000000').toString(),
        'hash': 'demo\$$senha', // DEV: mesmo esquema do seed; trocar por bcrypt
        'ini': (b['nosso_numero_inicio'] ?? 1000),
        'fim': (b['nosso_numero_fim'] ?? 1999),
      },
    );
  } on ServerException catch (e) {
    if (e.code == '23505') {
      return _json(409, {'error': 'Já existe um usuário com esse e-mail.'});
    }
    return _json(500, {'error': 'Falha ao criar vendedor: ${e.message}'});
  } catch (e) {
    return _json(500, {'error': 'Falha ao criar vendedor: $e'});
  }
  return _json(201, {'status': 'created'});
}

Response _json(int status, Object data) => Response(
      status,
      body: jsonEncode(data),
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

/// Middleware CORS para permitir chamadas do app (inclusive Web/desktop).
Middleware _cors() {
  const headers = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Origin, Content-Type, Authorization, X-Tenant-ID',
  };
  return (Handler handler) {
    return (Request req) async {
      if (req.method == 'OPTIONS') {
        return Response.ok('', headers: headers);
      }
      final res = await handler(req);
      return res.change(headers: headers);
    };
  };
}

Future<void> main() async {
  await Db.open();
  stdout.writeln('✓ Conectado ao PostgreSQL (venda_completa)');

  final router = Router()
    ..get('/health', (Request req) => _json(200, {'status': 'ok'}))
    ..post('/auth/login', _login)
    ..get('/sync/catalog', _catalog)
    ..post('/sync/vendas', _syncVenda)
    ..get('/fiscal/status/<orderId>', _fiscalStatus)
    ..get('/ws', _wsHandler)
    // Painel administrativo (role=admin)
    ..get('/admin', _adminPage)
    ..get('/admin/products', _adminListProducts)
    ..post('/admin/products', _adminCreateProduct)
    ..post('/admin/products/import', _adminImportProducts)
    ..put('/admin/products/<id>', _adminUpdateProduct)
    ..delete('/admin/products/<id>', _adminDeleteProduct)
    ..get('/admin/sellers', _adminListSellers)
    ..post('/admin/sellers', _adminCreateSeller)
    ..put('/admin/sellers/<id>', _adminUpdateSeller)
    ..delete('/admin/sellers/<id>', _adminDeleteSeller)
    ..get('/admin/invoices', _adminListInvoices)
    ..get('/admin/invoices/<chave>/xml', _adminInvoiceXml);

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(_cors())
      .addHandler(router.call);

  final port = int.parse(Platform.environment['PORT'] ?? '3000');
  final server = await io.serve(handler, InternetAddress.anyIPv4, port);
  stdout.writeln('✓ Servidor rodando em http://localhost:${server.port}');
}
