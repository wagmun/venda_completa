import 'dart:convert';
import 'package:http/http.dart' as http;

/// Resultado de um login bem-sucedido no backend.
class LoginResult {
  final String token;
  final String tenantId;
  final String sellerId;
  final String sellerName;
  final String razaoSocial;
  final String cnpj;
  final String uf;

  LoginResult({
    required this.token,
    required this.tenantId,
    required this.sellerId,
    required this.sellerName,
    required this.razaoSocial,
    required this.cnpj,
    required this.uf,
  });
}

/// Lançada quando o servidor responde que as credenciais são inválidas (401).
class InvalidCredentialsException implements Exception {}

/// Chamadas de autenticação ao backend central.
class AuthApiService {
  final http.Client client;
  final String apiBaseUrl;

  AuthApiService({required this.client, required this.apiBaseUrl});

  /// Faz login no backend. Retorna [LoginResult] em sucesso.
  /// Lança [InvalidCredentialsException] em 401. Relança erros de rede
  /// (servidor desligado/inacessível) para o chamador decidir o fallback.
  Future<LoginResult> login(String email, String password) async {
    final res = await client.post(
      Uri.parse('$apiBaseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return LoginResult(
        token: data['access_token'].toString(),
        tenantId: data['tenant_id'].toString(),
        sellerId: (data['seller_id'] ?? '').toString(),
        sellerName: (data['seller_name'] ?? '').toString(),
        razaoSocial: (data['razao_social'] ?? data['tenant_name'] ?? '').toString(),
        cnpj: (data['cnpj'] ?? '').toString(),
        uf: (data['uf'] ?? 'SP').toString(),
      );
    } else if (res.statusCode == 401) {
      throw InvalidCredentialsException();
    } else {
      throw Exception('Erro do servidor (${res.statusCode}).');
    }
  }

  /// Troca a senha do vendedor logado. Retorna null em sucesso, ou a mensagem
  /// de erro do servidor (ex.: senha atual incorreta) para exibir ao usuário.
  Future<String?> changePassword({
    required String token,
    required String senhaAtual,
    required String senhaNova,
  }) async {
    try {
      final res = await client.post(
        Uri.parse('$apiBaseUrl/auth/change-password'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'senha_atual': senhaAtual, 'senha_nova': senhaNova}),
      );
      if (res.statusCode == 200) return null;
      try {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return (data['error'] ?? 'Erro (${res.statusCode}).').toString();
      } catch (_) {
        return 'Erro do servidor (${res.statusCode}).';
      }
    } catch (_) {
      return 'Sem conexão com o servidor.';
    }
  }
}
