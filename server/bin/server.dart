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
import 'package:venda_completa_server/bling_service.dart';

/// Versão publicada do servidor. BUMP a cada deploy relevante — a aba "Status"
/// do painel mostra este valor, então dá pra ver na hora se o deploy subiu.
const String kServerVersion = '2026-11-12.3-bling-empresa-aba';

final BlingService _bling = BlingService();

/// Access token do Bling do tenant, renovando se expirado. Null se não conectado.
Future<String?> _blingToken(String tenantId) async {
  final rows = await Db.query(
    'SELECT bling_access_token, bling_refresh_token, bling_token_expira_em FROM tenants WHERE id = @t',
    params: {'t': tenantId},
  );
  if (rows.isEmpty) return null;
  final r = rows.first;
  final access = (r['bling_access_token'] ?? '').toString();
  final refresh = (r['bling_refresh_token'] ?? '').toString();
  if (access.isEmpty) return null;
  final exp = r['bling_token_expira_em'];
  final expira = exp is DateTime ? exp : DateTime.tryParse('${exp ?? ''}');
  if (expira != null && expira.isAfter(DateTime.now().add(const Duration(minutes: 2)))) {
    return access;
  }
  if (refresh.isEmpty) return access;
  try {
    final t = await _bling.refresh(refresh);
    await _storeBlingTokens(tenantId, t);
    return t.accessToken;
  } catch (_) {
    return access;
  }
}

Future<void> _storeBlingTokens(String tenantId, BlingTokens t) async {
  await Db.connection.execute(
    Sql.named('''
      UPDATE tenants SET bling_access_token = @a, bling_refresh_token = @r,
        bling_token_expira_em = @e WHERE id = @t
    '''),
    parameters: {
      'a': t.accessToken,
      'r': t.refreshToken,
      'e': DateTime.now().add(Duration(seconds: t.expiresIn)),
      't': tenantId,
    },
  );
}

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

  var orderId = '';
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
      orderId = inserted.first.first.toString();

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
    });
  } catch (e) {
    return _json(500, {'error': 'Falha ao gravar a venda: $e'});
  }

  // Emissão da NF-e modelo 55 + boleto pelo Bling (fora da transação — rede).
  // Best-effort: falha não bloqueia a venda; fica para reconciliação.
  await _emitirNfe55Bling(
    tenantId: tenantId,
    orderId: orderId,
    clientOrderId: clientOrderId,
    clienteNome: clienteNome,
    clienteDoc: clienteDoc,
    items: items,
    valorTotal: valorTotal,
  );

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

/// POST /auth/change-password — o próprio vendedor logado troca sua senha.
/// Body: {senha_atual, senha_nova}. Exige token válido (qualquer papel).
Future<Response> _changePassword(Request req) async {
  final claims = _authClaims(req);
  if (claims == null) return _json(401, {'error': 'Token inválido.'});
  final sellerId = claims['sub'].toString();

  final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
  final atual = (body['senha_atual'] ?? '').toString();
  final nova = (body['senha_nova'] ?? '').toString();

  if (nova.length < 6) {
    return _json(400, {'error': 'A nova senha deve ter ao menos 6 caracteres.'});
  }

  final rows = await Db.query(
    'SELECT senha_hash FROM sellers WHERE id = @id AND ativo = true',
    params: {'id': sellerId},
  );
  if (rows.isEmpty) {
    return _json(404, {'error': 'Usuário não encontrado.'});
  }
  if (!Auth.verifyPassword(atual, rows.first['senha_hash'].toString())) {
    return _json(401, {'error': 'Senha atual incorreta.'});
  }

  await Db.query(
    'UPDATE sellers SET senha_hash = @h WHERE id = @id',
    params: {'h': Auth.hashPassword(nova), 'id': sellerId},
  );
  return _json(200, {'status': 'ok'});
}

/// GET /fiscal/status/<orderId> — status fiscal (SEFAZ) de um pedido do app.
/// Emite a NF-e modelo 55 (e gera a parcela/boleto) pelo Bling a partir da
/// venda já gravada. Busca o destinatário no Bling pelo documento (traz IE e
/// endereço que o cliente mantém lá). Grava o resultado em fiscal_invoices.
Future<void> _emitirNfe55Bling({
  required String tenantId,
  required String orderId,
  required String clientOrderId,
  required String clienteNome,
  required String clienteDoc,
  required List<Map<String, dynamic>> items,
  required double valorTotal,
}) async {
  final bt = await _blingToken(tenantId);
  if (bt == null) return; // empresa sem Bling conectado

  try {
    // Config fiscal da empresa (natureza de operação / loja / forma boleto).
    final cfg = await Db.query(
      '''SELECT bling_natureza_operacao_id, bling_loja_id,
                bling_forma_pagamento_boleto_id
         FROM tenants WHERE id = @t''',
      params: {'t': tenantId},
    );
    final c = cfg.isNotEmpty ? cfg.first : const {};
    final naturezaId = int.tryParse('${c['bling_natureza_operacao_id'] ?? ''}');
    final lojaId = int.tryParse('${c['bling_loja_id'] ?? ''}');
    final formaBoletoId =
        int.tryParse('${c['bling_forma_pagamento_boleto_id'] ?? ''}');

    final docLimpo = clienteDoc.replaceAll(RegExp(r'[^0-9]'), '');
    final tipoPessoa = docLimpo.length > 11 ? 'J' : 'F';

    // Destinatário: usa o contato já cadastrado no Bling, se existir.
    final contato = await _bling.buscarContato(bt, clienteDoc);
    final Map<String, dynamic> destinatario = contato != null
        ? {
            'id': contato['id'],
            'nome': (contato['nome'] ?? clienteNome).toString(),
            'numeroDocumento': (contato['numeroDocumento'] ?? clienteDoc).toString(),
            'tipoPessoa': (contato['tipoPessoa'] ?? tipoPessoa).toString(),
            if (contato['ie'] != null) 'ie': contato['ie'],
            if (contato['endereco'] != null) 'endereco': contato['endereco'],
          }
        : {
            'nome': clienteNome,
            'numeroDocumento': clienteDoc,
            'tipoPessoa': tipoPessoa,
          };

    final itensNfe = items
        .map((i) => {
              'codigo': (i['sku'] ?? '').toString(),
              'descricao': (i['descricao'] ?? '').toString(),
              'unidade': 'UN',
              'quantidade': _toDouble(i['quantidade']),
              'valor': _toDouble(i['preco_unitario']),
            })
        .toList();

    // Parcela única (vence em 1 dia); com forma de boleto gera a cobrança.
    final venc = DateTime.now().add(const Duration(days: 1));
    final vencStr =
        '${venc.year.toString().padLeft(4, '0')}-${venc.month.toString().padLeft(2, '0')}-${venc.day.toString().padLeft(2, '0')}';
    final parcelas = <Map<String, dynamic>>[
      {
        'data': vencStr,
        'valor': valorTotal,
        if (formaBoletoId != null) 'formaPagamento': {'id': formaBoletoId},
      }
    ];

    final idNota = await _bling.createNfe(
      bt,
      destinatario: destinatario,
      itens: itensNfe,
      parcelas: parcelas,
      naturezaOperacaoId: naturezaId,
      lojaId: lojaId,
      observacoes: 'Pedido $clientOrderId',
    );

    // Registra a nota como PROCESSANDO antes de enviar à SEFAZ.
    await Db.connection.execute(
      Sql.named('''
        INSERT INTO fiscal_invoices (tenant_id, order_id, modelo, serie, numero,
          tp_emis, status_sefaz, bling_nota_id)
        VALUES (@t, @o, '55', 0, 0, '1', 'PROCESSANDO', @bid)
      '''),
      parameters: {'t': tenantId, 'o': orderId, 'bid': idNota},
    );

    // Envia à SEFAZ e consulta o resultado.
    await _bling.enviarNfe(bt, idNota);
    final st = await _bling.getNfe(bt, idNota);
    await Db.connection.execute(
      Sql.named('''
        UPDATE fiscal_invoices
        SET status_sefaz = @s,
            chave_acesso = NULLIF(@c, ''),
            link_danfe = NULLIF(@l, ''),
            numero = COALESCE(NULLIF(@n, '')::int, numero),
            protocolo_autorizacao = NULLIF(@c, ''),
            motivo_rejeicao = NULLIF(@m, '')
        WHERE bling_nota_id = @bid AND tenant_id = @t
      '''),
      parameters: {
        's': st['status'],
        'c': st['chave_acesso'],
        'l': st['link_danfe'],
        'n': st['numero'],
        'm': st['motivo'],
        'bid': idNota,
        't': tenantId,
      },
    );
  } catch (e) {
    // Falha de emissão: registra para reconciliação, sem bloquear a venda.
    try {
      await Db.connection.execute(
        Sql.named('''
          INSERT INTO fiscal_invoices (tenant_id, order_id, modelo, serie,
            numero, tp_emis, status_sefaz, motivo_rejeicao)
          VALUES (@t, @o, '55', 0, 0, '1', 'ERRO', @m)
        '''),
        parameters: {'t': tenantId, 'o': orderId, 'm': e.toString()},
      );
    } catch (_) {/* ignora */}
  }
}

Future<Response> _fiscalStatus(Request req, String orderId) async {
  final claims = _authClaims(req);
  if (claims == null) return _json(401, {'error': 'Token inválido.'});
  final tenantId = claims['tenant_id'].toString();
  final rows = await Db.query(
    '''
    SELECT fi.status_sefaz, fi.protocolo_autorizacao, fi.chave_acesso,
           fi.modelo, fi.link_danfe, fi.motivo_rejeicao
    FROM fiscal_invoices fi
    JOIN orders o ON o.id = fi.order_id
    WHERE o.tenant_id = @t AND o.client_order_id = @c
    ORDER BY fi.created_at DESC
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
    'modelo': rows.first['modelo'],
    'link_danfe': rows.first['link_danfe'],
    'motivo': rows.first['motivo_rejeicao'],
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
           p.unidade_medida, p.preco_venda, i.qtd_fisica, i.qtd_reservada,
           i.cota_offline
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
        'cota_offline': _toDouble(r['cota_offline']),
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
          INSERT INTO inventory (tenant_id, product_id, qtd_fisica, cota_offline)
          VALUES (@t, @p, @q, @cota)
        '''),
        parameters: {
          't': tenantId,
          'p': pid,
          'q': _toDouble(b['qtd_fisica']),
          'cota': _toDouble(b['cota_offline']),
        },
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
      if (b['qtd_fisica'] != null || b['cota_offline'] != null) {
        await tx.execute(
          Sql.named('''
            UPDATE inventory SET
              qtd_fisica = COALESCE(@q, qtd_fisica),
              cota_offline = COALESCE(@cota, cota_offline),
              updated_at = CURRENT_TIMESTAMP
            WHERE product_id = @id AND tenant_id = @t
          '''),
          parameters: {
            'q': b['qtd_fisica'] != null ? _toDouble(b['qtd_fisica']) : null,
            'cota': b['cota_offline'] != null ? _toDouble(b['cota_offline']) : null,
            'id': id,
            't': tenantId,
          },
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

/// POST /provision — cria uma empresa (tenant) + admin. Ação da PLATAFORMA,
/// protegida pela chave em PLATFORM_KEY (header X-Platform-Key).
Future<Response> _provision(Request req) async {
  final expected = Platform.environment['PLATFORM_KEY'] ?? '';
  final key = req.headers['x-platform-key'] ?? '';
  if (expected.isEmpty || key != expected) {
    return _json(403, {'error': 'Chave de plataforma inválida.'});
  }
  final b = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
  final razao = (b['razao_social'] ?? '').toString().trim();
  final cnpj = (b['cnpj'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
  final email = (b['admin_email'] ?? '').toString().trim().toLowerCase();
  final senha = (b['admin_senha'] ?? '').toString();
  if (razao.isEmpty || cnpj.isEmpty || email.isEmpty || senha.isEmpty) {
    return _json(400, {'error': 'razao_social, cnpj, admin_email e admin_senha são obrigatórios.'});
  }
  try {
    final tenantId = await Db.connection.runTx((tx) async {
      final t = await tx.execute(
        Sql.named('''
          INSERT INTO tenants (razao_social, nome_fantasia, cnpj, inscricao_estadual, uf)
          VALUES (@r, @nf, @c, @ie, @uf) RETURNING id
        '''),
        parameters: {
          'r': razao,
          'nf': (b['nome_fantasia'] ?? razao).toString(),
          'c': cnpj,
          'ie': (b['inscricao_estadual'] ?? 'ISENTO').toString(),
          'uf': (b['uf'] ?? 'SP').toString(),
        },
      );
      final tid = t.first[0].toString();
      await tx.execute(
        Sql.named('''
          INSERT INTO sellers (tenant_id, nome, email, cpf, senha_hash, role)
          VALUES (@t, 'Administrador', @e, '00000000000', @h, 'admin')
        '''),
        parameters: {'t': tid, 'e': email, 'h': Auth.hashPassword(senha)},
      );
      return tid;
    });
    return _json(201, {'status': 'created', 'tenant_id': tenantId});
  } on ServerException catch (e) {
    if (e.code == '23505') return _json(409, {'error': 'CNPJ ou e-mail já cadastrado.'});
    return _json(500, {'error': e.message});
  } catch (e) {
    return _json(500, {'error': '$e'});
  }
}

/// GET /admin/bling/connect — devolve a URL de autorização OAuth do Bling.
Future<Response> _blingConnect(Request req) async {
  final claims = _adminClaims(req);
  if (claims == null) return _json(403, {'error': 'Acesso restrito ao administrador.'});
  if (!_bling.configurado) {
    return _json(400, {'error': 'Bling não configurado no servidor (BLING_CLIENT_ID/SECRET).'});
  }
  return _json(200, {'url': _bling.authorizeUrl(claims['tenant_id'].toString())});
}

/// GET /bling/callback?code=&state= — o Bling redireciona aqui após autorizar.
Future<Response> _blingCallback(Request req) async {
  final code = req.url.queryParameters['code'] ?? '';
  final state = req.url.queryParameters['state'] ?? ''; // tenant_id
  if (code.isEmpty || state.isEmpty) {
    return Response(400, body: 'code/state ausentes');
  }
  try {
    final t = await _bling.exchangeCode(code);
    await _storeBlingTokens(state, t);
  } catch (e) {
    return Response(500, body: 'Falha ao conectar Bling: $e');
  }
  return Response.ok(
    '<html><body style="font-family:sans-serif;padding:40px">'
    '<h2>Bling conectado!</h2><p>Pode fechar esta aba e voltar ao painel.</p></body></html>',
    headers: {'content-type': 'text/html; charset=utf-8'},
  );
}

/// GET /admin/bling/status — se a empresa está conectada ao Bling.
/// GET /admin/status — fotografia do estado desta empresa, pra aba "Status"
/// do painel. Mostra empresa/CNPJ, Bling conectado, config fiscal, contagens e
/// a versão publicada do servidor (pra saber se o deploy subiu).
Future<Response> _adminStatus(Request req) async {
  final claims = _adminClaims(req);
  if (claims == null) return _json(403, {'error': 'Acesso restrito ao administrador.'});
  final tenantId = claims['tenant_id'].toString();

  final t = await Db.query(
    '''SELECT razao_social, cnpj, uf,
              (bling_access_token IS NOT NULL AND bling_access_token <> '') AS bling_ok,
              bling_natureza_operacao_id, bling_forma_pagamento_boleto_id
       FROM tenants WHERE id = @t''',
    params: {'t': tenantId},
  );
  final row = t.isNotEmpty ? t.first : const {};

  final nProdutos = await Db.query(
      'SELECT COUNT(*) AS n FROM products WHERE tenant_id = @t', params: {'t': tenantId});
  final nVendedores = await Db.query(
      "SELECT COUNT(*) AS n FROM sellers WHERE tenant_id = @t AND role = 'vendedor'",
      params: {'t': tenantId});
  final nVendas = await Db.query(
      'SELECT COUNT(*) AS n FROM orders WHERE tenant_id = @t', params: {'t': tenantId});

  final fiscalOk = row['bling_natureza_operacao_id'] != null &&
      row['bling_forma_pagamento_boleto_id'] != null;

  // De QUEM é o Bling conectado (nome + CNPJ da conta Bling), se conectado.
  String blingEmpresa = '';
  String blingCnpj = '';
  if (row['bling_ok'] == true) {
    try {
      final token = await _blingToken(tenantId);
      if (token != null) {
        final e = await _bling.dadosEmpresa(token);
        blingEmpresa = e['nome'] ?? '';
        blingCnpj = e['cnpj'] ?? '';
      }
    } catch (_) {/* não quebra o status se o Bling não responder */}
  }

  return _json(200, {
    'versao_servidor': kServerVersion,
    'empresa': row['razao_social'],
    'cnpj': row['cnpj'],
    'uf': row['uf'],
    'bling_conectado': row['bling_ok'] == true,
    'bling_empresa': blingEmpresa,
    'bling_cnpj': blingCnpj,
    'fiscal_configurado': fiscalOk,
    'qtd_produtos': nProdutos.first['n'],
    'qtd_vendedores': nVendedores.first['n'],
    'qtd_vendas': nVendas.first['n'],
  });
}

Future<Response> _blingStatus(Request req) async {
  final claims = _adminClaims(req);
  if (claims == null) return _json(403, {'error': 'Acesso restrito ao administrador.'});
  final tenantId = claims['tenant_id'].toString();
  final rows = await Db.query(
    "SELECT (bling_access_token IS NOT NULL AND bling_access_token <> '') AS conectado FROM tenants WHERE id = @t",
    params: {'t': tenantId},
  );
  final conectado = rows.isNotEmpty && rows.first['conectado'] == true;

  // De QUEM é o Bling (nome + CNPJ da conta), pra mostrar na própria linha.
  String empresa = '';
  String cnpj = '';
  if (conectado) {
    try {
      final token = await _blingToken(tenantId);
      if (token != null) {
        final e = await _bling.dadosEmpresa(token);
        empresa = e['nome'] ?? '';
        cnpj = e['cnpj'] ?? '';
      }
    } catch (_) {/* não quebra o status */}
  }

  return _json(200, {
    'configurado': _bling.configurado,
    'conectado': conectado,
    'empresa': empresa,
    'cnpj': cnpj,
  });
}

/// GET /admin/bling/fiscal-config — opções do Bling (naturezas, formas de
/// pagamento) + a configuração fiscal já salva para a empresa.
Future<Response> _blingFiscalConfig(Request req) async {
  final claims = _adminClaims(req);
  if (claims == null) return _json(403, {'error': 'Acesso restrito ao administrador.'});
  final tenantId = claims['tenant_id'].toString();
  final token = await _blingToken(tenantId);
  if (token == null) return _json(400, {'error': 'Bling não conectado para esta empresa.'});

  List<Map<String, dynamic>> naturezas = const [];
  List<Map<String, dynamic>> formas = const [];
  try {
    naturezas = await _bling.listarNaturezas(token);
    formas = await _bling.listarFormasPagamento(token);
  } catch (e) {
    return _json(502, {'error': 'Falha ao consultar o Bling: $e'});
  }

  final cfg = await Db.query(
    '''SELECT bling_natureza_operacao_id, bling_loja_id,
              bling_forma_pagamento_boleto_id
       FROM tenants WHERE id = @t''',
    params: {'t': tenantId},
  );
  final c = cfg.isNotEmpty ? cfg.first : const {};
  return _json(200, {
    'naturezas': naturezas,
    'formas_pagamento': formas,
    'config': {
      'natureza_operacao_id': c['bling_natureza_operacao_id'],
      'loja_id': c['bling_loja_id'],
      'forma_pagamento_boleto_id': c['bling_forma_pagamento_boleto_id'],
    },
  });
}

/// POST /admin/bling/fiscal-config — salva os 3 ids fiscais na empresa.
Future<Response> _blingSaveFiscalConfig(Request req) async {
  final claims = _adminClaims(req);
  if (claims == null) return _json(403, {'error': 'Acesso restrito ao administrador.'});
  final tenantId = claims['tenant_id'].toString();
  final b = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
  int? parse(dynamic v) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? null : int.tryParse(s);
  }

  await Db.connection.execute(
    Sql.named('''
      UPDATE tenants SET
        bling_natureza_operacao_id = @n,
        bling_loja_id = @l,
        bling_forma_pagamento_boleto_id = @f
      WHERE id = @t
    '''),
    parameters: {
      'n': parse(b['natureza_operacao_id']),
      'l': parse(b['loja_id']),
      'f': parse(b['forma_pagamento_boleto_id']),
      't': tenantId,
    },
  );
  return _json(200, {'status': 'saved'});
}

/// POST /admin/bling/sync — puxa produtos+estoque do Bling para o catálogo.
Future<Response> _blingSync(Request req) async {
  final claims = _adminClaims(req);
  if (claims == null) return _json(403, {'error': 'Acesso restrito ao administrador.'});
  final tenantId = claims['tenant_id'].toString();
  final token = await _blingToken(tenantId);
  if (token == null) return _json(400, {'error': 'Bling não conectado para esta empresa.'});

  List<Map<String, dynamic>> produtos;
  try {
    produtos = await _bling.getProducts(token);
  } catch (e) {
    return _json(502, {'error': 'Falha ao consultar o Bling: $e'});
  }

  var criados = 0, atualizados = 0;
  for (final p in produtos) {
    final sku = (p['sku'] ?? '').toString();
    if (sku.isEmpty) continue;
    try {
      final inserted = await Db.connection.runTx((tx) async {
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
            'ean': (p['codigo_ean'] ?? '').toString(),
            'sku': sku,
            'desc': (p['descricao'] ?? '').toString(),
            'preco': _toDouble(p['preco']),
            'ncm': (p['ncm'] ?? '00000000').toString(),
            'un': (p['unidade_medida'] ?? 'UN').toString(),
          },
        );
        final pid = up.first[0].toString();
        await tx.execute(
          Sql.named('''
            INSERT INTO inventory (tenant_id, product_id, qtd_fisica)
            VALUES (@t, @p, @q)
            ON CONFLICT (tenant_id, product_id) DO UPDATE SET
              qtd_fisica = EXCLUDED.qtd_fisica, updated_at = CURRENT_TIMESTAMP
          '''),
          parameters: {'t': tenantId, 'p': pid, 'q': _toDouble(p['qtd_fisica'])},
        );
        return up.first[1] as bool;
      });
      if (inserted) {
        criados++;
      } else {
        atualizados++;
      }
    } catch (_) {/* pula item com problema */}
  }
  return _json(200, {'total': criados + atualizados, 'criados': criados, 'atualizados': atualizados});
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
        if (senha.isNotEmpty) 'hash': Auth.hashPassword(senha),
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
        'hash': Auth.hashPassword(senha),
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
    ..get('/version', (Request req) => _json(200, {'version': kServerVersion}))
    ..get('/admin/status', _adminStatus)
    ..post('/auth/login', _login)
    ..post('/auth/change-password', _changePassword)
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
    ..get('/admin/invoices/<chave>/xml', _adminInvoiceXml)
    ..get('/admin/bling/connect', _blingConnect)
    ..get('/admin/bling/status', _blingStatus)
    ..get('/admin/bling/fiscal-config', _blingFiscalConfig)
    ..post('/admin/bling/fiscal-config', _blingSaveFiscalConfig)
    ..post('/admin/bling/sync', _blingSync)
    ..get('/bling/callback', _blingCallback)
    ..post('/provision', _provision);

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(_cors())
      .addHandler(router.call);

  final port = int.parse(Platform.environment['PORT'] ?? '3000');
  final server = await io.serve(handler, InternetAddress.anyIPv4, port);
  stdout.writeln('✓ Servidor rodando em http://localhost:${server.port}');
}
