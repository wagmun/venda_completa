import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Backend de chave-valor.
abstract class _KvStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> clearAll();
}

/// Mobile (Android/iOS): keychain/keystore seguro, sem prompt.
class _SecureStore implements _KvStore {
  static const _s = FlutterSecureStorage();
  @override
  Future<String?> read(String key) => _s.read(key: key);
  @override
  Future<void> write(String key, String value) => _s.write(key: key, value: value);
  @override
  Future<void> clearAll() => _s.deleteAll();
}

/// Desktop (macOS/Windows/Linux): SharedPreferences — evita o prompt de senha
/// do keychain do macOS em app de desenvolvimento não assinado.
class _PrefsStore implements _KvStore {
  Future<SharedPreferences> get _p => SharedPreferences.getInstance();
  @override
  Future<String?> read(String key) async => (await _p).getString(key);
  @override
  Future<void> write(String key, String value) async => (await _p).setString(key, value);
  @override
  Future<void> clearAll() async {
    final p = await _p;
    for (final k in SecureStorageService.allKeys) {
      await p.remove(k);
    }
  }
}

/// Armazenamento de credenciais/sessão e dados fiscais do dispositivo.
/// No desktop usa SharedPreferences; no mobile usa armazenamento seguro.
class SecureStorageService {
  final _KvStore _store;

  SecureStorageService({_KvStore? store}) : _store = store ?? _defaultStore();

  static _KvStore _defaultStore() {
    if (Platform.isAndroid || Platform.isIOS) return _SecureStore();
    return _PrefsStore();
  }

  static const String _keyToken = 'auth_token';
  static const String _keyTenantId = 'tenant_id';
  static const String _keyRazao = 'empresa_razao';
  static const String _keyCnpj = 'empresa_cnpj';
  static const String _keyUf = 'empresa_uf';
  static const String _keyNfceNumero = 'nfce_proximo_numero';

  static const List<String> allKeys = [
    _keyToken, _keyTenantId, _keyRazao, _keyCnpj, _keyUf, _keyNfceNumero,
  ];

  Future<void> saveToken(String token) => _store.write(_keyToken, token);
  Future<String?> getToken() => _store.read(_keyToken);

  Future<void> saveTenantId(String tenantId) => _store.write(_keyTenantId, tenantId);
  Future<String?> getTenantId() => _store.read(_keyTenantId);

  Future<void> saveEmpresaFiscal({
    required String razaoSocial,
    required String cnpj,
    required String uf,
  }) async {
    await _store.write(_keyRazao, razaoSocial);
    await _store.write(_keyCnpj, cnpj);
    await _store.write(_keyUf, uf);
  }

  Future<String?> getRazaoSocial() => _store.read(_keyRazao);
  Future<String?> getCnpj() => _store.read(_keyCnpj);
  Future<String?> getUf() => _store.read(_keyUf);

  /// Espia o próximo número de NFC-e SEM consumir (para a pré-visualização).
  Future<int> peekNfceNumero() async {
    final atual = int.tryParse(await _store.read(_keyNfceNumero) ?? '0') ?? 0;
    return atual + 1;
  }

  /// Confirma o consumo do número (só ao efetivar a venda).
  Future<void> commitNfceNumero(int numero) =>
      _store.write(_keyNfceNumero, numero.toString());

  /// Encerra a sessão: remove token, empresa e dados fiscais, mas preserva o
  /// próximo número de NFC-e (continuidade da numeração do dispositivo).
  Future<void> clearSession() async {
    await _store.write(_keyToken, '');
    await _store.write(_keyTenantId, '');
    await _store.write(_keyRazao, '');
    await _store.write(_keyCnpj, '');
    await _store.write(_keyUf, '');
  }

  Future<void> clearAll() => _store.clearAll();
}
