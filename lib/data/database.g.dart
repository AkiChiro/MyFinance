// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $WalletsTable extends Wallets with TableInfo<$WalletsTable, Wallet> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WalletsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _initialBalanceMeta =
      const VerificationMeta('initialBalance');
  @override
  late final GeneratedColumn<int> initialBalance = GeneratedColumn<int>(
      'initial_balance', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('cash'));
  @override
  List<GeneratedColumn> get $columns => [id, name, initialBalance, type];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'wallets';
  @override
  VerificationContext validateIntegrity(Insertable<Wallet> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('initial_balance')) {
      context.handle(
          _initialBalanceMeta,
          initialBalance.isAcceptableOrUnknown(
              data['initial_balance']!, _initialBalanceMeta));
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Wallet map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Wallet(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      initialBalance: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}initial_balance'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
    );
  }

  @override
  $WalletsTable createAlias(String alias) {
    return $WalletsTable(attachedDatabase, alias);
  }
}

class Wallet extends DataClass implements Insertable<Wallet> {
  final String id;
  final String name;
  final int initialBalance;
  final String type;
  const Wallet(
      {required this.id,
      required this.name,
      required this.initialBalance,
      required this.type});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['initial_balance'] = Variable<int>(initialBalance);
    map['type'] = Variable<String>(type);
    return map;
  }

  WalletsCompanion toCompanion(bool nullToAbsent) {
    return WalletsCompanion(
      id: Value(id),
      name: Value(name),
      initialBalance: Value(initialBalance),
      type: Value(type),
    );
  }

  factory Wallet.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Wallet(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      initialBalance: serializer.fromJson<int>(json['initialBalance']),
      type: serializer.fromJson<String>(json['type']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'initialBalance': serializer.toJson<int>(initialBalance),
      'type': serializer.toJson<String>(type),
    };
  }

  Wallet copyWith(
          {String? id, String? name, int? initialBalance, String? type}) =>
      Wallet(
        id: id ?? this.id,
        name: name ?? this.name,
        initialBalance: initialBalance ?? this.initialBalance,
        type: type ?? this.type,
      );
  Wallet copyWithCompanion(WalletsCompanion data) {
    return Wallet(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      initialBalance: data.initialBalance.present
          ? data.initialBalance.value
          : this.initialBalance,
      type: data.type.present ? data.type.value : this.type,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Wallet(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('initialBalance: $initialBalance, ')
          ..write('type: $type')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, initialBalance, type);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Wallet &&
          other.id == this.id &&
          other.name == this.name &&
          other.initialBalance == this.initialBalance &&
          other.type == this.type);
}

class WalletsCompanion extends UpdateCompanion<Wallet> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> initialBalance;
  final Value<String> type;
  final Value<int> rowid;
  const WalletsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.initialBalance = const Value.absent(),
    this.type = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WalletsCompanion.insert({
    required String id,
    required String name,
    this.initialBalance = const Value.absent(),
    this.type = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name);
  static Insertable<Wallet> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? initialBalance,
    Expression<String>? type,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (initialBalance != null) 'initial_balance': initialBalance,
      if (type != null) 'type': type,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WalletsCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<int>? initialBalance,
      Value<String>? type,
      Value<int>? rowid}) {
    return WalletsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      initialBalance: initialBalance ?? this.initialBalance,
      type: type ?? this.type,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (initialBalance.present) {
      map['initial_balance'] = Variable<int>(initialBalance.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WalletsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('initialBalance: $initialBalance, ')
          ..write('type: $type, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TxnsTable extends Txns with TableInfo<$TxnsTable, Txn> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TxnsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<int> amount = GeneratedColumn<int>(
      'amount', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _walletIdMeta =
      const VerificationMeta('walletId');
  @override
  late final GeneratedColumn<String> walletId = GeneratedColumn<String>(
      'wallet_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _walletToIdMeta =
      const VerificationMeta('walletToId');
  @override
  late final GeneratedColumn<String> walletToId = GeneratedColumn<String>(
      'wallet_to_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _timestampMeta =
      const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
      'timestamp', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _importedMeta =
      const VerificationMeta('imported');
  @override
  late final GeneratedColumn<bool> imported = GeneratedColumn<bool>(
      'imported', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("imported" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _starredMeta =
      const VerificationMeta('starred');
  @override
  late final GeneratedColumn<bool> starred = GeneratedColumn<bool>(
      'starred', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("starred" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _walletFromNameMeta =
      const VerificationMeta('walletFromName');
  @override
  late final GeneratedColumn<String> walletFromName = GeneratedColumn<String>(
      'wallet_from_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _walletToNameMeta =
      const VerificationMeta('walletToName');
  @override
  late final GeneratedColumn<String> walletToName = GeneratedColumn<String>(
      'wallet_to_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        type,
        amount,
        description,
        walletId,
        walletToId,
        category,
        timestamp,
        createdAt,
        imported,
        starred,
        walletFromName,
        walletToName
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'txns';
  @override
  VerificationContext validateIntegrity(Insertable<Txn> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(_amountMeta,
          amount.isAcceptableOrUnknown(data['amount']!, _amountMeta));
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('wallet_id')) {
      context.handle(_walletIdMeta,
          walletId.isAcceptableOrUnknown(data['wallet_id']!, _walletIdMeta));
    } else if (isInserting) {
      context.missing(_walletIdMeta);
    }
    if (data.containsKey('wallet_to_id')) {
      context.handle(
          _walletToIdMeta,
          walletToId.isAcceptableOrUnknown(
              data['wallet_to_id']!, _walletToIdMeta));
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta,
          timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('imported')) {
      context.handle(_importedMeta,
          imported.isAcceptableOrUnknown(data['imported']!, _importedMeta));
    }
    if (data.containsKey('starred')) {
      context.handle(_starredMeta,
          starred.isAcceptableOrUnknown(data['starred']!, _starredMeta));
    }
    if (data.containsKey('wallet_from_name')) {
      context.handle(
          _walletFromNameMeta,
          walletFromName.isAcceptableOrUnknown(
              data['wallet_from_name']!, _walletFromNameMeta));
    }
    if (data.containsKey('wallet_to_name')) {
      context.handle(
          _walletToNameMeta,
          walletToName.isAcceptableOrUnknown(
              data['wallet_to_name']!, _walletToNameMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Txn map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Txn(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      amount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}amount'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      walletId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}wallet_id'])!,
      walletToId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}wallet_to_id']),
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category']),
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}timestamp'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      imported: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}imported'])!,
      starred: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}starred'])!,
      walletFromName: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}wallet_from_name']),
      walletToName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}wallet_to_name']),
    );
  }

  @override
  $TxnsTable createAlias(String alias) {
    return $TxnsTable(attachedDatabase, alias);
  }
}

class Txn extends DataClass implements Insertable<Txn> {
  final String id;
  final String type;
  final int amount;
  final String? description;
  final String walletId;
  final String? walletToId;
  final String? category;
  final DateTime timestamp;
  final DateTime createdAt;
  final bool imported;
  final bool starred;

  /// Snapshot of the source wallet name at CSV-import time (for merged rows).
  final String? walletFromName;

  /// Snapshot of the destination wallet name at CSV-import time.
  final String? walletToName;
  const Txn(
      {required this.id,
      required this.type,
      required this.amount,
      this.description,
      required this.walletId,
      this.walletToId,
      this.category,
      required this.timestamp,
      required this.createdAt,
      required this.imported,
      required this.starred,
      this.walletFromName,
      this.walletToName});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['type'] = Variable<String>(type);
    map['amount'] = Variable<int>(amount);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['wallet_id'] = Variable<String>(walletId);
    if (!nullToAbsent || walletToId != null) {
      map['wallet_to_id'] = Variable<String>(walletToId);
    }
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    map['timestamp'] = Variable<DateTime>(timestamp);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['imported'] = Variable<bool>(imported);
    map['starred'] = Variable<bool>(starred);
    if (!nullToAbsent || walletFromName != null) {
      map['wallet_from_name'] = Variable<String>(walletFromName);
    }
    if (!nullToAbsent || walletToName != null) {
      map['wallet_to_name'] = Variable<String>(walletToName);
    }
    return map;
  }

  TxnsCompanion toCompanion(bool nullToAbsent) {
    return TxnsCompanion(
      id: Value(id),
      type: Value(type),
      amount: Value(amount),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      walletId: Value(walletId),
      walletToId: walletToId == null && nullToAbsent
          ? const Value.absent()
          : Value(walletToId),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      timestamp: Value(timestamp),
      createdAt: Value(createdAt),
      imported: Value(imported),
      starred: Value(starred),
      walletFromName: walletFromName == null && nullToAbsent
          ? const Value.absent()
          : Value(walletFromName),
      walletToName: walletToName == null && nullToAbsent
          ? const Value.absent()
          : Value(walletToName),
    );
  }

  factory Txn.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Txn(
      id: serializer.fromJson<String>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      amount: serializer.fromJson<int>(json['amount']),
      description: serializer.fromJson<String?>(json['description']),
      walletId: serializer.fromJson<String>(json['walletId']),
      walletToId: serializer.fromJson<String?>(json['walletToId']),
      category: serializer.fromJson<String?>(json['category']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      imported: serializer.fromJson<bool>(json['imported']),
      starred: serializer.fromJson<bool>(json['starred']),
      walletFromName: serializer.fromJson<String?>(json['walletFromName']),
      walletToName: serializer.fromJson<String?>(json['walletToName']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'type': serializer.toJson<String>(type),
      'amount': serializer.toJson<int>(amount),
      'description': serializer.toJson<String?>(description),
      'walletId': serializer.toJson<String>(walletId),
      'walletToId': serializer.toJson<String?>(walletToId),
      'category': serializer.toJson<String?>(category),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'imported': serializer.toJson<bool>(imported),
      'starred': serializer.toJson<bool>(starred),
      'walletFromName': serializer.toJson<String?>(walletFromName),
      'walletToName': serializer.toJson<String?>(walletToName),
    };
  }

  Txn copyWith(
          {String? id,
          String? type,
          int? amount,
          Value<String?> description = const Value.absent(),
          String? walletId,
          Value<String?> walletToId = const Value.absent(),
          Value<String?> category = const Value.absent(),
          DateTime? timestamp,
          DateTime? createdAt,
          bool? imported,
          bool? starred,
          Value<String?> walletFromName = const Value.absent(),
          Value<String?> walletToName = const Value.absent()}) =>
      Txn(
        id: id ?? this.id,
        type: type ?? this.type,
        amount: amount ?? this.amount,
        description: description.present ? description.value : this.description,
        walletId: walletId ?? this.walletId,
        walletToId: walletToId.present ? walletToId.value : this.walletToId,
        category: category.present ? category.value : this.category,
        timestamp: timestamp ?? this.timestamp,
        createdAt: createdAt ?? this.createdAt,
        imported: imported ?? this.imported,
        starred: starred ?? this.starred,
        walletFromName:
            walletFromName.present ? walletFromName.value : this.walletFromName,
        walletToName:
            walletToName.present ? walletToName.value : this.walletToName,
      );
  Txn copyWithCompanion(TxnsCompanion data) {
    return Txn(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      amount: data.amount.present ? data.amount.value : this.amount,
      description:
          data.description.present ? data.description.value : this.description,
      walletId: data.walletId.present ? data.walletId.value : this.walletId,
      walletToId:
          data.walletToId.present ? data.walletToId.value : this.walletToId,
      category: data.category.present ? data.category.value : this.category,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      imported: data.imported.present ? data.imported.value : this.imported,
      starred: data.starred.present ? data.starred.value : this.starred,
      walletFromName: data.walletFromName.present
          ? data.walletFromName.value
          : this.walletFromName,
      walletToName: data.walletToName.present
          ? data.walletToName.value
          : this.walletToName,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Txn(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('amount: $amount, ')
          ..write('description: $description, ')
          ..write('walletId: $walletId, ')
          ..write('walletToId: $walletToId, ')
          ..write('category: $category, ')
          ..write('timestamp: $timestamp, ')
          ..write('createdAt: $createdAt, ')
          ..write('imported: $imported, ')
          ..write('starred: $starred, ')
          ..write('walletFromName: $walletFromName, ')
          ..write('walletToName: $walletToName')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      type,
      amount,
      description,
      walletId,
      walletToId,
      category,
      timestamp,
      createdAt,
      imported,
      starred,
      walletFromName,
      walletToName);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Txn &&
          other.id == this.id &&
          other.type == this.type &&
          other.amount == this.amount &&
          other.description == this.description &&
          other.walletId == this.walletId &&
          other.walletToId == this.walletToId &&
          other.category == this.category &&
          other.timestamp == this.timestamp &&
          other.createdAt == this.createdAt &&
          other.imported == this.imported &&
          other.starred == this.starred &&
          other.walletFromName == this.walletFromName &&
          other.walletToName == this.walletToName);
}

class TxnsCompanion extends UpdateCompanion<Txn> {
  final Value<String> id;
  final Value<String> type;
  final Value<int> amount;
  final Value<String?> description;
  final Value<String> walletId;
  final Value<String?> walletToId;
  final Value<String?> category;
  final Value<DateTime> timestamp;
  final Value<DateTime> createdAt;
  final Value<bool> imported;
  final Value<bool> starred;
  final Value<String?> walletFromName;
  final Value<String?> walletToName;
  final Value<int> rowid;
  const TxnsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.amount = const Value.absent(),
    this.description = const Value.absent(),
    this.walletId = const Value.absent(),
    this.walletToId = const Value.absent(),
    this.category = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.imported = const Value.absent(),
    this.starred = const Value.absent(),
    this.walletFromName = const Value.absent(),
    this.walletToName = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TxnsCompanion.insert({
    required String id,
    required String type,
    required int amount,
    this.description = const Value.absent(),
    required String walletId,
    this.walletToId = const Value.absent(),
    this.category = const Value.absent(),
    required DateTime timestamp,
    required DateTime createdAt,
    this.imported = const Value.absent(),
    this.starred = const Value.absent(),
    this.walletFromName = const Value.absent(),
    this.walletToName = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        type = Value(type),
        amount = Value(amount),
        walletId = Value(walletId),
        timestamp = Value(timestamp),
        createdAt = Value(createdAt);
  static Insertable<Txn> custom({
    Expression<String>? id,
    Expression<String>? type,
    Expression<int>? amount,
    Expression<String>? description,
    Expression<String>? walletId,
    Expression<String>? walletToId,
    Expression<String>? category,
    Expression<DateTime>? timestamp,
    Expression<DateTime>? createdAt,
    Expression<bool>? imported,
    Expression<bool>? starred,
    Expression<String>? walletFromName,
    Expression<String>? walletToName,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (amount != null) 'amount': amount,
      if (description != null) 'description': description,
      if (walletId != null) 'wallet_id': walletId,
      if (walletToId != null) 'wallet_to_id': walletToId,
      if (category != null) 'category': category,
      if (timestamp != null) 'timestamp': timestamp,
      if (createdAt != null) 'created_at': createdAt,
      if (imported != null) 'imported': imported,
      if (starred != null) 'starred': starred,
      if (walletFromName != null) 'wallet_from_name': walletFromName,
      if (walletToName != null) 'wallet_to_name': walletToName,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TxnsCompanion copyWith(
      {Value<String>? id,
      Value<String>? type,
      Value<int>? amount,
      Value<String?>? description,
      Value<String>? walletId,
      Value<String?>? walletToId,
      Value<String?>? category,
      Value<DateTime>? timestamp,
      Value<DateTime>? createdAt,
      Value<bool>? imported,
      Value<bool>? starred,
      Value<String?>? walletFromName,
      Value<String?>? walletToName,
      Value<int>? rowid}) {
    return TxnsCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      walletId: walletId ?? this.walletId,
      walletToId: walletToId ?? this.walletToId,
      category: category ?? this.category,
      timestamp: timestamp ?? this.timestamp,
      createdAt: createdAt ?? this.createdAt,
      imported: imported ?? this.imported,
      starred: starred ?? this.starred,
      walletFromName: walletFromName ?? this.walletFromName,
      walletToName: walletToName ?? this.walletToName,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (amount.present) {
      map['amount'] = Variable<int>(amount.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (walletId.present) {
      map['wallet_id'] = Variable<String>(walletId.value);
    }
    if (walletToId.present) {
      map['wallet_to_id'] = Variable<String>(walletToId.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (imported.present) {
      map['imported'] = Variable<bool>(imported.value);
    }
    if (starred.present) {
      map['starred'] = Variable<bool>(starred.value);
    }
    if (walletFromName.present) {
      map['wallet_from_name'] = Variable<String>(walletFromName.value);
    }
    if (walletToName.present) {
      map['wallet_to_name'] = Variable<String>(walletToName.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TxnsCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('amount: $amount, ')
          ..write('description: $description, ')
          ..write('walletId: $walletId, ')
          ..write('walletToId: $walletToId, ')
          ..write('category: $category, ')
          ..write('timestamp: $timestamp, ')
          ..write('createdAt: $createdAt, ')
          ..write('imported: $imported, ')
          ..write('starred: $starred, ')
          ..write('walletFromName: $walletFromName, ')
          ..write('walletToName: $walletToName, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppCategoriesTable extends AppCategories
    with TableInfo<$AppCategoriesTable, AppCategory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppCategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
      'label', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
      'kind', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _thresholdMeta =
      const VerificationMeta('threshold');
  @override
  late final GeneratedColumn<int> threshold = GeneratedColumn<int>(
      'threshold', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _isDefaultMeta =
      const VerificationMeta('isDefault');
  @override
  late final GeneratedColumn<bool> isDefault = GeneratedColumn<bool>(
      'is_default', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_default" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _archivedMeta =
      const VerificationMeta('archived');
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
      'archived', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("archived" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns =>
      [id, label, kind, threshold, isDefault, archived, sortOrder];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_categories';
  @override
  VerificationContext validateIntegrity(Insertable<AppCategory> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
          _labelMeta, label.isAcceptableOrUnknown(data['label']!, _labelMeta));
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
          _kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('threshold')) {
      context.handle(_thresholdMeta,
          threshold.isAcceptableOrUnknown(data['threshold']!, _thresholdMeta));
    }
    if (data.containsKey('is_default')) {
      context.handle(_isDefaultMeta,
          isDefault.isAcceptableOrUnknown(data['is_default']!, _isDefaultMeta));
    }
    if (data.containsKey('archived')) {
      context.handle(_archivedMeta,
          archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta));
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AppCategory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppCategory(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      label: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}label'])!,
      kind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      threshold: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}threshold'])!,
      isDefault: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_default'])!,
      archived: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}archived'])!,
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
    );
  }

  @override
  $AppCategoriesTable createAlias(String alias) {
    return $AppCategoriesTable(attachedDatabase, alias);
  }
}

class AppCategory extends DataClass implements Insertable<AppCategory> {
  final String id;
  final String label;
  final String kind;
  final int threshold;
  final bool isDefault;
  final bool archived;
  final int sortOrder;
  const AppCategory(
      {required this.id,
      required this.label,
      required this.kind,
      required this.threshold,
      required this.isDefault,
      required this.archived,
      required this.sortOrder});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['label'] = Variable<String>(label);
    map['kind'] = Variable<String>(kind);
    map['threshold'] = Variable<int>(threshold);
    map['is_default'] = Variable<bool>(isDefault);
    map['archived'] = Variable<bool>(archived);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  AppCategoriesCompanion toCompanion(bool nullToAbsent) {
    return AppCategoriesCompanion(
      id: Value(id),
      label: Value(label),
      kind: Value(kind),
      threshold: Value(threshold),
      isDefault: Value(isDefault),
      archived: Value(archived),
      sortOrder: Value(sortOrder),
    );
  }

  factory AppCategory.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppCategory(
      id: serializer.fromJson<String>(json['id']),
      label: serializer.fromJson<String>(json['label']),
      kind: serializer.fromJson<String>(json['kind']),
      threshold: serializer.fromJson<int>(json['threshold']),
      isDefault: serializer.fromJson<bool>(json['isDefault']),
      archived: serializer.fromJson<bool>(json['archived']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'label': serializer.toJson<String>(label),
      'kind': serializer.toJson<String>(kind),
      'threshold': serializer.toJson<int>(threshold),
      'isDefault': serializer.toJson<bool>(isDefault),
      'archived': serializer.toJson<bool>(archived),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  AppCategory copyWith(
          {String? id,
          String? label,
          String? kind,
          int? threshold,
          bool? isDefault,
          bool? archived,
          int? sortOrder}) =>
      AppCategory(
        id: id ?? this.id,
        label: label ?? this.label,
        kind: kind ?? this.kind,
        threshold: threshold ?? this.threshold,
        isDefault: isDefault ?? this.isDefault,
        archived: archived ?? this.archived,
        sortOrder: sortOrder ?? this.sortOrder,
      );
  AppCategory copyWithCompanion(AppCategoriesCompanion data) {
    return AppCategory(
      id: data.id.present ? data.id.value : this.id,
      label: data.label.present ? data.label.value : this.label,
      kind: data.kind.present ? data.kind.value : this.kind,
      threshold: data.threshold.present ? data.threshold.value : this.threshold,
      isDefault: data.isDefault.present ? data.isDefault.value : this.isDefault,
      archived: data.archived.present ? data.archived.value : this.archived,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppCategory(')
          ..write('id: $id, ')
          ..write('label: $label, ')
          ..write('kind: $kind, ')
          ..write('threshold: $threshold, ')
          ..write('isDefault: $isDefault, ')
          ..write('archived: $archived, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, label, kind, threshold, isDefault, archived, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppCategory &&
          other.id == this.id &&
          other.label == this.label &&
          other.kind == this.kind &&
          other.threshold == this.threshold &&
          other.isDefault == this.isDefault &&
          other.archived == this.archived &&
          other.sortOrder == this.sortOrder);
}

class AppCategoriesCompanion extends UpdateCompanion<AppCategory> {
  final Value<String> id;
  final Value<String> label;
  final Value<String> kind;
  final Value<int> threshold;
  final Value<bool> isDefault;
  final Value<bool> archived;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const AppCategoriesCompanion({
    this.id = const Value.absent(),
    this.label = const Value.absent(),
    this.kind = const Value.absent(),
    this.threshold = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.archived = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppCategoriesCompanion.insert({
    required String id,
    required String label,
    required String kind,
    this.threshold = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.archived = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        label = Value(label),
        kind = Value(kind);
  static Insertable<AppCategory> custom({
    Expression<String>? id,
    Expression<String>? label,
    Expression<String>? kind,
    Expression<int>? threshold,
    Expression<bool>? isDefault,
    Expression<bool>? archived,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (label != null) 'label': label,
      if (kind != null) 'kind': kind,
      if (threshold != null) 'threshold': threshold,
      if (isDefault != null) 'is_default': isDefault,
      if (archived != null) 'archived': archived,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppCategoriesCompanion copyWith(
      {Value<String>? id,
      Value<String>? label,
      Value<String>? kind,
      Value<int>? threshold,
      Value<bool>? isDefault,
      Value<bool>? archived,
      Value<int>? sortOrder,
      Value<int>? rowid}) {
    return AppCategoriesCompanion(
      id: id ?? this.id,
      label: label ?? this.label,
      kind: kind ?? this.kind,
      threshold: threshold ?? this.threshold,
      isDefault: isDefault ?? this.isDefault,
      archived: archived ?? this.archived,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (threshold.present) {
      map['threshold'] = Variable<int>(threshold.value);
    }
    if (isDefault.present) {
      map['is_default'] = Variable<bool>(isDefault.value);
    }
    if (archived.present) {
      map['archived'] = Variable<bool>(archived.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppCategoriesCompanion(')
          ..write('id: $id, ')
          ..write('label: $label, ')
          ..write('kind: $kind, ')
          ..write('threshold: $threshold, ')
          ..write('isDefault: $isDefault, ')
          ..write('archived: $archived, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $WalletsTable wallets = $WalletsTable(this);
  late final $TxnsTable txns = $TxnsTable(this);
  late final $AppCategoriesTable appCategories = $AppCategoriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [wallets, txns, appCategories];
}

typedef $$WalletsTableCreateCompanionBuilder = WalletsCompanion Function({
  required String id,
  required String name,
  Value<int> initialBalance,
  Value<String> type,
  Value<int> rowid,
});
typedef $$WalletsTableUpdateCompanionBuilder = WalletsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<int> initialBalance,
  Value<String> type,
  Value<int> rowid,
});

class $$WalletsTableFilterComposer
    extends Composer<_$AppDatabase, $WalletsTable> {
  $$WalletsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get initialBalance => $composableBuilder(
      column: $table.initialBalance,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));
}

class $$WalletsTableOrderingComposer
    extends Composer<_$AppDatabase, $WalletsTable> {
  $$WalletsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get initialBalance => $composableBuilder(
      column: $table.initialBalance,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));
}

class $$WalletsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WalletsTable> {
  $$WalletsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get initialBalance => $composableBuilder(
      column: $table.initialBalance, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);
}

class $$WalletsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $WalletsTable,
    Wallet,
    $$WalletsTableFilterComposer,
    $$WalletsTableOrderingComposer,
    $$WalletsTableAnnotationComposer,
    $$WalletsTableCreateCompanionBuilder,
    $$WalletsTableUpdateCompanionBuilder,
    (Wallet, BaseReferences<_$AppDatabase, $WalletsTable, Wallet>),
    Wallet,
    PrefetchHooks Function()> {
  $$WalletsTableTableManager(_$AppDatabase db, $WalletsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WalletsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WalletsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WalletsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<int> initialBalance = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              WalletsCompanion(
            id: id,
            name: name,
            initialBalance: initialBalance,
            type: type,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            Value<int> initialBalance = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              WalletsCompanion.insert(
            id: id,
            name: name,
            initialBalance: initialBalance,
            type: type,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$WalletsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $WalletsTable,
    Wallet,
    $$WalletsTableFilterComposer,
    $$WalletsTableOrderingComposer,
    $$WalletsTableAnnotationComposer,
    $$WalletsTableCreateCompanionBuilder,
    $$WalletsTableUpdateCompanionBuilder,
    (Wallet, BaseReferences<_$AppDatabase, $WalletsTable, Wallet>),
    Wallet,
    PrefetchHooks Function()>;
typedef $$TxnsTableCreateCompanionBuilder = TxnsCompanion Function({
  required String id,
  required String type,
  required int amount,
  Value<String?> description,
  required String walletId,
  Value<String?> walletToId,
  Value<String?> category,
  required DateTime timestamp,
  required DateTime createdAt,
  Value<bool> imported,
  Value<bool> starred,
  Value<String?> walletFromName,
  Value<String?> walletToName,
  Value<int> rowid,
});
typedef $$TxnsTableUpdateCompanionBuilder = TxnsCompanion Function({
  Value<String> id,
  Value<String> type,
  Value<int> amount,
  Value<String?> description,
  Value<String> walletId,
  Value<String?> walletToId,
  Value<String?> category,
  Value<DateTime> timestamp,
  Value<DateTime> createdAt,
  Value<bool> imported,
  Value<bool> starred,
  Value<String?> walletFromName,
  Value<String?> walletToName,
  Value<int> rowid,
});

class $$TxnsTableFilterComposer extends Composer<_$AppDatabase, $TxnsTable> {
  $$TxnsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get walletId => $composableBuilder(
      column: $table.walletId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get walletToId => $composableBuilder(
      column: $table.walletToId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get imported => $composableBuilder(
      column: $table.imported, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get starred => $composableBuilder(
      column: $table.starred, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get walletFromName => $composableBuilder(
      column: $table.walletFromName,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get walletToName => $composableBuilder(
      column: $table.walletToName, builder: (column) => ColumnFilters(column));
}

class $$TxnsTableOrderingComposer extends Composer<_$AppDatabase, $TxnsTable> {
  $$TxnsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get walletId => $composableBuilder(
      column: $table.walletId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get walletToId => $composableBuilder(
      column: $table.walletToId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get imported => $composableBuilder(
      column: $table.imported, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get starred => $composableBuilder(
      column: $table.starred, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get walletFromName => $composableBuilder(
      column: $table.walletFromName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get walletToName => $composableBuilder(
      column: $table.walletToName,
      builder: (column) => ColumnOrderings(column));
}

class $$TxnsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TxnsTable> {
  $$TxnsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<String> get walletId =>
      $composableBuilder(column: $table.walletId, builder: (column) => column);

  GeneratedColumn<String> get walletToId => $composableBuilder(
      column: $table.walletToId, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get imported =>
      $composableBuilder(column: $table.imported, builder: (column) => column);

  GeneratedColumn<bool> get starred =>
      $composableBuilder(column: $table.starred, builder: (column) => column);

  GeneratedColumn<String> get walletFromName => $composableBuilder(
      column: $table.walletFromName, builder: (column) => column);

  GeneratedColumn<String> get walletToName => $composableBuilder(
      column: $table.walletToName, builder: (column) => column);
}

class $$TxnsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TxnsTable,
    Txn,
    $$TxnsTableFilterComposer,
    $$TxnsTableOrderingComposer,
    $$TxnsTableAnnotationComposer,
    $$TxnsTableCreateCompanionBuilder,
    $$TxnsTableUpdateCompanionBuilder,
    (Txn, BaseReferences<_$AppDatabase, $TxnsTable, Txn>),
    Txn,
    PrefetchHooks Function()> {
  $$TxnsTableTableManager(_$AppDatabase db, $TxnsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TxnsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TxnsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TxnsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<int> amount = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<String> walletId = const Value.absent(),
            Value<String?> walletToId = const Value.absent(),
            Value<String?> category = const Value.absent(),
            Value<DateTime> timestamp = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<bool> imported = const Value.absent(),
            Value<bool> starred = const Value.absent(),
            Value<String?> walletFromName = const Value.absent(),
            Value<String?> walletToName = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TxnsCompanion(
            id: id,
            type: type,
            amount: amount,
            description: description,
            walletId: walletId,
            walletToId: walletToId,
            category: category,
            timestamp: timestamp,
            createdAt: createdAt,
            imported: imported,
            starred: starred,
            walletFromName: walletFromName,
            walletToName: walletToName,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String type,
            required int amount,
            Value<String?> description = const Value.absent(),
            required String walletId,
            Value<String?> walletToId = const Value.absent(),
            Value<String?> category = const Value.absent(),
            required DateTime timestamp,
            required DateTime createdAt,
            Value<bool> imported = const Value.absent(),
            Value<bool> starred = const Value.absent(),
            Value<String?> walletFromName = const Value.absent(),
            Value<String?> walletToName = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TxnsCompanion.insert(
            id: id,
            type: type,
            amount: amount,
            description: description,
            walletId: walletId,
            walletToId: walletToId,
            category: category,
            timestamp: timestamp,
            createdAt: createdAt,
            imported: imported,
            starred: starred,
            walletFromName: walletFromName,
            walletToName: walletToName,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$TxnsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $TxnsTable,
    Txn,
    $$TxnsTableFilterComposer,
    $$TxnsTableOrderingComposer,
    $$TxnsTableAnnotationComposer,
    $$TxnsTableCreateCompanionBuilder,
    $$TxnsTableUpdateCompanionBuilder,
    (Txn, BaseReferences<_$AppDatabase, $TxnsTable, Txn>),
    Txn,
    PrefetchHooks Function()>;
typedef $$AppCategoriesTableCreateCompanionBuilder = AppCategoriesCompanion
    Function({
  required String id,
  required String label,
  required String kind,
  Value<int> threshold,
  Value<bool> isDefault,
  Value<bool> archived,
  Value<int> sortOrder,
  Value<int> rowid,
});
typedef $$AppCategoriesTableUpdateCompanionBuilder = AppCategoriesCompanion
    Function({
  Value<String> id,
  Value<String> label,
  Value<String> kind,
  Value<int> threshold,
  Value<bool> isDefault,
  Value<bool> archived,
  Value<int> sortOrder,
  Value<int> rowid,
});

class $$AppCategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $AppCategoriesTable> {
  $$AppCategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get label => $composableBuilder(
      column: $table.label, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get threshold => $composableBuilder(
      column: $table.threshold, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isDefault => $composableBuilder(
      column: $table.isDefault, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get archived => $composableBuilder(
      column: $table.archived, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnFilters(column));
}

class $$AppCategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $AppCategoriesTable> {
  $$AppCategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get label => $composableBuilder(
      column: $table.label, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get threshold => $composableBuilder(
      column: $table.threshold, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isDefault => $composableBuilder(
      column: $table.isDefault, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get archived => $composableBuilder(
      column: $table.archived, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnOrderings(column));
}

class $$AppCategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppCategoriesTable> {
  $$AppCategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get threshold =>
      $composableBuilder(column: $table.threshold, builder: (column) => column);

  GeneratedColumn<bool> get isDefault =>
      $composableBuilder(column: $table.isDefault, builder: (column) => column);

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);
}

class $$AppCategoriesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AppCategoriesTable,
    AppCategory,
    $$AppCategoriesTableFilterComposer,
    $$AppCategoriesTableOrderingComposer,
    $$AppCategoriesTableAnnotationComposer,
    $$AppCategoriesTableCreateCompanionBuilder,
    $$AppCategoriesTableUpdateCompanionBuilder,
    (
      AppCategory,
      BaseReferences<_$AppDatabase, $AppCategoriesTable, AppCategory>
    ),
    AppCategory,
    PrefetchHooks Function()> {
  $$AppCategoriesTableTableManager(_$AppDatabase db, $AppCategoriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppCategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppCategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppCategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> label = const Value.absent(),
            Value<String> kind = const Value.absent(),
            Value<int> threshold = const Value.absent(),
            Value<bool> isDefault = const Value.absent(),
            Value<bool> archived = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AppCategoriesCompanion(
            id: id,
            label: label,
            kind: kind,
            threshold: threshold,
            isDefault: isDefault,
            archived: archived,
            sortOrder: sortOrder,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String label,
            required String kind,
            Value<int> threshold = const Value.absent(),
            Value<bool> isDefault = const Value.absent(),
            Value<bool> archived = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AppCategoriesCompanion.insert(
            id: id,
            label: label,
            kind: kind,
            threshold: threshold,
            isDefault: isDefault,
            archived: archived,
            sortOrder: sortOrder,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AppCategoriesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AppCategoriesTable,
    AppCategory,
    $$AppCategoriesTableFilterComposer,
    $$AppCategoriesTableOrderingComposer,
    $$AppCategoriesTableAnnotationComposer,
    $$AppCategoriesTableCreateCompanionBuilder,
    $$AppCategoriesTableUpdateCompanionBuilder,
    (
      AppCategory,
      BaseReferences<_$AppDatabase, $AppCategoriesTable, AppCategory>
    ),
    AppCategory,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$WalletsTableTableManager get wallets =>
      $$WalletsTableTableManager(_db, _db.wallets);
  $$TxnsTableTableManager get txns => $$TxnsTableTableManager(_db, _db.txns);
  $$AppCategoriesTableTableManager get appCategories =>
      $$AppCategoriesTableTableManager(_db, _db.appCategories);
}
