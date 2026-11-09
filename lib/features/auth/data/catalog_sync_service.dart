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

      // Converte o payload JSON para objetos de tabela do Drift (com campos fiscais e de estoque)
      final items = jsonList.map((json) {
        return LocalInventoryCompanion(
          id: Value(json['id'].toString()),
          tenantId: Value(tenantId),
          sku: Value(json['sku'] ?? ''),
          codigoEan: Value(json['codigo_ean'] ?? json['codigoEan'] ?? ''),
          descricao: Value(json['descricao'] ?? ''),
          ncm: Value(json['ncm'] ?? '00000000'),
          cest: Value(json['cest']?.toString()),
          unidadeMedida: Value(json['unidade_medida'] ?? json['unidadeMedida'] ?? 'UN'),
          precoVenda: Value((json['preco_venda'] as num).toDouble()),
          qtdFisica: Value((json['qtd_fisica'] as num?)?.toDouble() ?? (json['qtd_disponivel'] as num?)?.toDouble() ?? 0.0),
          qtdReservada: Value((json['qtd_reservada'] as num?)?.toDouble() ?? 0.0),
          cotaOffline: Value((json['cota_offline'] as num?)?.toDouble() ?? 0.0),
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
