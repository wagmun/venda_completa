import 'package:bcrypt/bcrypt.dart';
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

  /// Verifica a senha. Suporta hash bcrypt (produção) e o esquema legado
  /// 'demo$<senha>' (seed/dados antigos), para não quebrar logins existentes.
  static bool verifyPassword(String plain, String storedHash) {
    if (storedHash.startsWith(r'$2')) {
      try {
        return BCrypt.checkpw(plain, storedHash);
      } catch (_) {
        return false;
      }
    }
    return storedHash == 'demo\$$plain';
  }

  /// Gera o hash bcrypt de uma senha (para novos cadastros).
  static String hashPassword(String plain) =>
      BCrypt.hashpw(plain, BCrypt.gensalt());
}
