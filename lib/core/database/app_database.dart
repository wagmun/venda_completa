import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

part 'app_database.g.dart';

// Tabela de Produtos / Estoque Local (Com campos fiscais e de cota offline)
class LocalInventory extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get sku => text()();
  TextColumn get codigoEan => text()();
  TextColumn get descricao => text()();

  // Campos Fiscais para NFC-e / NF-e
  TextColumn get ncm => text().withDefault(const Constant('00000000'))();
  TextColumn get cest => text().nullable()();
  TextColumn get unidadeMedida => text().withDefault(const Constant('UN'))();

  // Gestão Tríplice de Estoque
  RealColumn get precoVenda => real()();
  RealColumn get qtdFisica => real().withDefault(const Constant(0.0))();
  RealColumn get qtdReservada => real().withDefault(const Constant(0.0))();
  RealColumn get cotaOffline => real().withDefault(const Constant(0.0))();

  @override
  Set<Column> get primaryKey => {id};
}

// Tabela da Fila de Outbox Durável
class Outbox extends Table {
  TextColumn get id => text()(); // Chave de Idempotência (UUID)
  TextColumn get tenantId => text()();
  TextColumn get eventType => text()(); // ex: 'order.created'
  TextColumn get payload => text()();   // JSON completo
  TextColumn get status => text().withDefault(const Constant('PENDENTE'))();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [LocalInventory, Outbox])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          // Os dados locais são apenas cache (os produtos vêm do servidor e a
          // Outbox é reenviada). Recria as tabelas para aplicar mudanças de
          // schema — ex.: a chave primária que faltava em bancos antigos.
          for (final table in allTables) {
            await m.deleteTable(table.actualTableName);
          }
          await m.createAll();
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'vendas_app.sqlite'));

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      return NativeDatabase.createInBackground(file);
    } else {
      return NativeDatabase.createInBackground(file);
    }
  });
}
