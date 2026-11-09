import 'dart:async';
import 'package:flutter/material.dart';
import '../data/catalog_repository.dart';
import '../../auth/data/catalog_sync_service.dart';
import '../../../core/database/app_database.dart';
import '../../../core/security/secure_storage_service.dart';

class CatalogController extends ChangeNotifier {
  final CatalogRepository _repository;
  final SecureStorageService _storage;

  List<LocalInventoryData> _products = [];
  bool _isLoading = false;
  StreamSubscription<List<LocalInventoryData>>? _watchSub;

  List<LocalInventoryData> get products => _products;
  bool get isLoading => _isLoading;

  final CatalogSyncService? _syncService;

  CatalogController({
    required CatalogRepository repository,
    required SecureStorageService storage,
    CatalogSyncService? syncService,
  })  : _repository = repository,
        _storage = storage,
        _syncService = syncService;

  /// Rebaixa o catálogo do servidor (produtos novos/alterados pelo painel).
  /// A lista é reativa (watch), então atualiza sozinha após gravar no SQLite.
  Future<bool> refreshFromServer() async {
    if (_syncService == null) return false;
    try {
      return await _syncService.executeInitialCatalogPull();
    } catch (_) {
      return false;
    }
  }

  /// Assina o catálogo local de forma reativa: qualquer alteração no estoque
  /// (venda local ou evento WebSocket de outro vendedor) reflete na hora.
  Future<void> loadProducts() async {
    _isLoading = true;
    notifyListeners();

    final tenantId = await _storage.getTenantId() ?? '';
    await _watchSub?.cancel();
    _watchSub = _repository.watchProducts(tenantId).listen((products) {
      _products = products;
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> searchProducts(String query) async {
    if (query.trim().isEmpty) {
      await loadProducts();
      return;
    }
    // Durante a busca filtrada, pausa a assinatura reativa.
    await _watchSub?.cancel();
    _watchSub = null;

    _isLoading = true;
    notifyListeners();

    final tenantId = await _storage.getTenantId() ?? '';
    _products = await _repository.searchProducts(tenantId, query);

    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _watchSub?.cancel();
    super.dispose();
  }

  Future<LocalInventoryData?> findByEan(String ean) async {
    final tenantId = await _storage.getTenantId() ?? '';
    return await _repository.findByEan(tenantId, ean);
  }

  Stream<List<LocalInventoryData>> watchProducts(String tenantId) {
    return _repository.watchProducts(tenantId);
  }
}
