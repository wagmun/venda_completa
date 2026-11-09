// Smoke test: garante que o app inicializa e exibe a tela de Login.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'package:venda_completa/core/database/app_database.dart';
import 'package:venda_completa/core/security/secure_storage_service.dart';
import 'package:venda_completa/features/auth/data/auth_api_service.dart';
import 'package:venda_completa/features/auth/data/catalog_sync_service.dart';
import 'package:venda_completa/features/auth/presentation/auth_controller.dart';
import 'package:venda_completa/features/auth/presentation/login_screen.dart';

void main() {
  testWidgets('App abre na tela de Login', (WidgetTester tester) async {
    // AppDatabase é lazy: não abre o SQLite enquanto nenhuma query roda,
    // então montar a árvore não toca o disco neste smoke test.
    final db = AppDatabase();
    final storage = SecureStorageService();
    final syncService = CatalogSyncService(
      client: http.Client(),
      db: db,
      storage: storage,
      apiBaseUrl: 'http://localhost',
    );
    final authApi = AuthApiService(client: http.Client(), apiBaseUrl: 'http://localhost');

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>(
        create: (_) => AuthController(
          authApi: authApi,
          syncService: syncService,
          storage: storage,
        ),
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Venda Completa'), findsOneWidget);
  });
}
