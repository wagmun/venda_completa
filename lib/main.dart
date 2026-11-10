import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'core/database/app_database.dart';
import 'core/network/websocket_handler.dart';
import 'core/security/secure_storage_service.dart';
import 'features/auth/data/auth_api_service.dart';
import 'features/auth/data/catalog_sync_service.dart';
import 'features/auth/presentation/auth_controller.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/catalog/data/catalog_repository.dart';
import 'features/catalog/data/catalog_seed_service.dart';
import 'features/catalog/presentation/catalog_controller.dart';
import 'features/catalog/presentation/catalog_screen.dart';
import 'features/cart/data/cart_repository.dart';
import 'features/cart/presentation/cart_controller.dart';
import 'features/sales/data/outbox_service.dart';
import 'features/sales/data/outbox_sync_manager.dart';
import 'features/sales/data/printer_service.dart';
import 'features/sales/domain/fiscal_service.dart';
import 'features/cart/presentation/cart_screen.dart';

/// URL base do backend central (Fonte Única da Verdade).
/// macOS/desktop/web local: localhost. Emulador Android: http://10.0.2.2:3000.
/// Aparelho físico: http://<IP-do-Mac>:3000. Produção: domínio do servidor.
const String kApiBaseUrl = 'https://venda-completa-api.onrender.com';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Infraestrutura compartilhada (instância única por app).
  final db = AppDatabase();
  final storage = SecureStorageService();
  final httpClient = http.Client();

  // Serviços e repositórios que dependem da infraestrutura.
  final authApi = AuthApiService(
    client: httpClient,
    apiBaseUrl: kApiBaseUrl,
  );
  final webSocketHandler = WebSocketHandler(
    db: db,
    storage: storage,
    wsBaseUrl: kApiBaseUrl.replaceFirst('http', 'ws'),
  );
  final catalogSync = CatalogSyncService(
    client: httpClient,
    db: db,
    storage: storage,
    apiBaseUrl: kApiBaseUrl,
  );
  final catalogRepository = CatalogRepository(db);
  final catalogSeed = CatalogSeedService(db);
  final cartRepository = CartRepository(db);
  final outboxService = OutboxService(
    db: db,
    client: httpClient,
    storage: storage,
    apiBaseUrl: kApiBaseUrl,
  );
  // Replay automático da Outbox: início + reconexão + timer periódico.
  OutboxSyncManager(outboxService: outboxService).start();
  final fiscalService = FiscalService(storage);
  final printerService = ThermalPrinterService();

  runApp(
    MultiProvider(
      providers: [
        // Infraestrutura exposta para quem precisar.
        Provider<AppDatabase>.value(value: db),
        Provider<SecureStorageService>.value(value: storage),

        // Controllers das fatias (ChangeNotifier reativo via Provider).
        ChangeNotifierProvider<AuthController>(
          create: (_) => AuthController(
            authApi: authApi,
            syncService: catalogSync,
            storage: storage,
            seedService: catalogSeed,
            webSocketHandler: webSocketHandler,
          ),
        ),
        ChangeNotifierProvider<CatalogController>(
          create: (_) => CatalogController(
            repository: catalogRepository,
            storage: storage,
            syncService: catalogSync,
          ),
        ),
        ChangeNotifierProvider<CartController>(
          create: (_) => CartController(
            cartRepository: cartRepository,
            storage: storage,
            outboxService: outboxService,
            fiscalService: fiscalService,
            printerService: printerService,
          ),
        ),
      ],
      child: const VendaCompletaApp(),
    ),
  );
}

class VendaCompletaApp extends StatelessWidget {
  const VendaCompletaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Venda Completa',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (_) => const LoginScreen(),
        '/catalog': (_) => const CatalogScreen(),
        '/cart': (_) => const CartScreen(),
      },
    );
  }
}
