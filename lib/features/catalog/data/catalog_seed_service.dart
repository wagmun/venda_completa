import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';
import 'demo_catalog_data.dart';

/// Popula o catálogo local (SQLite) com produtos de exemplo quando ainda não
/// há dados para o tenant. Usado no modo demonstração offline, permitindo
/// operar o app sem depender do backend central.
class CatalogSeedService {
  final AppDatabase db;

  CatalogSeedService(this.db);

  /// Garante que o tenant tenha catálogo local. Se já existir ao menos um
  /// produto, não faz nada. Retorna true quando há catálogo disponível.
  Future<bool> seedIfEmpty(String tenantId) async {
    final existing = await (db.select(db.localInventory)
          ..where((t) => t.tenantId.equals(tenantId))
          ..limit(1))
        .get();
    if (existing.isNotEmpty) return true;

    final catalogo = demoCatalogFor(tenantId);
    final samples =
        catalogo.map((p) => _toCompanion(tenantId, p)).toList();

    await db.batch((b) => b.insertAllOnConflictUpdate(db.localInventory, samples));
    return true;
  }

  LocalInventoryCompanion _toCompanion(String tenantId, DemoProduct p) {
    return LocalInventoryCompanion.insert(
      id: '$tenantId-${p.sku}',
      tenantId: tenantId,
      sku: p.sku,
      codigoEan: p.ean,
      descricao: p.descricao,
      precoVenda: p.preco,
      ncm: Value(p.ncm),
      qtdFisica: Value(p.estoque),
    );
  }
}
