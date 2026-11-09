import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';

class CatalogRepository {
  final AppDatabase _db;

  CatalogRepository(this._db);

  /// Busca todos os produtos pertencentes à empresa (tenantId)
  Future<List<LocalInventoryData>> getProducts(String tenantId) async {
    return (_db.select(_db.localInventory)
      ..where((tbl) => tbl.tenantId.equals(tenantId)))
        .get();
  }

  /// Escuta em tempo real (Stream) as alterações no catálogo local
  Stream<List<LocalInventoryData>> watchProducts(String tenantId) {
    return (_db.select(_db.localInventory)
      ..where((tbl) => tbl.tenantId.equals(tenantId)))
        .watch();
  }

  /// Realiza a busca filtrada por Descrição, SKU ou Código EAN
  Future<List<LocalInventoryData>> searchProducts(String tenantId, String query) async {
    if (query.trim().isEmpty) {
      return getProducts(tenantId);
    }
    final lowerQuery = '%${query.toLowerCase()}%';
    return (_db.select(_db.localInventory)
      ..where((tbl) =>
      tbl.tenantId.equals(tenantId) &
      (tbl.descricao.lower().like(lowerQuery) |
      tbl.sku.lower().like(lowerQuery) |
      tbl.codigoEan.like('%$query%'))))
        .get();
  }

  /// Busca um produto específico pelo Código de Barras EAN exato
  Future<LocalInventoryData?> findByEan(String tenantId, String ean) async {
    return (_db.select(_db.localInventory)
      ..where((tbl) =>
      tbl.tenantId.equals(tenantId) &
      tbl.codigoEan.equals(ean)))
        .getSingleOrNull();
  }
}
