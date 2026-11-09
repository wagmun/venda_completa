import 'dart:io';
import 'package:postgres/postgres.dart';

/// Conexão única com o PostgreSQL (Postgres.app, banco venda_completa).
/// Em desenvolvimento usa auth "trust" local — sem senha.
class Db {
  static late final Connection connection;

  static Future<void> open() async {
    final username = Platform.environment['PGUSER'] ??
        Platform.environment['USER'] ??
        'postgres';

    // PGSSL=require (ou 'true') ativa TLS — necessário no Supabase/produção.
    final ssl = (Platform.environment['PGSSL'] ?? '').toLowerCase();
    final sslMode = (ssl == 'require' || ssl == 'true')
        ? SslMode.require
        : SslMode.disable;

    connection = await Connection.open(
      Endpoint(
        host: Platform.environment['PGHOST'] ?? 'localhost',
        port: int.tryParse(Platform.environment['PGPORT'] ?? '5432') ?? 5432,
        database: Platform.environment['PGDATABASE'] ?? 'venda_completa',
        username: username,
        password: Platform.environment['PGPASSWORD'],
      ),
      settings: ConnectionSettings(sslMode: sslMode),
    );
  }

  /// Executa uma query com parâmetros nomeados (@nome) e devolve as linhas
  /// como lista de mapas coluna->valor.
  static Future<List<Map<String, dynamic>>> query(
    String sql, {
    Map<String, dynamic> params = const {},
  }) async {
    final result = await connection.execute(
      Sql.named(sql),
      parameters: params,
    );
    return result.map((row) => row.toColumnMap()).toList();
  }

  static Future<void> close() async {
    await connection.close();
  }
}
