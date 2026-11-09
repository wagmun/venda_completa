import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:venda_completa/core/database/app_database.dart';
import 'package:venda_completa/features/cart/domain/cart_item.dart';

class CartRepository {
  final AppDatabase _db;

  CartRepository(this._db);

  /// Executa o Checkout em uma Transação Atômica no SQLite:
  /// 1. Abate a quantidade comprada da `qtdFisica` do estoque local.
  /// 2. Registra o pedido na fila durável da `Outbox` para sincronização futura.
  /// Efetiva a venda localmente. Retorna o `orderId` em sucesso, ou null.
  Future<String?> processCheckout({
    required String tenantId,
    required List<CartItem> items,
    required double totalAmount,
    required String paymentMethod,
    Map<String, dynamic>? fiscal,
  }) async {
    if (items.isEmpty) return null;

    final orderId = 'ORD-${DateTime.now().millisecondsSinceEpoch}';

    final orderPayload = jsonEncode({
      'order_id': orderId,
      'tenant_id': tenantId,
      'created_at': DateTime.now().toIso8601String(),
      'payment_method': paymentMethod,
      'total_amount': totalAmount,
      'items': items.map((item) => item.toJson()).toList(),
      if (fiscal != null) 'fiscal': fiscal,
    });

    try {
      await _db.transaction(() async {
        // 1. Abate o estoque físico de cada produto no SQLite local
        for (final item in items) {
          final product = await (_db.select(_db.localInventory)
            ..where((tbl) => tbl.id.equals(item.product.id)))
              .getSingle();

          final novaQtdFisica = product.qtdFisica - item.quantity;

          await (_db.update(_db.localInventory)
            ..where((tbl) => tbl.id.equals(item.product.id)))
              .write(
            LocalInventoryCompanion(
              qtdFisica: Value(novaQtdFisica),
            ),
          );
        }

        // 2. Insere o pedido como evento durável na Outbox
        await _db.into(_db.outbox).insert(
          OutboxCompanion.insert(
            id: orderId,
            tenantId: tenantId,
            eventType: 'order.created',
            payload: orderPayload,
            status: const Value('PENDENTE'),
          ),
        );
      });
      return orderId;
    } catch (e) {
      return null;
    }
  }
}
