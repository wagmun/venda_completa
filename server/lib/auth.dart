import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

/// Assinatura e verificação de JWT para o backend.
/// Em produção, o segredo deve vir de variável de ambiente / secret manager.
class Auth {
  static final String _secret =
      const String.fromEnvironment('JWT_SECRET', defaultValue: 'dev-secret-venda-completa');

  /// Gera o JWT com as claims do vendedor. O tenant_id vai DENTRO do token —
  /// o app nunca informa a empresa; ela é resolvida aqui pelo cadastro.
  static String signToken({
    required String sellerId,
    required String tenantId,
    required String role,
  }) {
    final jwt = JWT({
      'sub': sellerId,
      'tenant_id': tenantId,
      'role': role,
    });
    return jwt.sign(SecretKey(_secret), expiresIn: const Duration(hours: 12));
  }

  /// Verifica o token e devolve as claims, ou null se inválido/expirado.
  static Map<String, dynamic>? verifyToken(String token) {
    try {
      final jwt = JWT.verify(token, SecretKey(_secret));
      return Map<String, dynamic>.from(jwt.payload as Map);
    } catch (_) {
      return null;
    }
  }

  /// Validação de senha no modo demo. O seed guarda o hash placeholder
  /// 'demo$<senha>'. Em produção, trocar por bcrypt/argon2.
  static bool verifyPassword(String plain, String storedHash) {
    return storedHash == 'demo\$$plain';
  }
}
