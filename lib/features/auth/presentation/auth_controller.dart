import 'package:flutter/material.dart';
import '../data/auth_api_service.dart';
import '../data/catalog_sync_service.dart';
import '../../../core/network/websocket_handler.dart';
import '../../../core/security/secure_storage_service.dart';
import '../../catalog/data/catalog_seed_service.dart';

enum AuthStatus { initial, loading, authenticated, error }

/// Define os estados da autenticação
class AuthState {
  final AuthStatus status;
  final String? errorMessage;
  final String? tenantId;

  const AuthState({
    this.status = AuthStatus.initial,
    this.errorMessage,
    this.tenantId,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? errorMessage,
    String? tenantId,
  }) {
    return AuthState(
      status: status ?? this.status,
      errorMessage: errorMessage,
      tenantId: tenantId ?? this.tenantId,
    );
  }
}

/// Controller responsável pelo Login e Carga Inicial do Catálogo
class AuthController extends ChangeNotifier {
  final AuthApiService _authApi;
  final CatalogSyncService _syncService;
  final SecureStorageService _storage;
  final CatalogSeedService? _seedService;
  final WebSocketHandler? _webSocketHandler;

  AuthState _state = const AuthState();
  AuthState get state => _state;

  AuthController({
    required AuthApiService authApi,
    required CatalogSyncService syncService,
    required SecureStorageService storage,
    CatalogSeedService? seedService,
    WebSocketHandler? webSocketHandler,
  })  : _authApi = authApi,
        _syncService = syncService,
        _storage = storage,
        _seedService = seedService,
        _webSocketHandler = webSocketHandler;

  Future<void> login({
    required String email,
    required String password,
  }) async {
    _state = _state.copyWith(status: AuthStatus.loading, errorMessage: null);
    notifyListeners();

    try {
      // 1) Tenta o login REAL no servidor. É ele quem descobre a empresa do
      //    vendedor (pelo cadastro) e devolve o tenant_id dentro do JWT — o
      //    vendedor nunca informa a empresa.
      String? tenantId;
      String token = '';
      bool fromServer = false;

      try {
        final result = await _authApi.login(email, password);
        tenantId = result.tenantId;
        token = result.token;
        fromServer = true;
        // Guarda os dados fiscais da empresa (para emitir a NFC-e no app).
        await _storage.saveEmpresaFiscal(
          razaoSocial: result.razaoSocial,
          cnpj: result.cnpj,
          uf: result.uf,
        );
      } on InvalidCredentialsException {
        // Servidor respondeu: credenciais erradas. Não há fallback aqui.
        _state = _state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'E-mail ou senha inválidos.',
        );
        notifyListeners();
        return;
      } catch (_) {
        // Servidor desligado/inacessível → cai no modo demonstração offline,
        // simulando o cadastro usuário→empresa localmente.
        fromServer = false;
      }

      if (!fromServer) {
        tenantId = _resolveTenantId(email);
        token = 'token_demo_offline';
      }

      // Salva sessão (JWT real ou token demo) e o tenant resolvido.
      await _storage.saveToken(token);
      await _storage.saveTenantId(tenantId!);

      // 2) Carga inicial do catálogo. Com servidor, puxa do backend
      //    (/sync/catalog). Sem servidor, popula o catálogo demo local.
      bool success = false;
      try {
        success = await _syncService.executeInitialCatalogPull();
      } catch (_) {
        success = false;
      }

      if (!success && _seedService != null) {
        success = await _seedService.seedIfEmpty(tenantId);
      }

      if (success) {
        _state = _state.copyWith(status: AuthStatus.authenticated, tenantId: tenantId);
        // Abre o canal de tempo real (broadcast de estoque da empresa).
        _webSocketHandler?.connect();
      } else {
        _state = _state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'Falha ao realizar a carga inicial do catálogo.',
        );
      }
    } catch (e) {
      _state = _state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Erro na autenticação: ${e.toString()}',
      );
    }
    notifyListeners();
  }

  /// Diretório de usuários DEMO: simula o cadastro do servidor que vincula
  /// cada vendedor à sua empresa. Note que o vínculo é por USUÁRIO, não pelo
  /// domínio do e-mail — dois vendedores da mesma empresa podem ter e-mails
  /// de domínios diferentes. Em produção isto vive no backend.
  static const Map<String, String> _demoUserDirectory = {
    'joao@autopecas.com': 'empresa_autopecas',
    'maria@gmail.com': 'empresa_autopecas',
    'ana@oficinaboa.com': 'empresa_oficina_boa',
  };

  /// Resolve a empresa (tenant) do vendedor a partir do cadastro. No modo
  /// demonstração consulta o diretório fixo; e-mails não cadastrados caem numa
  /// empresa demo padrão. Em produção, substituído pelo tenant_id do JWT.
  String _resolveTenantId(String email) {
    final normalized = email.trim().toLowerCase();
    return _demoUserDirectory[normalized] ?? 'empresa_demo';
  }
}
