// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $LocalInventoryTable extends LocalInventory
    with TableInfo<$LocalInventoryTable, LocalInventoryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalInventoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _tenantIdMeta =
      const VerificationMeta('tenantId');
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
      'tenant_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _skuMeta = const VerificationMeta('sku');
  @override
  late final GeneratedColumn<String> sku = GeneratedColumn<String>(
      'sku', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _codigoEanMeta =
      const VerificationMeta('codigoEan');
  @override
  late final GeneratedColumn<String> codigoEan = GeneratedColumn<String>(
      'codigo_ean', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descricaoMeta =
      const VerificationMeta('descricao');
  @override
  late final GeneratedColumn<String> descricao = GeneratedColumn<String>(
      'descricao', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _ncmMeta = const VerificationMeta('ncm');
  @override
  late final GeneratedColumn<String> ncm = GeneratedColumn<String>(
      'ncm', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('00000000'));
  static const VerificationMeta _cestMeta = const VerificationMeta('cest');
  @override
  late final GeneratedColumn<String> cest = GeneratedColumn<String>(
      'cest', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _unidadeMedidaMeta =
      const VerificationMeta('unidadeMedida');
  @override
  late final GeneratedColumn<String> unidadeMedida = GeneratedColumn<String>(
      'unidade_medida', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('UN'));
  static const VerificationMeta _precoVendaMeta =
      const VerificationMeta('precoVenda');
  @override
  late final GeneratedColumn<double> precoVenda = GeneratedColumn<double>(
      'preco_venda', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _qtdFisicaMeta =
      const VerificationMeta('qtdFisica');
  @override
  late final GeneratedColumn<double> qtdFisica = GeneratedColumn<double>(
      'qtd_fisica', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _qtdReservadaMeta =
      const VerificationMeta('qtdReservada');
  @override
  late final GeneratedColumn<double> qtdReservada = GeneratedColumn<double>(
      'qtd_reservada', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _cotaOfflineMeta =
      const VerificationMeta('cotaOffline');
  @override
  late final GeneratedColumn<double> cotaOffline = GeneratedColumn<double>(
      'cota_offline', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        tenantId,
        sku,
        codigoEan,
        descricao,
        ncm,
        cest,
        unidadeMedida,
        precoVenda,
        qtdFisica,
        qtdReservada,
        cotaOffline
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_inventory';
  @override
  VerificationContext validateIntegrity(Insertable<LocalInventoryData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tenant_id')) {
      context.handle(_tenantIdMeta,
          tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta));
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('sku')) {
      context.handle(
          _skuMeta, sku.isAcceptableOrUnknown(data['sku']!, _skuMeta));
    } else if (isInserting) {
      context.missing(_skuMeta);
    }
    if (data.containsKey('codigo_ean')) {
      context.handle(_codigoEanMeta,
          codigoEan.isAcceptableOrUnknown(data['codigo_ean']!, _codigoEanMeta));
    } else if (isInserting) {
      context.missing(_codigoEanMeta);
    }
    if (data.containsKey('descricao')) {
      context.handle(_descricaoMeta,
          descricao.isAcceptableOrUnknown(data['descricao']!, _descricaoMeta));
    } else if (isInserting) {
      context.missing(_descricaoMeta);
    }
    if (data.containsKey('ncm')) {
      context.handle(
          _ncmMeta, ncm.isAcceptableOrUnknown(data['ncm']!, _ncmMeta));
    }
    if (data.containsKey('cest')) {
      context.handle(
          _cestMeta, cest.isAcceptableOrUnknown(data['cest']!, _cestMeta));
    }
    if (data.containsKey('unidade_medida')) {
      context.handle(
          _unidadeMedidaMeta,
          unidadeMedida.isAcceptableOrUnknown(
              data['unidade_medida']!, _unidadeMedidaMeta));
    }
    if (data.containsKey('preco_venda')) {
      context.handle(
          _precoVendaMeta,
          precoVenda.isAcceptableOrUnknown(
              data['preco_venda']!, _precoVendaMeta));
    } else if (isInserting) {
      context.missing(_precoVendaMeta);
    }
    if (data.containsKey('qtd_fisica')) {
      context.handle(_qtdFisicaMeta,
          qtdFisica.isAcceptableOrUnknown(data['qtd_fisica']!, _qtdFisicaMeta));
    }
    if (data.containsKey('qtd_reservada')) {
      context.handle(
          _qtdReservadaMeta,
          qtdReservada.isAcceptableOrUnknown(
              data['qtd_reservada']!, _qtdReservadaMeta));
    }
    if (data.containsKey('cota_offline')) {
      context.handle(
          _cotaOfflineMeta,
          cotaOffline.isAcceptableOrUnknown(
              data['cota_offline']!, _cotaOfflineMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalInventoryData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalInventoryData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      tenantId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tenant_id'])!,
      sku: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sku'])!,
      codigoEan: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}codigo_ean'])!,
      descricao: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}descricao'])!,
      ncm: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}ncm'])!,
      cest: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cest']),
      unidadeMedida: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}unidade_medida'])!,
      precoVenda: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}preco_venda'])!,
      qtdFisica: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}qtd_fisica'])!,
      qtdReservada: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}qtd_reservada'])!,
      cotaOffline: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}cota_offline'])!,
    );
  }

  @override
  $LocalInventoryTable createAlias(String alias) {
    return $LocalInventoryTable(attachedDatabase, alias);
  }
}

class LocalInventoryData extends DataClass
    implements Insertable<LocalInventoryData> {
  final String id;
  final String tenantId;
  final String sku;
  final String codigoEan;
  final String descricao;
  final String ncm;
  final String? cest;
  final String unidadeMedida;
  final double precoVenda;
  final double qtdFisica;
  final double qtdReservada;
  final double cotaOffline;
  const LocalInventoryData(
      {required this.id,
      required this.tenantId,
      required this.sku,
      required this.codigoEan,
      required this.descricao,
      required this.ncm,
      this.cest,
      required this.unidadeMedida,
      required this.precoVenda,
      required this.qtdFisica,
      required this.qtdReservada,
      required this.cotaOffline});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tenant_id'] = Variable<String>(tenantId);
    map['sku'] = Variable<String>(sku);
    map['codigo_ean'] = Variable<String>(codigoEan);
    map['descricao'] = Variable<String>(descricao);
    map['ncm'] = Variable<String>(ncm);
    if (!nullToAbsent || cest != null) {
      map['cest'] = Variable<String>(cest);
    }
    map['unidade_medida'] = Variable<String>(unidadeMedida);
    map['preco_venda'] = Variable<double>(precoVenda);
    map['qtd_fisica'] = Variable<double>(qtdFisica);
    map['qtd_reservada'] = Variable<double>(qtdReservada);
    map['cota_offline'] = Variable<double>(cotaOffline);
    return map;
  }

  LocalInventoryCompanion toCompanion(bool nullToAbsent) {
    return LocalInventoryCompanion(
      id: Value(id),
      tenantId: Value(tenantId),
      sku: Value(sku),
      codigoEan: Value(codigoEan),
      descricao: Value(descricao),
      ncm: Value(ncm),
      cest: cest == null && nullToAbsent ? const Value.absent() : Value(cest),
      unidadeMedida: Value(unidadeMedida),
      precoVenda: Value(precoVenda),
      qtdFisica: Value(qtdFisica),
      qtdReservada: Value(qtdReservada),
      cotaOffline: Value(cotaOffline),
    );
  }

  factory LocalInventoryData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalInventoryData(
      id: serializer.fromJson<String>(json['id']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      sku: serializer.fromJson<String>(json['sku']),
      codigoEan: serializer.fromJson<String>(json['codigoEan']),
      descricao: serializer.fromJson<String>(json['descricao']),
      ncm: serializer.fromJson<String>(json['ncm']),
      cest: serializer.fromJson<String?>(json['cest']),
      unidadeMedida: serializer.fromJson<String>(json['unidadeMedida']),
      precoVenda: serializer.fromJson<double>(json['precoVenda']),
      qtdFisica: serializer.fromJson<double>(json['qtdFisica']),
      qtdReservada: serializer.fromJson<double>(json['qtdReservada']),
      cotaOffline: serializer.fromJson<double>(json['cotaOffline']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tenantId': serializer.toJson<String>(tenantId),
      'sku': serializer.toJson<String>(sku),
      'codigoEan': serializer.toJson<String>(codigoEan),
      'descricao': serializer.toJson<String>(descricao),
      'ncm': serializer.toJson<String>(ncm),
      'cest': serializer.toJson<String?>(cest),
      'unidadeMedida': serializer.toJson<String>(unidadeMedida),
      'precoVenda': serializer.toJson<double>(precoVenda),
      'qtdFisica': serializer.toJson<double>(qtdFisica),
      'qtdReservada': serializer.toJson<double>(qtdReservada),
      'cotaOffline': serializer.toJson<double>(cotaOffline),
    };
  }

  LocalInventoryData copyWith(
          {String? id,
          String? tenantId,
          String? sku,
          String? codigoEan,
          String? descricao,
          String? ncm,
          Value<String?> cest = const Value.absent(),
          String? unidadeMedida,
          double? precoVenda,
          double? qtdFisica,
          double? qtdReservada,
          double? cotaOffline}) =>
      LocalInventoryData(
        id: id ?? this.id,
        tenantId: tenantId ?? this.tenantId,
        sku: sku ?? this.sku,
        codigoEan: codigoEan ?? this.codigoEan,
        descricao: descricao ?? this.descricao,
        ncm: ncm ?? this.ncm,
        cest: cest.present ? cest.value : this.cest,
        unidadeMedida: unidadeMedida ?? this.unidadeMedida,
        precoVenda: precoVenda ?? this.precoVenda,
        qtdFisica: qtdFisica ?? this.qtdFisica,
        qtdReservada: qtdReservada ?? this.qtdReservada,
        cotaOffline: cotaOffline ?? this.cotaOffline,
      );
  LocalInventoryData copyWithCompanion(LocalInventoryCompanion data) {
    return LocalInventoryData(
      id: data.id.present ? data.id.value : this.id,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      sku: data.sku.present ? data.sku.value : this.sku,
      codigoEan: data.codigoEan.present ? data.codigoEan.value : this.codigoEan,
      descricao: data.descricao.present ? data.descricao.value : this.descricao,
      ncm: data.ncm.present ? data.ncm.value : this.ncm,
      cest: data.cest.present ? data.cest.value : this.cest,
      unidadeMedida: data.unidadeMedida.present
          ? data.unidadeMedida.value
          : this.unidadeMedida,
      precoVenda:
          data.precoVenda.present ? data.precoVenda.value : this.precoVenda,
      qtdFisica: data.qtdFisica.present ? data.qtdFisica.value : this.qtdFisica,
      qtdReservada: data.qtdReservada.present
          ? data.qtdReservada.value
          : this.qtdReservada,
      cotaOffline:
          data.cotaOffline.present ? data.cotaOffline.value : this.cotaOffline,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalInventoryData(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('sku: $sku, ')
          ..write('codigoEan: $codigoEan, ')
          ..write('descricao: $descricao, ')
          ..write('ncm: $ncm, ')
          ..write('cest: $cest, ')
          ..write('unidadeMedida: $unidadeMedida, ')
          ..write('precoVenda: $precoVenda, ')
          ..write('qtdFisica: $qtdFisica, ')
          ..write('qtdReservada: $qtdReservada, ')
          ..write('cotaOffline: $cotaOffline')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, tenantId, sku, codigoEan, descricao, ncm,
      cest, unidadeMedida, precoVenda, qtdFisica, qtdReservada, cotaOffline);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalInventoryData &&
          other.id == this.id &&
          other.tenantId == this.tenantId &&
          other.sku == this.sku &&
          other.codigoEan == this.codigoEan &&
          other.descricao == this.descricao &&
          other.ncm == this.ncm &&
          other.cest == this.cest &&
          other.unidadeMedida == this.unidadeMedida &&
          other.precoVenda == this.precoVenda &&
          other.qtdFisica == this.qtdFisica &&
          other.qtdReservada == this.qtdReservada &&
          other.cotaOffline == this.cotaOffline);
}

class LocalInventoryCompanion extends UpdateCompanion<LocalInventoryData> {
  final Value<String> id;
  final Value<String> tenantId;
  final Value<String> sku;
  final Value<String> codigoEan;
  final Value<String> descricao;
  final Value<String> ncm;
  final Value<String?> cest;
  final Value<String> unidadeMedida;
  final Value<double> precoVenda;
  final Value<double> qtdFisica;
  final Value<double> qtdReservada;
  final Value<double> cotaOffline;
  final Value<int> rowid;
  const LocalInventoryCompanion({
    this.id = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.sku = const Value.absent(),
    this.codigoEan = const Value.absent(),
    this.descricao = const Value.absent(),
    this.ncm = const Value.absent(),
    this.cest = const Value.absent(),
    this.unidadeMedida = const Value.absent(),
    this.precoVenda = const Value.absent(),
    this.qtdFisica = const Value.absent(),
    this.qtdReservada = const Value.absent(),
    this.cotaOffline = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalInventoryCompanion.insert({
    required String id,
    required String tenantId,
    required String sku,
    required String codigoEan,
    required String descricao,
    this.ncm = const Value.absent(),
    this.cest = const Value.absent(),
    this.unidadeMedida = const Value.absent(),
    required double precoVenda,
    this.qtdFisica = const Value.absent(),
    this.qtdReservada = const Value.absent(),
    this.cotaOffline = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        tenantId = Value(tenantId),
        sku = Value(sku),
        codigoEan = Value(codigoEan),
        descricao = Value(descricao),
        precoVenda = Value(precoVenda);
  static Insertable<LocalInventoryData> custom({
    Expression<String>? id,
    Expression<String>? tenantId,
    Expression<String>? sku,
    Expression<String>? codigoEan,
    Expression<String>? descricao,
    Expression<String>? ncm,
    Expression<String>? cest,
    Expression<String>? unidadeMedida,
    Expression<double>? precoVenda,
    Expression<double>? qtdFisica,
    Expression<double>? qtdReservada,
    Expression<double>? cotaOffline,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tenantId != null) 'tenant_id': tenantId,
      if (sku != null) 'sku': sku,
      if (codigoEan != null) 'codigo_ean': codigoEan,
      if (descricao != null) 'descricao': descricao,
      if (ncm != null) 'ncm': ncm,
      if (cest != null) 'cest': cest,
      if (unidadeMedida != null) 'unidade_medida': unidadeMedida,
      if (precoVenda != null) 'preco_venda': precoVenda,
      if (qtdFisica != null) 'qtd_fisica': qtdFisica,
      if (qtdReservada != null) 'qtd_reservada': qtdReservada,
      if (cotaOffline != null) 'cota_offline': cotaOffline,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalInventoryCompanion copyWith(
      {Value<String>? id,
      Value<String>? tenantId,
      Value<String>? sku,
      Value<String>? codigoEan,
      Value<String>? descricao,
      Value<String>? ncm,
      Value<String?>? cest,
      Value<String>? unidadeMedida,
      Value<double>? precoVenda,
      Value<double>? qtdFisica,
      Value<double>? qtdReservada,
      Value<double>? cotaOffline,
      Value<int>? rowid}) {
    return LocalInventoryCompanion(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      sku: sku ?? this.sku,
      codigoEan: codigoEan ?? this.codigoEan,
      descricao: descricao ?? this.descricao,
      ncm: ncm ?? this.ncm,
      cest: cest ?? this.cest,
      unidadeMedida: unidadeMedida ?? this.unidadeMedida,
      precoVenda: precoVenda ?? this.precoVenda,
      qtdFisica: qtdFisica ?? this.qtdFisica,
      qtdReservada: qtdReservada ?? this.qtdReservada,
      cotaOffline: cotaOffline ?? this.cotaOffline,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (sku.present) {
      map['sku'] = Variable<String>(sku.value);
    }
    if (codigoEan.present) {
      map['codigo_ean'] = Variable<String>(codigoEan.value);
    }
    if (descricao.present) {
      map['descricao'] = Variable<String>(descricao.value);
    }
    if (ncm.present) {
      map['ncm'] = Variable<String>(ncm.value);
    }
    if (cest.present) {
      map['cest'] = Variable<String>(cest.value);
    }
    if (unidadeMedida.present) {
      map['unidade_medida'] = Variable<String>(unidadeMedida.value);
    }
    if (precoVenda.present) {
      map['preco_venda'] = Variable<double>(precoVenda.value);
    }
    if (qtdFisica.present) {
      map['qtd_fisica'] = Variable<double>(qtdFisica.value);
    }
    if (qtdReservada.present) {
      map['qtd_reservada'] = Variable<double>(qtdReservada.value);
    }
    if (cotaOffline.present) {
      map['cota_offline'] = Variable<double>(cotaOffline.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalInventoryCompanion(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('sku: $sku, ')
          ..write('codigoEan: $codigoEan, ')
          ..write('descricao: $descricao, ')
          ..write('ncm: $ncm, ')
          ..write('cest: $cest, ')
          ..write('unidadeMedida: $unidadeMedida, ')
          ..write('precoVenda: $precoVenda, ')
          ..write('qtdFisica: $qtdFisica, ')
          ..write('qtdReservada: $qtdReservada, ')
          ..write('cotaOffline: $cotaOffline, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxTable extends Outbox with TableInfo<$OutboxTable, OutboxData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _tenantIdMeta =
      const VerificationMeta('tenantId');
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
      'tenant_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _eventTypeMeta =
      const VerificationMeta('eventType');
  @override
  late final GeneratedColumn<String> eventType = GeneratedColumn<String>(
      'event_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _payloadMeta =
      const VerificationMeta('payload');
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
      'payload', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('PENDENTE'));
  static const VerificationMeta _retryCountMeta =
      const VerificationMeta('retryCount');
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
      'retry_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _lastErrorMeta =
      const VerificationMeta('lastError');
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
      'last_error', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        tenantId,
        eventType,
        payload,
        status,
        retryCount,
        lastError,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox';
  @override
  VerificationContext validateIntegrity(Insertable<OutboxData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tenant_id')) {
      context.handle(_tenantIdMeta,
          tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta));
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('event_type')) {
      context.handle(_eventTypeMeta,
          eventType.isAcceptableOrUnknown(data['event_type']!, _eventTypeMeta));
    } else if (isInserting) {
      context.missing(_eventTypeMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(_payloadMeta,
          payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta));
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('retry_count')) {
      context.handle(
          _retryCountMeta,
          retryCount.isAcceptableOrUnknown(
              data['retry_count']!, _retryCountMeta));
    }
    if (data.containsKey('last_error')) {
      context.handle(_lastErrorMeta,
          lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OutboxData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      tenantId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tenant_id'])!,
      eventType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}event_type'])!,
      payload: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      retryCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}retry_count'])!,
      lastError: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}last_error']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $OutboxTable createAlias(String alias) {
    return $OutboxTable(attachedDatabase, alias);
  }
}

class OutboxData extends DataClass implements Insertable<OutboxData> {
  final String id;
  final String tenantId;
  final String eventType;
  final String payload;
  final String status;
  final int retryCount;
  final String? lastError;
  final DateTime createdAt;
  const OutboxData(
      {required this.id,
      required this.tenantId,
      required this.eventType,
      required this.payload,
      required this.status,
      required this.retryCount,
      this.lastError,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tenant_id'] = Variable<String>(tenantId);
    map['event_type'] = Variable<String>(eventType);
    map['payload'] = Variable<String>(payload);
    map['status'] = Variable<String>(status);
    map['retry_count'] = Variable<int>(retryCount);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  OutboxCompanion toCompanion(bool nullToAbsent) {
    return OutboxCompanion(
      id: Value(id),
      tenantId: Value(tenantId),
      eventType: Value(eventType),
      payload: Value(payload),
      status: Value(status),
      retryCount: Value(retryCount),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      createdAt: Value(createdAt),
    );
  }

  factory OutboxData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxData(
      id: serializer.fromJson<String>(json['id']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      eventType: serializer.fromJson<String>(json['eventType']),
      payload: serializer.fromJson<String>(json['payload']),
      status: serializer.fromJson<String>(json['status']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tenantId': serializer.toJson<String>(tenantId),
      'eventType': serializer.toJson<String>(eventType),
      'payload': serializer.toJson<String>(payload),
      'status': serializer.toJson<String>(status),
      'retryCount': serializer.toJson<int>(retryCount),
      'lastError': serializer.toJson<String?>(lastError),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  OutboxData copyWith(
          {String? id,
          String? tenantId,
          String? eventType,
          String? payload,
          String? status,
          int? retryCount,
          Value<String?> lastError = const Value.absent(),
          DateTime? createdAt}) =>
      OutboxData(
        id: id ?? this.id,
        tenantId: tenantId ?? this.tenantId,
        eventType: eventType ?? this.eventType,
        payload: payload ?? this.payload,
        status: status ?? this.status,
        retryCount: retryCount ?? this.retryCount,
        lastError: lastError.present ? lastError.value : this.lastError,
        createdAt: createdAt ?? this.createdAt,
      );
  OutboxData copyWithCompanion(OutboxCompanion data) {
    return OutboxData(
      id: data.id.present ? data.id.value : this.id,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      eventType: data.eventType.present ? data.eventType.value : this.eventType,
      payload: data.payload.present ? data.payload.value : this.payload,
      status: data.status.present ? data.status.value : this.status,
      retryCount:
          data.retryCount.present ? data.retryCount.value : this.retryCount,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxData(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('eventType: $eventType, ')
          ..write('payload: $payload, ')
          ..write('status: $status, ')
          ..write('retryCount: $retryCount, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, tenantId, eventType, payload, status,
      retryCount, lastError, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxData &&
          other.id == this.id &&
          other.tenantId == this.tenantId &&
          other.eventType == this.eventType &&
          other.payload == this.payload &&
          other.status == this.status &&
          other.retryCount == this.retryCount &&
          other.lastError == this.lastError &&
          other.createdAt == this.createdAt);
}

class OutboxCompanion extends UpdateCompanion<OutboxData> {
  final Value<String> id;
  final Value<String> tenantId;
  final Value<String> eventType;
  final Value<String> payload;
  final Value<String> status;
  final Value<int> retryCount;
  final Value<String?> lastError;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const OutboxCompanion({
    this.id = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.eventType = const Value.absent(),
    this.payload = const Value.absent(),
    this.status = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OutboxCompanion.insert({
    required String id,
    required String tenantId,
    required String eventType,
    required String payload,
    this.status = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        tenantId = Value(tenantId),
        eventType = Value(eventType),
        payload = Value(payload);
  static Insertable<OutboxData> custom({
    Expression<String>? id,
    Expression<String>? tenantId,
    Expression<String>? eventType,
    Expression<String>? payload,
    Expression<String>? status,
    Expression<int>? retryCount,
    Expression<String>? lastError,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tenantId != null) 'tenant_id': tenantId,
      if (eventType != null) 'event_type': eventType,
      if (payload != null) 'payload': payload,
      if (status != null) 'status': status,
      if (retryCount != null) 'retry_count': retryCount,
      if (lastError != null) 'last_error': lastError,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OutboxCompanion copyWith(
      {Value<String>? id,
      Value<String>? tenantId,
      Value<String>? eventType,
      Value<String>? payload,
      Value<String>? status,
      Value<int>? retryCount,
      Value<String?>? lastError,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return OutboxCompanion(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      eventType: eventType ?? this.eventType,
      payload: payload ?? this.payload,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (eventType.present) {
      map['event_type'] = Variable<String>(eventType.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxCompanion(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('eventType: $eventType, ')
          ..write('payload: $payload, ')
          ..write('status: $status, ')
          ..write('retryCount: $retryCount, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LocalInventoryTable localInventory = $LocalInventoryTable(this);
  late final $OutboxTable outbox = $OutboxTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [localInventory, outbox];
}

typedef $$LocalInventoryTableCreateCompanionBuilder = LocalInventoryCompanion
    Function({
  required String id,
  required String tenantId,
  required String sku,
  required String codigoEan,
  required String descricao,
  Value<String> ncm,
  Value<String?> cest,
  Value<String> unidadeMedida,
  required double precoVenda,
  Value<double> qtdFisica,
  Value<double> qtdReservada,
  Value<double> cotaOffline,
  Value<int> rowid,
});
typedef $$LocalInventoryTableUpdateCompanionBuilder = LocalInventoryCompanion
    Function({
  Value<String> id,
  Value<String> tenantId,
  Value<String> sku,
  Value<String> codigoEan,
  Value<String> descricao,
  Value<String> ncm,
  Value<String?> cest,
  Value<String> unidadeMedida,
  Value<double> precoVenda,
  Value<double> qtdFisica,
  Value<double> qtdReservada,
  Value<double> cotaOffline,
  Value<int> rowid,
});

class $$LocalInventoryTableFilterComposer
    extends Composer<_$AppDatabase, $LocalInventoryTable> {
  $$LocalInventoryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tenantId => $composableBuilder(
      column: $table.tenantId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sku => $composableBuilder(
      column: $table.sku, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get codigoEan => $composableBuilder(
      column: $table.codigoEan, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get descricao => $composableBuilder(
      column: $table.descricao, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get ncm => $composableBuilder(
      column: $table.ncm, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get cest => $composableBuilder(
      column: $table.cest, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get unidadeMedida => $composableBuilder(
      column: $table.unidadeMedida, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get precoVenda => $composableBuilder(
      column: $table.precoVenda, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get qtdFisica => $composableBuilder(
      column: $table.qtdFisica, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get qtdReservada => $composableBuilder(
      column: $table.qtdReservada, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get cotaOffline => $composableBuilder(
      column: $table.cotaOffline, builder: (column) => ColumnFilters(column));
}

class $$LocalInventoryTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalInventoryTable> {
  $$LocalInventoryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tenantId => $composableBuilder(
      column: $table.tenantId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sku => $composableBuilder(
      column: $table.sku, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get codigoEan => $composableBuilder(
      column: $table.codigoEan, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get descricao => $composableBuilder(
      column: $table.descricao, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get ncm => $composableBuilder(
      column: $table.ncm, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get cest => $composableBuilder(
      column: $table.cest, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get unidadeMedida => $composableBuilder(
      column: $table.unidadeMedida,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get precoVenda => $composableBuilder(
      column: $table.precoVenda, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get qtdFisica => $composableBuilder(
      column: $table.qtdFisica, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get qtdReservada => $composableBuilder(
      column: $table.qtdReservada,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get cotaOffline => $composableBuilder(
      column: $table.cotaOffline, builder: (column) => ColumnOrderings(column));
}

class $$LocalInventoryTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalInventoryTable> {
  $$LocalInventoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get sku =>
      $composableBuilder(column: $table.sku, builder: (column) => column);

  GeneratedColumn<String> get codigoEan =>
      $composableBuilder(column: $table.codigoEan, builder: (column) => column);

  GeneratedColumn<String> get descricao =>
      $composableBuilder(column: $table.descricao, builder: (column) => column);

  GeneratedColumn<String> get ncm =>
      $composableBuilder(column: $table.ncm, builder: (column) => column);

  GeneratedColumn<String> get cest =>
      $composableBuilder(column: $table.cest, builder: (column) => column);

  GeneratedColumn<String> get unidadeMedida => $composableBuilder(
      column: $table.unidadeMedida, builder: (column) => column);

  GeneratedColumn<double> get precoVenda => $composableBuilder(
      column: $table.precoVenda, builder: (column) => column);

  GeneratedColumn<double> get qtdFisica =>
      $composableBuilder(column: $table.qtdFisica, builder: (column) => column);

  GeneratedColumn<double> get qtdReservada => $composableBuilder(
      column: $table.qtdReservada, builder: (column) => column);

  GeneratedColumn<double> get cotaOffline => $composableBuilder(
      column: $table.cotaOffline, builder: (column) => column);
}

class $$LocalInventoryTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LocalInventoryTable,
    LocalInventoryData,
    $$LocalInventoryTableFilterComposer,
    $$LocalInventoryTableOrderingComposer,
    $$LocalInventoryTableAnnotationComposer,
    $$LocalInventoryTableCreateCompanionBuilder,
    $$LocalInventoryTableUpdateCompanionBuilder,
    (
      LocalInventoryData,
      BaseReferences<_$AppDatabase, $LocalInventoryTable, LocalInventoryData>
    ),
    LocalInventoryData,
    PrefetchHooks Function()> {
  $$LocalInventoryTableTableManager(
      _$AppDatabase db, $LocalInventoryTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalInventoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalInventoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalInventoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> tenantId = const Value.absent(),
            Value<String> sku = const Value.absent(),
            Value<String> codigoEan = const Value.absent(),
            Value<String> descricao = const Value.absent(),
            Value<String> ncm = const Value.absent(),
            Value<String?> cest = const Value.absent(),
            Value<String> unidadeMedida = const Value.absent(),
            Value<double> precoVenda = const Value.absent(),
            Value<double> qtdFisica = const Value.absent(),
            Value<double> qtdReservada = const Value.absent(),
            Value<double> cotaOffline = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalInventoryCompanion(
            id: id,
            tenantId: tenantId,
            sku: sku,
            codigoEan: codigoEan,
            descricao: descricao,
            ncm: ncm,
            cest: cest,
            unidadeMedida: unidadeMedida,
            precoVenda: precoVenda,
            qtdFisica: qtdFisica,
            qtdReservada: qtdReservada,
            cotaOffline: cotaOffline,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String tenantId,
            required String sku,
            required String codigoEan,
            required String descricao,
            Value<String> ncm = const Value.absent(),
            Value<String?> cest = const Value.absent(),
            Value<String> unidadeMedida = const Value.absent(),
            required double precoVenda,
            Value<double> qtdFisica = const Value.absent(),
            Value<double> qtdReservada = const Value.absent(),
            Value<double> cotaOffline = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalInventoryCompanion.insert(
            id: id,
            tenantId: tenantId,
            sku: sku,
            codigoEan: codigoEan,
            descricao: descricao,
            ncm: ncm,
            cest: cest,
            unidadeMedida: unidadeMedida,
            precoVenda: precoVenda,
            qtdFisica: qtdFisica,
            qtdReservada: qtdReservada,
            cotaOffline: cotaOffline,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalInventoryTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $LocalInventoryTable,
    LocalInventoryData,
    $$LocalInventoryTableFilterComposer,
    $$LocalInventoryTableOrderingComposer,
    $$LocalInventoryTableAnnotationComposer,
    $$LocalInventoryTableCreateCompanionBuilder,
    $$LocalInventoryTableUpdateCompanionBuilder,
    (
      LocalInventoryData,
      BaseReferences<_$AppDatabase, $LocalInventoryTable, LocalInventoryData>
    ),
    LocalInventoryData,
    PrefetchHooks Function()>;
typedef $$OutboxTableCreateCompanionBuilder = OutboxCompanion Function({
  required String id,
  required String tenantId,
  required String eventType,
  required String payload,
  Value<String> status,
  Value<int> retryCount,
  Value<String?> lastError,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$OutboxTableUpdateCompanionBuilder = OutboxCompanion Function({
  Value<String> id,
  Value<String> tenantId,
  Value<String> eventType,
  Value<String> payload,
  Value<String> status,
  Value<int> retryCount,
  Value<String?> lastError,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$OutboxTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tenantId => $composableBuilder(
      column: $table.tenantId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get eventType => $composableBuilder(
      column: $table.eventType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$OutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tenantId => $composableBuilder(
      column: $table.tenantId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get eventType => $composableBuilder(
      column: $table.eventType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$OutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get eventType =>
      $composableBuilder(column: $table.eventType, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$OutboxTableTableManager extends RootTableManager<
    _$AppDatabase,
    $OutboxTable,
    OutboxData,
    $$OutboxTableFilterComposer,
    $$OutboxTableOrderingComposer,
    $$OutboxTableAnnotationComposer,
    $$OutboxTableCreateCompanionBuilder,
    $$OutboxTableUpdateCompanionBuilder,
    (OutboxData, BaseReferences<_$AppDatabase, $OutboxTable, OutboxData>),
    OutboxData,
    PrefetchHooks Function()> {
  $$OutboxTableTableManager(_$AppDatabase db, $OutboxTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> tenantId = const Value.absent(),
            Value<String> eventType = const Value.absent(),
            Value<String> payload = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<int> retryCount = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              OutboxCompanion(
            id: id,
            tenantId: tenantId,
            eventType: eventType,
            payload: payload,
            status: status,
            retryCount: retryCount,
            lastError: lastError,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String tenantId,
            required String eventType,
            required String payload,
            Value<String> status = const Value.absent(),
            Value<int> retryCount = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              OutboxCompanion.insert(
            id: id,
            tenantId: tenantId,
            eventType: eventType,
            payload: payload,
            status: status,
            retryCount: retryCount,
            lastError: lastError,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$OutboxTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $OutboxTable,
    OutboxData,
    $$OutboxTableFilterComposer,
    $$OutboxTableOrderingComposer,
    $$OutboxTableAnnotationComposer,
    $$OutboxTableCreateCompanionBuilder,
    $$OutboxTableUpdateCompanionBuilder,
    (OutboxData, BaseReferences<_$AppDatabase, $OutboxTable, OutboxData>),
    OutboxData,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LocalInventoryTableTableManager get localInventory =>
      $$LocalInventoryTableTableManager(_db, _db.localInventory);
  $$OutboxTableTableManager get outbox =>
      $$OutboxTableTableManager(_db, _db.outbox);
}
