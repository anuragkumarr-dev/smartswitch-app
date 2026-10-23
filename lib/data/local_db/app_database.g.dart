// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CachedHomesTable extends CachedHomes
    with TableInfo<$CachedHomesTable, CachedHome> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedHomesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _homeIdMeta = const VerificationMeta('homeId');
  @override
  late final GeneratedColumn<String> homeId = GeneratedColumn<String>(
    'home_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timezoneMeta = const VerificationMeta(
    'timezone',
  );
  @override
  late final GeneratedColumn<String> timezone = GeneratedColumn<String>(
    'timezone',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _homeKeyMeta = const VerificationMeta(
    'homeKey',
  );
  @override
  late final GeneratedColumn<Uint8List> homeKey = GeneratedColumn<Uint8List>(
    'home_key',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _meshIdMeta = const VerificationMeta('meshId');
  @override
  late final GeneratedColumn<String> meshId = GeneratedColumn<String>(
    'mesh_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _meshApPasswordMeta = const VerificationMeta(
    'meshApPassword',
  );
  @override
  late final GeneratedColumn<String> meshApPassword = GeneratedColumn<String>(
    'mesh_ap_password',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    homeId,
    name,
    timezone,
    homeKey,
    meshId,
    meshApPassword,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_homes';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedHome> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('home_id')) {
      context.handle(
        _homeIdMeta,
        homeId.isAcceptableOrUnknown(data['home_id']!, _homeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_homeIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('timezone')) {
      context.handle(
        _timezoneMeta,
        timezone.isAcceptableOrUnknown(data['timezone']!, _timezoneMeta),
      );
    } else if (isInserting) {
      context.missing(_timezoneMeta);
    }
    if (data.containsKey('home_key')) {
      context.handle(
        _homeKeyMeta,
        homeKey.isAcceptableOrUnknown(data['home_key']!, _homeKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_homeKeyMeta);
    }
    if (data.containsKey('mesh_id')) {
      context.handle(
        _meshIdMeta,
        meshId.isAcceptableOrUnknown(data['mesh_id']!, _meshIdMeta),
      );
    } else if (isInserting) {
      context.missing(_meshIdMeta);
    }
    if (data.containsKey('mesh_ap_password')) {
      context.handle(
        _meshApPasswordMeta,
        meshApPassword.isAcceptableOrUnknown(
          data['mesh_ap_password']!,
          _meshApPasswordMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_meshApPasswordMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {homeId};
  @override
  CachedHome map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedHome(
      homeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}home_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      timezone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}timezone'],
      )!,
      homeKey: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}home_key'],
      )!,
      meshId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mesh_id'],
      )!,
      meshApPassword: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mesh_ap_password'],
      )!,
    );
  }

  @override
  $CachedHomesTable createAlias(String alias) {
    return $CachedHomesTable(attachedDatabase, alias);
  }
}

class CachedHome extends DataClass implements Insertable<CachedHome> {
  final String homeId;
  final String name;
  final String timezone;
  final Uint8List homeKey;
  final String meshId;
  final String meshApPassword;
  const CachedHome({
    required this.homeId,
    required this.name,
    required this.timezone,
    required this.homeKey,
    required this.meshId,
    required this.meshApPassword,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['home_id'] = Variable<String>(homeId);
    map['name'] = Variable<String>(name);
    map['timezone'] = Variable<String>(timezone);
    map['home_key'] = Variable<Uint8List>(homeKey);
    map['mesh_id'] = Variable<String>(meshId);
    map['mesh_ap_password'] = Variable<String>(meshApPassword);
    return map;
  }

  CachedHomesCompanion toCompanion(bool nullToAbsent) {
    return CachedHomesCompanion(
      homeId: Value(homeId),
      name: Value(name),
      timezone: Value(timezone),
      homeKey: Value(homeKey),
      meshId: Value(meshId),
      meshApPassword: Value(meshApPassword),
    );
  }

  factory CachedHome.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedHome(
      homeId: serializer.fromJson<String>(json['homeId']),
      name: serializer.fromJson<String>(json['name']),
      timezone: serializer.fromJson<String>(json['timezone']),
      homeKey: serializer.fromJson<Uint8List>(json['homeKey']),
      meshId: serializer.fromJson<String>(json['meshId']),
      meshApPassword: serializer.fromJson<String>(json['meshApPassword']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'homeId': serializer.toJson<String>(homeId),
      'name': serializer.toJson<String>(name),
      'timezone': serializer.toJson<String>(timezone),
      'homeKey': serializer.toJson<Uint8List>(homeKey),
      'meshId': serializer.toJson<String>(meshId),
      'meshApPassword': serializer.toJson<String>(meshApPassword),
    };
  }

  CachedHome copyWith({
    String? homeId,
    String? name,
    String? timezone,
    Uint8List? homeKey,
    String? meshId,
    String? meshApPassword,
  }) => CachedHome(
    homeId: homeId ?? this.homeId,
    name: name ?? this.name,
    timezone: timezone ?? this.timezone,
    homeKey: homeKey ?? this.homeKey,
    meshId: meshId ?? this.meshId,
    meshApPassword: meshApPassword ?? this.meshApPassword,
  );
  CachedHome copyWithCompanion(CachedHomesCompanion data) {
    return CachedHome(
      homeId: data.homeId.present ? data.homeId.value : this.homeId,
      name: data.name.present ? data.name.value : this.name,
      timezone: data.timezone.present ? data.timezone.value : this.timezone,
      homeKey: data.homeKey.present ? data.homeKey.value : this.homeKey,
      meshId: data.meshId.present ? data.meshId.value : this.meshId,
      meshApPassword: data.meshApPassword.present
          ? data.meshApPassword.value
          : this.meshApPassword,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedHome(')
          ..write('homeId: $homeId, ')
          ..write('name: $name, ')
          ..write('timezone: $timezone, ')
          ..write('homeKey: $homeKey, ')
          ..write('meshId: $meshId, ')
          ..write('meshApPassword: $meshApPassword')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    homeId,
    name,
    timezone,
    $driftBlobEquality.hash(homeKey),
    meshId,
    meshApPassword,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedHome &&
          other.homeId == this.homeId &&
          other.name == this.name &&
          other.timezone == this.timezone &&
          $driftBlobEquality.equals(other.homeKey, this.homeKey) &&
          other.meshId == this.meshId &&
          other.meshApPassword == this.meshApPassword);
}

class CachedHomesCompanion extends UpdateCompanion<CachedHome> {
  final Value<String> homeId;
  final Value<String> name;
  final Value<String> timezone;
  final Value<Uint8List> homeKey;
  final Value<String> meshId;
  final Value<String> meshApPassword;
  final Value<int> rowid;
  const CachedHomesCompanion({
    this.homeId = const Value.absent(),
    this.name = const Value.absent(),
    this.timezone = const Value.absent(),
    this.homeKey = const Value.absent(),
    this.meshId = const Value.absent(),
    this.meshApPassword = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedHomesCompanion.insert({
    required String homeId,
    required String name,
    required String timezone,
    required Uint8List homeKey,
    required String meshId,
    required String meshApPassword,
    this.rowid = const Value.absent(),
  }) : homeId = Value(homeId),
       name = Value(name),
       timezone = Value(timezone),
       homeKey = Value(homeKey),
       meshId = Value(meshId),
       meshApPassword = Value(meshApPassword);
  static Insertable<CachedHome> custom({
    Expression<String>? homeId,
    Expression<String>? name,
    Expression<String>? timezone,
    Expression<Uint8List>? homeKey,
    Expression<String>? meshId,
    Expression<String>? meshApPassword,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (homeId != null) 'home_id': homeId,
      if (name != null) 'name': name,
      if (timezone != null) 'timezone': timezone,
      if (homeKey != null) 'home_key': homeKey,
      if (meshId != null) 'mesh_id': meshId,
      if (meshApPassword != null) 'mesh_ap_password': meshApPassword,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedHomesCompanion copyWith({
    Value<String>? homeId,
    Value<String>? name,
    Value<String>? timezone,
    Value<Uint8List>? homeKey,
    Value<String>? meshId,
    Value<String>? meshApPassword,
    Value<int>? rowid,
  }) {
    return CachedHomesCompanion(
      homeId: homeId ?? this.homeId,
      name: name ?? this.name,
      timezone: timezone ?? this.timezone,
      homeKey: homeKey ?? this.homeKey,
      meshId: meshId ?? this.meshId,
      meshApPassword: meshApPassword ?? this.meshApPassword,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (homeId.present) {
      map['home_id'] = Variable<String>(homeId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (timezone.present) {
      map['timezone'] = Variable<String>(timezone.value);
    }
    if (homeKey.present) {
      map['home_key'] = Variable<Uint8List>(homeKey.value);
    }
    if (meshId.present) {
      map['mesh_id'] = Variable<String>(meshId.value);
    }
    if (meshApPassword.present) {
      map['mesh_ap_password'] = Variable<String>(meshApPassword.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedHomesCompanion(')
          ..write('homeId: $homeId, ')
          ..write('name: $name, ')
          ..write('timezone: $timezone, ')
          ..write('homeKey: $homeKey, ')
          ..write('meshId: $meshId, ')
          ..write('meshApPassword: $meshApPassword, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedRoomsTable extends CachedRooms
    with TableInfo<$CachedRoomsTable, CachedRoom> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedRoomsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _roomIdMeta = const VerificationMeta('roomId');
  @override
  late final GeneratedColumn<String> roomId = GeneratedColumn<String>(
    'room_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _homeIdMeta = const VerificationMeta('homeId');
  @override
  late final GeneratedColumn<String> homeId = GeneratedColumn<String>(
    'home_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _orderIndexMeta = const VerificationMeta(
    'orderIndex',
  );
  @override
  late final GeneratedColumn<int> orderIndex = GeneratedColumn<int>(
    'order_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [roomId, homeId, name, orderIndex];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_rooms';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedRoom> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('room_id')) {
      context.handle(
        _roomIdMeta,
        roomId.isAcceptableOrUnknown(data['room_id']!, _roomIdMeta),
      );
    } else if (isInserting) {
      context.missing(_roomIdMeta);
    }
    if (data.containsKey('home_id')) {
      context.handle(
        _homeIdMeta,
        homeId.isAcceptableOrUnknown(data['home_id']!, _homeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_homeIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('order_index')) {
      context.handle(
        _orderIndexMeta,
        orderIndex.isAcceptableOrUnknown(data['order_index']!, _orderIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_orderIndexMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {roomId};
  @override
  CachedRoom map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedRoom(
      roomId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}room_id'],
      )!,
      homeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}home_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      orderIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order_index'],
      )!,
    );
  }

  @override
  $CachedRoomsTable createAlias(String alias) {
    return $CachedRoomsTable(attachedDatabase, alias);
  }
}

class CachedRoom extends DataClass implements Insertable<CachedRoom> {
  final String roomId;
  final String homeId;
  final String name;
  final int orderIndex;
  const CachedRoom({
    required this.roomId,
    required this.homeId,
    required this.name,
    required this.orderIndex,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['room_id'] = Variable<String>(roomId);
    map['home_id'] = Variable<String>(homeId);
    map['name'] = Variable<String>(name);
    map['order_index'] = Variable<int>(orderIndex);
    return map;
  }

  CachedRoomsCompanion toCompanion(bool nullToAbsent) {
    return CachedRoomsCompanion(
      roomId: Value(roomId),
      homeId: Value(homeId),
      name: Value(name),
      orderIndex: Value(orderIndex),
    );
  }

  factory CachedRoom.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedRoom(
      roomId: serializer.fromJson<String>(json['roomId']),
      homeId: serializer.fromJson<String>(json['homeId']),
      name: serializer.fromJson<String>(json['name']),
      orderIndex: serializer.fromJson<int>(json['orderIndex']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'roomId': serializer.toJson<String>(roomId),
      'homeId': serializer.toJson<String>(homeId),
      'name': serializer.toJson<String>(name),
      'orderIndex': serializer.toJson<int>(orderIndex),
    };
  }

  CachedRoom copyWith({
    String? roomId,
    String? homeId,
    String? name,
    int? orderIndex,
  }) => CachedRoom(
    roomId: roomId ?? this.roomId,
    homeId: homeId ?? this.homeId,
    name: name ?? this.name,
    orderIndex: orderIndex ?? this.orderIndex,
  );
  CachedRoom copyWithCompanion(CachedRoomsCompanion data) {
    return CachedRoom(
      roomId: data.roomId.present ? data.roomId.value : this.roomId,
      homeId: data.homeId.present ? data.homeId.value : this.homeId,
      name: data.name.present ? data.name.value : this.name,
      orderIndex: data.orderIndex.present
          ? data.orderIndex.value
          : this.orderIndex,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedRoom(')
          ..write('roomId: $roomId, ')
          ..write('homeId: $homeId, ')
          ..write('name: $name, ')
          ..write('orderIndex: $orderIndex')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(roomId, homeId, name, orderIndex);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedRoom &&
          other.roomId == this.roomId &&
          other.homeId == this.homeId &&
          other.name == this.name &&
          other.orderIndex == this.orderIndex);
}

class CachedRoomsCompanion extends UpdateCompanion<CachedRoom> {
  final Value<String> roomId;
  final Value<String> homeId;
  final Value<String> name;
  final Value<int> orderIndex;
  final Value<int> rowid;
  const CachedRoomsCompanion({
    this.roomId = const Value.absent(),
    this.homeId = const Value.absent(),
    this.name = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedRoomsCompanion.insert({
    required String roomId,
    required String homeId,
    required String name,
    required int orderIndex,
    this.rowid = const Value.absent(),
  }) : roomId = Value(roomId),
       homeId = Value(homeId),
       name = Value(name),
       orderIndex = Value(orderIndex);
  static Insertable<CachedRoom> custom({
    Expression<String>? roomId,
    Expression<String>? homeId,
    Expression<String>? name,
    Expression<int>? orderIndex,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (roomId != null) 'room_id': roomId,
      if (homeId != null) 'home_id': homeId,
      if (name != null) 'name': name,
      if (orderIndex != null) 'order_index': orderIndex,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedRoomsCompanion copyWith({
    Value<String>? roomId,
    Value<String>? homeId,
    Value<String>? name,
    Value<int>? orderIndex,
    Value<int>? rowid,
  }) {
    return CachedRoomsCompanion(
      roomId: roomId ?? this.roomId,
      homeId: homeId ?? this.homeId,
      name: name ?? this.name,
      orderIndex: orderIndex ?? this.orderIndex,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (roomId.present) {
      map['room_id'] = Variable<String>(roomId.value);
    }
    if (homeId.present) {
      map['home_id'] = Variable<String>(homeId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (orderIndex.present) {
      map['order_index'] = Variable<int>(orderIndex.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedRoomsCompanion(')
          ..write('roomId: $roomId, ')
          ..write('homeId: $homeId, ')
          ..write('name: $name, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedDevicesTable extends CachedDevices
    with TableInfo<$CachedDevicesTable, CachedDevice> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedDevicesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _homeIdMeta = const VerificationMeta('homeId');
  @override
  late final GeneratedColumn<String> homeId = GeneratedColumn<String>(
    'home_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roomIdMeta = const VerificationMeta('roomId');
  @override
  late final GeneratedColumn<String> roomId = GeneratedColumn<String>(
    'room_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _productMeta = const VerificationMeta(
    'product',
  );
  @override
  late final GeneratedColumn<String> product = GeneratedColumn<String>(
    'product',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gangsCountMeta = const VerificationMeta(
    'gangsCount',
  );
  @override
  late final GeneratedColumn<int> gangsCount = GeneratedColumn<int>(
    'gangs_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gangsJsonMeta = const VerificationMeta(
    'gangsJson',
  );
  @override
  late final GeneratedColumn<String> gangsJson = GeneratedColumn<String>(
    'gangs_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fwVersionMeta = const VerificationMeta(
    'fwVersion',
  );
  @override
  late final GeneratedColumn<String> fwVersion = GeneratedColumn<String>(
    'fw_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gatewayIdMeta = const VerificationMeta(
    'gatewayId',
  );
  @override
  late final GeneratedColumn<String> gatewayId = GeneratedColumn<String>(
    'gateway_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    deviceId,
    homeId,
    roomId,
    name,
    product,
    gangsCount,
    gangsJson,
    fwVersion,
    gatewayId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_devices';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedDevice> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('home_id')) {
      context.handle(
        _homeIdMeta,
        homeId.isAcceptableOrUnknown(data['home_id']!, _homeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_homeIdMeta);
    }
    if (data.containsKey('room_id')) {
      context.handle(
        _roomIdMeta,
        roomId.isAcceptableOrUnknown(data['room_id']!, _roomIdMeta),
      );
    } else if (isInserting) {
      context.missing(_roomIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('product')) {
      context.handle(
        _productMeta,
        product.isAcceptableOrUnknown(data['product']!, _productMeta),
      );
    } else if (isInserting) {
      context.missing(_productMeta);
    }
    if (data.containsKey('gangs_count')) {
      context.handle(
        _gangsCountMeta,
        gangsCount.isAcceptableOrUnknown(data['gangs_count']!, _gangsCountMeta),
      );
    } else if (isInserting) {
      context.missing(_gangsCountMeta);
    }
    if (data.containsKey('gangs_json')) {
      context.handle(
        _gangsJsonMeta,
        gangsJson.isAcceptableOrUnknown(data['gangs_json']!, _gangsJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_gangsJsonMeta);
    }
    if (data.containsKey('fw_version')) {
      context.handle(
        _fwVersionMeta,
        fwVersion.isAcceptableOrUnknown(data['fw_version']!, _fwVersionMeta),
      );
    } else if (isInserting) {
      context.missing(_fwVersionMeta);
    }
    if (data.containsKey('gateway_id')) {
      context.handle(
        _gatewayIdMeta,
        gatewayId.isAcceptableOrUnknown(data['gateway_id']!, _gatewayIdMeta),
      );
    } else if (isInserting) {
      context.missing(_gatewayIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {deviceId};
  @override
  CachedDevice map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedDevice(
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      homeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}home_id'],
      )!,
      roomId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}room_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      product: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product'],
      )!,
      gangsCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}gangs_count'],
      )!,
      gangsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gangs_json'],
      )!,
      fwVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fw_version'],
      )!,
      gatewayId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gateway_id'],
      )!,
    );
  }

  @override
  $CachedDevicesTable createAlias(String alias) {
    return $CachedDevicesTable(attachedDatabase, alias);
  }
}

class CachedDevice extends DataClass implements Insertable<CachedDevice> {
  final String deviceId;
  final String homeId;
  final String roomId;
  final String name;
  final String product;
  final int gangsCount;
  final String gangsJson;
  final String fwVersion;
  final String gatewayId;
  const CachedDevice({
    required this.deviceId,
    required this.homeId,
    required this.roomId,
    required this.name,
    required this.product,
    required this.gangsCount,
    required this.gangsJson,
    required this.fwVersion,
    required this.gatewayId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['device_id'] = Variable<String>(deviceId);
    map['home_id'] = Variable<String>(homeId);
    map['room_id'] = Variable<String>(roomId);
    map['name'] = Variable<String>(name);
    map['product'] = Variable<String>(product);
    map['gangs_count'] = Variable<int>(gangsCount);
    map['gangs_json'] = Variable<String>(gangsJson);
    map['fw_version'] = Variable<String>(fwVersion);
    map['gateway_id'] = Variable<String>(gatewayId);
    return map;
  }

  CachedDevicesCompanion toCompanion(bool nullToAbsent) {
    return CachedDevicesCompanion(
      deviceId: Value(deviceId),
      homeId: Value(homeId),
      roomId: Value(roomId),
      name: Value(name),
      product: Value(product),
      gangsCount: Value(gangsCount),
      gangsJson: Value(gangsJson),
      fwVersion: Value(fwVersion),
      gatewayId: Value(gatewayId),
    );
  }

  factory CachedDevice.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedDevice(
      deviceId: serializer.fromJson<String>(json['deviceId']),
      homeId: serializer.fromJson<String>(json['homeId']),
      roomId: serializer.fromJson<String>(json['roomId']),
      name: serializer.fromJson<String>(json['name']),
      product: serializer.fromJson<String>(json['product']),
      gangsCount: serializer.fromJson<int>(json['gangsCount']),
      gangsJson: serializer.fromJson<String>(json['gangsJson']),
      fwVersion: serializer.fromJson<String>(json['fwVersion']),
      gatewayId: serializer.fromJson<String>(json['gatewayId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'deviceId': serializer.toJson<String>(deviceId),
      'homeId': serializer.toJson<String>(homeId),
      'roomId': serializer.toJson<String>(roomId),
      'name': serializer.toJson<String>(name),
      'product': serializer.toJson<String>(product),
      'gangsCount': serializer.toJson<int>(gangsCount),
      'gangsJson': serializer.toJson<String>(gangsJson),
      'fwVersion': serializer.toJson<String>(fwVersion),
      'gatewayId': serializer.toJson<String>(gatewayId),
    };
  }

  CachedDevice copyWith({
    String? deviceId,
    String? homeId,
    String? roomId,
    String? name,
    String? product,
    int? gangsCount,
    String? gangsJson,
    String? fwVersion,
    String? gatewayId,
  }) => CachedDevice(
    deviceId: deviceId ?? this.deviceId,
    homeId: homeId ?? this.homeId,
    roomId: roomId ?? this.roomId,
    name: name ?? this.name,
    product: product ?? this.product,
    gangsCount: gangsCount ?? this.gangsCount,
    gangsJson: gangsJson ?? this.gangsJson,
    fwVersion: fwVersion ?? this.fwVersion,
    gatewayId: gatewayId ?? this.gatewayId,
  );
  CachedDevice copyWithCompanion(CachedDevicesCompanion data) {
    return CachedDevice(
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      homeId: data.homeId.present ? data.homeId.value : this.homeId,
      roomId: data.roomId.present ? data.roomId.value : this.roomId,
      name: data.name.present ? data.name.value : this.name,
      product: data.product.present ? data.product.value : this.product,
      gangsCount: data.gangsCount.present
          ? data.gangsCount.value
          : this.gangsCount,
      gangsJson: data.gangsJson.present ? data.gangsJson.value : this.gangsJson,
      fwVersion: data.fwVersion.present ? data.fwVersion.value : this.fwVersion,
      gatewayId: data.gatewayId.present ? data.gatewayId.value : this.gatewayId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedDevice(')
          ..write('deviceId: $deviceId, ')
          ..write('homeId: $homeId, ')
          ..write('roomId: $roomId, ')
          ..write('name: $name, ')
          ..write('product: $product, ')
          ..write('gangsCount: $gangsCount, ')
          ..write('gangsJson: $gangsJson, ')
          ..write('fwVersion: $fwVersion, ')
          ..write('gatewayId: $gatewayId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    deviceId,
    homeId,
    roomId,
    name,
    product,
    gangsCount,
    gangsJson,
    fwVersion,
    gatewayId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedDevice &&
          other.deviceId == this.deviceId &&
          other.homeId == this.homeId &&
          other.roomId == this.roomId &&
          other.name == this.name &&
          other.product == this.product &&
          other.gangsCount == this.gangsCount &&
          other.gangsJson == this.gangsJson &&
          other.fwVersion == this.fwVersion &&
          other.gatewayId == this.gatewayId);
}

class CachedDevicesCompanion extends UpdateCompanion<CachedDevice> {
  final Value<String> deviceId;
  final Value<String> homeId;
  final Value<String> roomId;
  final Value<String> name;
  final Value<String> product;
  final Value<int> gangsCount;
  final Value<String> gangsJson;
  final Value<String> fwVersion;
  final Value<String> gatewayId;
  final Value<int> rowid;
  const CachedDevicesCompanion({
    this.deviceId = const Value.absent(),
    this.homeId = const Value.absent(),
    this.roomId = const Value.absent(),
    this.name = const Value.absent(),
    this.product = const Value.absent(),
    this.gangsCount = const Value.absent(),
    this.gangsJson = const Value.absent(),
    this.fwVersion = const Value.absent(),
    this.gatewayId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedDevicesCompanion.insert({
    required String deviceId,
    required String homeId,
    required String roomId,
    required String name,
    required String product,
    required int gangsCount,
    required String gangsJson,
    required String fwVersion,
    required String gatewayId,
    this.rowid = const Value.absent(),
  }) : deviceId = Value(deviceId),
       homeId = Value(homeId),
       roomId = Value(roomId),
       name = Value(name),
       product = Value(product),
       gangsCount = Value(gangsCount),
       gangsJson = Value(gangsJson),
       fwVersion = Value(fwVersion),
       gatewayId = Value(gatewayId);
  static Insertable<CachedDevice> custom({
    Expression<String>? deviceId,
    Expression<String>? homeId,
    Expression<String>? roomId,
    Expression<String>? name,
    Expression<String>? product,
    Expression<int>? gangsCount,
    Expression<String>? gangsJson,
    Expression<String>? fwVersion,
    Expression<String>? gatewayId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (deviceId != null) 'device_id': deviceId,
      if (homeId != null) 'home_id': homeId,
      if (roomId != null) 'room_id': roomId,
      if (name != null) 'name': name,
      if (product != null) 'product': product,
      if (gangsCount != null) 'gangs_count': gangsCount,
      if (gangsJson != null) 'gangs_json': gangsJson,
      if (fwVersion != null) 'fw_version': fwVersion,
      if (gatewayId != null) 'gateway_id': gatewayId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedDevicesCompanion copyWith({
    Value<String>? deviceId,
    Value<String>? homeId,
    Value<String>? roomId,
    Value<String>? name,
    Value<String>? product,
    Value<int>? gangsCount,
    Value<String>? gangsJson,
    Value<String>? fwVersion,
    Value<String>? gatewayId,
    Value<int>? rowid,
  }) {
    return CachedDevicesCompanion(
      deviceId: deviceId ?? this.deviceId,
      homeId: homeId ?? this.homeId,
      roomId: roomId ?? this.roomId,
      name: name ?? this.name,
      product: product ?? this.product,
      gangsCount: gangsCount ?? this.gangsCount,
      gangsJson: gangsJson ?? this.gangsJson,
      fwVersion: fwVersion ?? this.fwVersion,
      gatewayId: gatewayId ?? this.gatewayId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (homeId.present) {
      map['home_id'] = Variable<String>(homeId.value);
    }
    if (roomId.present) {
      map['room_id'] = Variable<String>(roomId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (product.present) {
      map['product'] = Variable<String>(product.value);
    }
    if (gangsCount.present) {
      map['gangs_count'] = Variable<int>(gangsCount.value);
    }
    if (gangsJson.present) {
      map['gangs_json'] = Variable<String>(gangsJson.value);
    }
    if (fwVersion.present) {
      map['fw_version'] = Variable<String>(fwVersion.value);
    }
    if (gatewayId.present) {
      map['gateway_id'] = Variable<String>(gatewayId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedDevicesCompanion(')
          ..write('deviceId: $deviceId, ')
          ..write('homeId: $homeId, ')
          ..write('roomId: $roomId, ')
          ..write('name: $name, ')
          ..write('product: $product, ')
          ..write('gangsCount: $gangsCount, ')
          ..write('gangsJson: $gangsJson, ')
          ..write('fwVersion: $fwVersion, ')
          ..write('gatewayId: $gatewayId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedShadowsTable extends CachedShadows
    with TableInfo<$CachedShadowsTable, CachedShadow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedShadowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _desiredJsonMeta = const VerificationMeta(
    'desiredJson',
  );
  @override
  late final GeneratedColumn<String> desiredJson = GeneratedColumn<String>(
    'desired_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reportedJsonMeta = const VerificationMeta(
    'reportedJson',
  );
  @override
  late final GeneratedColumn<String> reportedJson = GeneratedColumn<String>(
    'reported_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _verMeta = const VerificationMeta('ver');
  @override
  late final GeneratedColumn<int> ver = GeneratedColumn<int>(
    'ver',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _onlineMeta = const VerificationMeta('online');
  @override
  late final GeneratedColumn<bool> online = GeneratedColumn<bool>(
    'online',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("online" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    deviceId,
    desiredJson,
    reportedJson,
    ver,
    online,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_shadows';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedShadow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('desired_json')) {
      context.handle(
        _desiredJsonMeta,
        desiredJson.isAcceptableOrUnknown(
          data['desired_json']!,
          _desiredJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_desiredJsonMeta);
    }
    if (data.containsKey('reported_json')) {
      context.handle(
        _reportedJsonMeta,
        reportedJson.isAcceptableOrUnknown(
          data['reported_json']!,
          _reportedJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_reportedJsonMeta);
    }
    if (data.containsKey('ver')) {
      context.handle(
        _verMeta,
        ver.isAcceptableOrUnknown(data['ver']!, _verMeta),
      );
    } else if (isInserting) {
      context.missing(_verMeta);
    }
    if (data.containsKey('online')) {
      context.handle(
        _onlineMeta,
        online.isAcceptableOrUnknown(data['online']!, _onlineMeta),
      );
    } else if (isInserting) {
      context.missing(_onlineMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {deviceId};
  @override
  CachedShadow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedShadow(
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      desiredJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}desired_json'],
      )!,
      reportedJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reported_json'],
      )!,
      ver: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ver'],
      )!,
      online: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}online'],
      )!,
    );
  }

  @override
  $CachedShadowsTable createAlias(String alias) {
    return $CachedShadowsTable(attachedDatabase, alias);
  }
}

class CachedShadow extends DataClass implements Insertable<CachedShadow> {
  final String deviceId;
  final String desiredJson;
  final String reportedJson;
  final int ver;
  final bool online;
  const CachedShadow({
    required this.deviceId,
    required this.desiredJson,
    required this.reportedJson,
    required this.ver,
    required this.online,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['device_id'] = Variable<String>(deviceId);
    map['desired_json'] = Variable<String>(desiredJson);
    map['reported_json'] = Variable<String>(reportedJson);
    map['ver'] = Variable<int>(ver);
    map['online'] = Variable<bool>(online);
    return map;
  }

  CachedShadowsCompanion toCompanion(bool nullToAbsent) {
    return CachedShadowsCompanion(
      deviceId: Value(deviceId),
      desiredJson: Value(desiredJson),
      reportedJson: Value(reportedJson),
      ver: Value(ver),
      online: Value(online),
    );
  }

  factory CachedShadow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedShadow(
      deviceId: serializer.fromJson<String>(json['deviceId']),
      desiredJson: serializer.fromJson<String>(json['desiredJson']),
      reportedJson: serializer.fromJson<String>(json['reportedJson']),
      ver: serializer.fromJson<int>(json['ver']),
      online: serializer.fromJson<bool>(json['online']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'deviceId': serializer.toJson<String>(deviceId),
      'desiredJson': serializer.toJson<String>(desiredJson),
      'reportedJson': serializer.toJson<String>(reportedJson),
      'ver': serializer.toJson<int>(ver),
      'online': serializer.toJson<bool>(online),
    };
  }

  CachedShadow copyWith({
    String? deviceId,
    String? desiredJson,
    String? reportedJson,
    int? ver,
    bool? online,
  }) => CachedShadow(
    deviceId: deviceId ?? this.deviceId,
    desiredJson: desiredJson ?? this.desiredJson,
    reportedJson: reportedJson ?? this.reportedJson,
    ver: ver ?? this.ver,
    online: online ?? this.online,
  );
  CachedShadow copyWithCompanion(CachedShadowsCompanion data) {
    return CachedShadow(
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      desiredJson: data.desiredJson.present
          ? data.desiredJson.value
          : this.desiredJson,
      reportedJson: data.reportedJson.present
          ? data.reportedJson.value
          : this.reportedJson,
      ver: data.ver.present ? data.ver.value : this.ver,
      online: data.online.present ? data.online.value : this.online,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedShadow(')
          ..write('deviceId: $deviceId, ')
          ..write('desiredJson: $desiredJson, ')
          ..write('reportedJson: $reportedJson, ')
          ..write('ver: $ver, ')
          ..write('online: $online')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(deviceId, desiredJson, reportedJson, ver, online);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedShadow &&
          other.deviceId == this.deviceId &&
          other.desiredJson == this.desiredJson &&
          other.reportedJson == this.reportedJson &&
          other.ver == this.ver &&
          other.online == this.online);
}

class CachedShadowsCompanion extends UpdateCompanion<CachedShadow> {
  final Value<String> deviceId;
  final Value<String> desiredJson;
  final Value<String> reportedJson;
  final Value<int> ver;
  final Value<bool> online;
  final Value<int> rowid;
  const CachedShadowsCompanion({
    this.deviceId = const Value.absent(),
    this.desiredJson = const Value.absent(),
    this.reportedJson = const Value.absent(),
    this.ver = const Value.absent(),
    this.online = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedShadowsCompanion.insert({
    required String deviceId,
    required String desiredJson,
    required String reportedJson,
    required int ver,
    required bool online,
    this.rowid = const Value.absent(),
  }) : deviceId = Value(deviceId),
       desiredJson = Value(desiredJson),
       reportedJson = Value(reportedJson),
       ver = Value(ver),
       online = Value(online);
  static Insertable<CachedShadow> custom({
    Expression<String>? deviceId,
    Expression<String>? desiredJson,
    Expression<String>? reportedJson,
    Expression<int>? ver,
    Expression<bool>? online,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (deviceId != null) 'device_id': deviceId,
      if (desiredJson != null) 'desired_json': desiredJson,
      if (reportedJson != null) 'reported_json': reportedJson,
      if (ver != null) 'ver': ver,
      if (online != null) 'online': online,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedShadowsCompanion copyWith({
    Value<String>? deviceId,
    Value<String>? desiredJson,
    Value<String>? reportedJson,
    Value<int>? ver,
    Value<bool>? online,
    Value<int>? rowid,
  }) {
    return CachedShadowsCompanion(
      deviceId: deviceId ?? this.deviceId,
      desiredJson: desiredJson ?? this.desiredJson,
      reportedJson: reportedJson ?? this.reportedJson,
      ver: ver ?? this.ver,
      online: online ?? this.online,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (desiredJson.present) {
      map['desired_json'] = Variable<String>(desiredJson.value);
    }
    if (reportedJson.present) {
      map['reported_json'] = Variable<String>(reportedJson.value);
    }
    if (ver.present) {
      map['ver'] = Variable<int>(ver.value);
    }
    if (online.present) {
      map['online'] = Variable<bool>(online.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedShadowsCompanion(')
          ..write('deviceId: $deviceId, ')
          ..write('desiredJson: $desiredJson, ')
          ..write('reportedJson: $reportedJson, ')
          ..write('ver: $ver, ')
          ..write('online: $online, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedSchedulesTable extends CachedSchedules
    with TableInfo<$CachedSchedulesTable, CachedSchedule> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedSchedulesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _scheduleIdMeta = const VerificationMeta(
    'scheduleId',
  );
  @override
  late final GeneratedColumn<String> scheduleId = GeneratedColumn<String>(
    'schedule_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gangIdMeta = const VerificationMeta('gangId');
  @override
  late final GeneratedColumn<String> gangId = GeneratedColumn<String>(
    'gang_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hourMeta = const VerificationMeta('hour');
  @override
  late final GeneratedColumn<int> hour = GeneratedColumn<int>(
    'hour',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _minuteMeta = const VerificationMeta('minute');
  @override
  late final GeneratedColumn<int> minute = GeneratedColumn<int>(
    'minute',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _repeatDaysJsonMeta = const VerificationMeta(
    'repeatDaysJson',
  );
  @override
  late final GeneratedColumn<String> repeatDaysJson = GeneratedColumn<String>(
    'repeat_days_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
    'action',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isEnabledMeta = const VerificationMeta(
    'isEnabled',
  );
  @override
  late final GeneratedColumn<bool> isEnabled = GeneratedColumn<bool>(
    'is_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_enabled" IN (0, 1))',
    ),
  );
  static const VerificationMeta _syncedToDeviceMeta = const VerificationMeta(
    'syncedToDevice',
  );
  @override
  late final GeneratedColumn<bool> syncedToDevice = GeneratedColumn<bool>(
    'synced_to_device',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("synced_to_device" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    scheduleId,
    deviceId,
    gangId,
    hour,
    minute,
    repeatDaysJson,
    action,
    isEnabled,
    syncedToDevice,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_schedules';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedSchedule> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('schedule_id')) {
      context.handle(
        _scheduleIdMeta,
        scheduleId.isAcceptableOrUnknown(data['schedule_id']!, _scheduleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_scheduleIdMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('gang_id')) {
      context.handle(
        _gangIdMeta,
        gangId.isAcceptableOrUnknown(data['gang_id']!, _gangIdMeta),
      );
    } else if (isInserting) {
      context.missing(_gangIdMeta);
    }
    if (data.containsKey('hour')) {
      context.handle(
        _hourMeta,
        hour.isAcceptableOrUnknown(data['hour']!, _hourMeta),
      );
    } else if (isInserting) {
      context.missing(_hourMeta);
    }
    if (data.containsKey('minute')) {
      context.handle(
        _minuteMeta,
        minute.isAcceptableOrUnknown(data['minute']!, _minuteMeta),
      );
    } else if (isInserting) {
      context.missing(_minuteMeta);
    }
    if (data.containsKey('repeat_days_json')) {
      context.handle(
        _repeatDaysJsonMeta,
        repeatDaysJson.isAcceptableOrUnknown(
          data['repeat_days_json']!,
          _repeatDaysJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_repeatDaysJsonMeta);
    }
    if (data.containsKey('action')) {
      context.handle(
        _actionMeta,
        action.isAcceptableOrUnknown(data['action']!, _actionMeta),
      );
    } else if (isInserting) {
      context.missing(_actionMeta);
    }
    if (data.containsKey('is_enabled')) {
      context.handle(
        _isEnabledMeta,
        isEnabled.isAcceptableOrUnknown(data['is_enabled']!, _isEnabledMeta),
      );
    } else if (isInserting) {
      context.missing(_isEnabledMeta);
    }
    if (data.containsKey('synced_to_device')) {
      context.handle(
        _syncedToDeviceMeta,
        syncedToDevice.isAcceptableOrUnknown(
          data['synced_to_device']!,
          _syncedToDeviceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_syncedToDeviceMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {scheduleId};
  @override
  CachedSchedule map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedSchedule(
      scheduleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}schedule_id'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      gangId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gang_id'],
      )!,
      hour: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hour'],
      )!,
      minute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}minute'],
      )!,
      repeatDaysJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}repeat_days_json'],
      )!,
      action: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action'],
      )!,
      isEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_enabled'],
      )!,
      syncedToDevice: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}synced_to_device'],
      )!,
    );
  }

  @override
  $CachedSchedulesTable createAlias(String alias) {
    return $CachedSchedulesTable(attachedDatabase, alias);
  }
}

class CachedSchedule extends DataClass implements Insertable<CachedSchedule> {
  final String scheduleId;
  final String deviceId;
  final String gangId;
  final int hour;
  final int minute;
  final String repeatDaysJson;
  final String action;
  final bool isEnabled;
  final bool syncedToDevice;
  const CachedSchedule({
    required this.scheduleId,
    required this.deviceId,
    required this.gangId,
    required this.hour,
    required this.minute,
    required this.repeatDaysJson,
    required this.action,
    required this.isEnabled,
    required this.syncedToDevice,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['schedule_id'] = Variable<String>(scheduleId);
    map['device_id'] = Variable<String>(deviceId);
    map['gang_id'] = Variable<String>(gangId);
    map['hour'] = Variable<int>(hour);
    map['minute'] = Variable<int>(minute);
    map['repeat_days_json'] = Variable<String>(repeatDaysJson);
    map['action'] = Variable<String>(action);
    map['is_enabled'] = Variable<bool>(isEnabled);
    map['synced_to_device'] = Variable<bool>(syncedToDevice);
    return map;
  }

  CachedSchedulesCompanion toCompanion(bool nullToAbsent) {
    return CachedSchedulesCompanion(
      scheduleId: Value(scheduleId),
      deviceId: Value(deviceId),
      gangId: Value(gangId),
      hour: Value(hour),
      minute: Value(minute),
      repeatDaysJson: Value(repeatDaysJson),
      action: Value(action),
      isEnabled: Value(isEnabled),
      syncedToDevice: Value(syncedToDevice),
    );
  }

  factory CachedSchedule.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedSchedule(
      scheduleId: serializer.fromJson<String>(json['scheduleId']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      gangId: serializer.fromJson<String>(json['gangId']),
      hour: serializer.fromJson<int>(json['hour']),
      minute: serializer.fromJson<int>(json['minute']),
      repeatDaysJson: serializer.fromJson<String>(json['repeatDaysJson']),
      action: serializer.fromJson<String>(json['action']),
      isEnabled: serializer.fromJson<bool>(json['isEnabled']),
      syncedToDevice: serializer.fromJson<bool>(json['syncedToDevice']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'scheduleId': serializer.toJson<String>(scheduleId),
      'deviceId': serializer.toJson<String>(deviceId),
      'gangId': serializer.toJson<String>(gangId),
      'hour': serializer.toJson<int>(hour),
      'minute': serializer.toJson<int>(minute),
      'repeatDaysJson': serializer.toJson<String>(repeatDaysJson),
      'action': serializer.toJson<String>(action),
      'isEnabled': serializer.toJson<bool>(isEnabled),
      'syncedToDevice': serializer.toJson<bool>(syncedToDevice),
    };
  }

  CachedSchedule copyWith({
    String? scheduleId,
    String? deviceId,
    String? gangId,
    int? hour,
    int? minute,
    String? repeatDaysJson,
    String? action,
    bool? isEnabled,
    bool? syncedToDevice,
  }) => CachedSchedule(
    scheduleId: scheduleId ?? this.scheduleId,
    deviceId: deviceId ?? this.deviceId,
    gangId: gangId ?? this.gangId,
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
    repeatDaysJson: repeatDaysJson ?? this.repeatDaysJson,
    action: action ?? this.action,
    isEnabled: isEnabled ?? this.isEnabled,
    syncedToDevice: syncedToDevice ?? this.syncedToDevice,
  );
  CachedSchedule copyWithCompanion(CachedSchedulesCompanion data) {
    return CachedSchedule(
      scheduleId: data.scheduleId.present
          ? data.scheduleId.value
          : this.scheduleId,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      gangId: data.gangId.present ? data.gangId.value : this.gangId,
      hour: data.hour.present ? data.hour.value : this.hour,
      minute: data.minute.present ? data.minute.value : this.minute,
      repeatDaysJson: data.repeatDaysJson.present
          ? data.repeatDaysJson.value
          : this.repeatDaysJson,
      action: data.action.present ? data.action.value : this.action,
      isEnabled: data.isEnabled.present ? data.isEnabled.value : this.isEnabled,
      syncedToDevice: data.syncedToDevice.present
          ? data.syncedToDevice.value
          : this.syncedToDevice,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedSchedule(')
          ..write('scheduleId: $scheduleId, ')
          ..write('deviceId: $deviceId, ')
          ..write('gangId: $gangId, ')
          ..write('hour: $hour, ')
          ..write('minute: $minute, ')
          ..write('repeatDaysJson: $repeatDaysJson, ')
          ..write('action: $action, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('syncedToDevice: $syncedToDevice')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    scheduleId,
    deviceId,
    gangId,
    hour,
    minute,
    repeatDaysJson,
    action,
    isEnabled,
    syncedToDevice,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedSchedule &&
          other.scheduleId == this.scheduleId &&
          other.deviceId == this.deviceId &&
          other.gangId == this.gangId &&
          other.hour == this.hour &&
          other.minute == this.minute &&
          other.repeatDaysJson == this.repeatDaysJson &&
          other.action == this.action &&
          other.isEnabled == this.isEnabled &&
          other.syncedToDevice == this.syncedToDevice);
}

class CachedSchedulesCompanion extends UpdateCompanion<CachedSchedule> {
  final Value<String> scheduleId;
  final Value<String> deviceId;
  final Value<String> gangId;
  final Value<int> hour;
  final Value<int> minute;
  final Value<String> repeatDaysJson;
  final Value<String> action;
  final Value<bool> isEnabled;
  final Value<bool> syncedToDevice;
  final Value<int> rowid;
  const CachedSchedulesCompanion({
    this.scheduleId = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.gangId = const Value.absent(),
    this.hour = const Value.absent(),
    this.minute = const Value.absent(),
    this.repeatDaysJson = const Value.absent(),
    this.action = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.syncedToDevice = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedSchedulesCompanion.insert({
    required String scheduleId,
    required String deviceId,
    required String gangId,
    required int hour,
    required int minute,
    required String repeatDaysJson,
    required String action,
    required bool isEnabled,
    required bool syncedToDevice,
    this.rowid = const Value.absent(),
  }) : scheduleId = Value(scheduleId),
       deviceId = Value(deviceId),
       gangId = Value(gangId),
       hour = Value(hour),
       minute = Value(minute),
       repeatDaysJson = Value(repeatDaysJson),
       action = Value(action),
       isEnabled = Value(isEnabled),
       syncedToDevice = Value(syncedToDevice);
  static Insertable<CachedSchedule> custom({
    Expression<String>? scheduleId,
    Expression<String>? deviceId,
    Expression<String>? gangId,
    Expression<int>? hour,
    Expression<int>? minute,
    Expression<String>? repeatDaysJson,
    Expression<String>? action,
    Expression<bool>? isEnabled,
    Expression<bool>? syncedToDevice,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (scheduleId != null) 'schedule_id': scheduleId,
      if (deviceId != null) 'device_id': deviceId,
      if (gangId != null) 'gang_id': gangId,
      if (hour != null) 'hour': hour,
      if (minute != null) 'minute': minute,
      if (repeatDaysJson != null) 'repeat_days_json': repeatDaysJson,
      if (action != null) 'action': action,
      if (isEnabled != null) 'is_enabled': isEnabled,
      if (syncedToDevice != null) 'synced_to_device': syncedToDevice,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedSchedulesCompanion copyWith({
    Value<String>? scheduleId,
    Value<String>? deviceId,
    Value<String>? gangId,
    Value<int>? hour,
    Value<int>? minute,
    Value<String>? repeatDaysJson,
    Value<String>? action,
    Value<bool>? isEnabled,
    Value<bool>? syncedToDevice,
    Value<int>? rowid,
  }) {
    return CachedSchedulesCompanion(
      scheduleId: scheduleId ?? this.scheduleId,
      deviceId: deviceId ?? this.deviceId,
      gangId: gangId ?? this.gangId,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      repeatDaysJson: repeatDaysJson ?? this.repeatDaysJson,
      action: action ?? this.action,
      isEnabled: isEnabled ?? this.isEnabled,
      syncedToDevice: syncedToDevice ?? this.syncedToDevice,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (scheduleId.present) {
      map['schedule_id'] = Variable<String>(scheduleId.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (gangId.present) {
      map['gang_id'] = Variable<String>(gangId.value);
    }
    if (hour.present) {
      map['hour'] = Variable<int>(hour.value);
    }
    if (minute.present) {
      map['minute'] = Variable<int>(minute.value);
    }
    if (repeatDaysJson.present) {
      map['repeat_days_json'] = Variable<String>(repeatDaysJson.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (isEnabled.present) {
      map['is_enabled'] = Variable<bool>(isEnabled.value);
    }
    if (syncedToDevice.present) {
      map['synced_to_device'] = Variable<bool>(syncedToDevice.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedSchedulesCompanion(')
          ..write('scheduleId: $scheduleId, ')
          ..write('deviceId: $deviceId, ')
          ..write('gangId: $gangId, ')
          ..write('hour: $hour, ')
          ..write('minute: $minute, ')
          ..write('repeatDaysJson: $repeatDaysJson, ')
          ..write('action: $action, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('syncedToDevice: $syncedToDevice, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CachedHomesTable cachedHomes = $CachedHomesTable(this);
  late final $CachedRoomsTable cachedRooms = $CachedRoomsTable(this);
  late final $CachedDevicesTable cachedDevices = $CachedDevicesTable(this);
  late final $CachedShadowsTable cachedShadows = $CachedShadowsTable(this);
  late final $CachedSchedulesTable cachedSchedules = $CachedSchedulesTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    cachedHomes,
    cachedRooms,
    cachedDevices,
    cachedShadows,
    cachedSchedules,
  ];
}

typedef $$CachedHomesTableCreateCompanionBuilder =
    CachedHomesCompanion Function({
      required String homeId,
      required String name,
      required String timezone,
      required Uint8List homeKey,
      required String meshId,
      required String meshApPassword,
      Value<int> rowid,
    });
typedef $$CachedHomesTableUpdateCompanionBuilder =
    CachedHomesCompanion Function({
      Value<String> homeId,
      Value<String> name,
      Value<String> timezone,
      Value<Uint8List> homeKey,
      Value<String> meshId,
      Value<String> meshApPassword,
      Value<int> rowid,
    });

class $$CachedHomesTableFilterComposer
    extends Composer<_$AppDatabase, $CachedHomesTable> {
  $$CachedHomesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get homeId => $composableBuilder(
    column: $table.homeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timezone => $composableBuilder(
    column: $table.timezone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get homeKey => $composableBuilder(
    column: $table.homeKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get meshId => $composableBuilder(
    column: $table.meshId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get meshApPassword => $composableBuilder(
    column: $table.meshApPassword,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedHomesTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedHomesTable> {
  $$CachedHomesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get homeId => $composableBuilder(
    column: $table.homeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timezone => $composableBuilder(
    column: $table.timezone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get homeKey => $composableBuilder(
    column: $table.homeKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get meshId => $composableBuilder(
    column: $table.meshId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get meshApPassword => $composableBuilder(
    column: $table.meshApPassword,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedHomesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedHomesTable> {
  $$CachedHomesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get homeId =>
      $composableBuilder(column: $table.homeId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get timezone =>
      $composableBuilder(column: $table.timezone, builder: (column) => column);

  GeneratedColumn<Uint8List> get homeKey =>
      $composableBuilder(column: $table.homeKey, builder: (column) => column);

  GeneratedColumn<String> get meshId =>
      $composableBuilder(column: $table.meshId, builder: (column) => column);

  GeneratedColumn<String> get meshApPassword => $composableBuilder(
    column: $table.meshApPassword,
    builder: (column) => column,
  );
}

class $$CachedHomesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedHomesTable,
          CachedHome,
          $$CachedHomesTableFilterComposer,
          $$CachedHomesTableOrderingComposer,
          $$CachedHomesTableAnnotationComposer,
          $$CachedHomesTableCreateCompanionBuilder,
          $$CachedHomesTableUpdateCompanionBuilder,
          (
            CachedHome,
            BaseReferences<_$AppDatabase, $CachedHomesTable, CachedHome>,
          ),
          CachedHome,
          PrefetchHooks Function()
        > {
  $$CachedHomesTableTableManager(_$AppDatabase db, $CachedHomesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedHomesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedHomesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedHomesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> homeId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> timezone = const Value.absent(),
                Value<Uint8List> homeKey = const Value.absent(),
                Value<String> meshId = const Value.absent(),
                Value<String> meshApPassword = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedHomesCompanion(
                homeId: homeId,
                name: name,
                timezone: timezone,
                homeKey: homeKey,
                meshId: meshId,
                meshApPassword: meshApPassword,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String homeId,
                required String name,
                required String timezone,
                required Uint8List homeKey,
                required String meshId,
                required String meshApPassword,
                Value<int> rowid = const Value.absent(),
              }) => CachedHomesCompanion.insert(
                homeId: homeId,
                name: name,
                timezone: timezone,
                homeKey: homeKey,
                meshId: meshId,
                meshApPassword: meshApPassword,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CachedHomesTable, CachedHome>(table),
                  BaseReferences<_$AppDatabase, $CachedHomesTable, CachedHome>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedHomesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedHomesTable,
      CachedHome,
      $$CachedHomesTableFilterComposer,
      $$CachedHomesTableOrderingComposer,
      $$CachedHomesTableAnnotationComposer,
      $$CachedHomesTableCreateCompanionBuilder,
      $$CachedHomesTableUpdateCompanionBuilder,
      (
        CachedHome,
        BaseReferences<_$AppDatabase, $CachedHomesTable, CachedHome>,
      ),
      CachedHome,
      PrefetchHooks Function()
    >;
typedef $$CachedRoomsTableCreateCompanionBuilder =
    CachedRoomsCompanion Function({
      required String roomId,
      required String homeId,
      required String name,
      required int orderIndex,
      Value<int> rowid,
    });
typedef $$CachedRoomsTableUpdateCompanionBuilder =
    CachedRoomsCompanion Function({
      Value<String> roomId,
      Value<String> homeId,
      Value<String> name,
      Value<int> orderIndex,
      Value<int> rowid,
    });

class $$CachedRoomsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedRoomsTable> {
  $$CachedRoomsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get roomId => $composableBuilder(
    column: $table.roomId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get homeId => $composableBuilder(
    column: $table.homeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedRoomsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedRoomsTable> {
  $$CachedRoomsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get roomId => $composableBuilder(
    column: $table.roomId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get homeId => $composableBuilder(
    column: $table.homeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedRoomsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedRoomsTable> {
  $$CachedRoomsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get roomId =>
      $composableBuilder(column: $table.roomId, builder: (column) => column);

  GeneratedColumn<String> get homeId =>
      $composableBuilder(column: $table.homeId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => column,
  );
}

class $$CachedRoomsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedRoomsTable,
          CachedRoom,
          $$CachedRoomsTableFilterComposer,
          $$CachedRoomsTableOrderingComposer,
          $$CachedRoomsTableAnnotationComposer,
          $$CachedRoomsTableCreateCompanionBuilder,
          $$CachedRoomsTableUpdateCompanionBuilder,
          (
            CachedRoom,
            BaseReferences<_$AppDatabase, $CachedRoomsTable, CachedRoom>,
          ),
          CachedRoom,
          PrefetchHooks Function()
        > {
  $$CachedRoomsTableTableManager(_$AppDatabase db, $CachedRoomsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedRoomsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedRoomsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedRoomsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> roomId = const Value.absent(),
                Value<String> homeId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedRoomsCompanion(
                roomId: roomId,
                homeId: homeId,
                name: name,
                orderIndex: orderIndex,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String roomId,
                required String homeId,
                required String name,
                required int orderIndex,
                Value<int> rowid = const Value.absent(),
              }) => CachedRoomsCompanion.insert(
                roomId: roomId,
                homeId: homeId,
                name: name,
                orderIndex: orderIndex,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CachedRoomsTable, CachedRoom>(table),
                  BaseReferences<_$AppDatabase, $CachedRoomsTable, CachedRoom>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedRoomsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedRoomsTable,
      CachedRoom,
      $$CachedRoomsTableFilterComposer,
      $$CachedRoomsTableOrderingComposer,
      $$CachedRoomsTableAnnotationComposer,
      $$CachedRoomsTableCreateCompanionBuilder,
      $$CachedRoomsTableUpdateCompanionBuilder,
      (
        CachedRoom,
        BaseReferences<_$AppDatabase, $CachedRoomsTable, CachedRoom>,
      ),
      CachedRoom,
      PrefetchHooks Function()
    >;
typedef $$CachedDevicesTableCreateCompanionBuilder =
    CachedDevicesCompanion Function({
      required String deviceId,
      required String homeId,
      required String roomId,
      required String name,
      required String product,
      required int gangsCount,
      required String gangsJson,
      required String fwVersion,
      required String gatewayId,
      Value<int> rowid,
    });
typedef $$CachedDevicesTableUpdateCompanionBuilder =
    CachedDevicesCompanion Function({
      Value<String> deviceId,
      Value<String> homeId,
      Value<String> roomId,
      Value<String> name,
      Value<String> product,
      Value<int> gangsCount,
      Value<String> gangsJson,
      Value<String> fwVersion,
      Value<String> gatewayId,
      Value<int> rowid,
    });

class $$CachedDevicesTableFilterComposer
    extends Composer<_$AppDatabase, $CachedDevicesTable> {
  $$CachedDevicesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get homeId => $composableBuilder(
    column: $table.homeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get roomId => $composableBuilder(
    column: $table.roomId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get product => $composableBuilder(
    column: $table.product,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get gangsCount => $composableBuilder(
    column: $table.gangsCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gangsJson => $composableBuilder(
    column: $table.gangsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fwVersion => $composableBuilder(
    column: $table.fwVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gatewayId => $composableBuilder(
    column: $table.gatewayId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedDevicesTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedDevicesTable> {
  $$CachedDevicesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get homeId => $composableBuilder(
    column: $table.homeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get roomId => $composableBuilder(
    column: $table.roomId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get product => $composableBuilder(
    column: $table.product,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get gangsCount => $composableBuilder(
    column: $table.gangsCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gangsJson => $composableBuilder(
    column: $table.gangsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fwVersion => $composableBuilder(
    column: $table.fwVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gatewayId => $composableBuilder(
    column: $table.gatewayId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedDevicesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedDevicesTable> {
  $$CachedDevicesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get homeId =>
      $composableBuilder(column: $table.homeId, builder: (column) => column);

  GeneratedColumn<String> get roomId =>
      $composableBuilder(column: $table.roomId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get product =>
      $composableBuilder(column: $table.product, builder: (column) => column);

  GeneratedColumn<int> get gangsCount => $composableBuilder(
    column: $table.gangsCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get gangsJson =>
      $composableBuilder(column: $table.gangsJson, builder: (column) => column);

  GeneratedColumn<String> get fwVersion =>
      $composableBuilder(column: $table.fwVersion, builder: (column) => column);

  GeneratedColumn<String> get gatewayId =>
      $composableBuilder(column: $table.gatewayId, builder: (column) => column);
}

class $$CachedDevicesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedDevicesTable,
          CachedDevice,
          $$CachedDevicesTableFilterComposer,
          $$CachedDevicesTableOrderingComposer,
          $$CachedDevicesTableAnnotationComposer,
          $$CachedDevicesTableCreateCompanionBuilder,
          $$CachedDevicesTableUpdateCompanionBuilder,
          (
            CachedDevice,
            BaseReferences<_$AppDatabase, $CachedDevicesTable, CachedDevice>,
          ),
          CachedDevice,
          PrefetchHooks Function()
        > {
  $$CachedDevicesTableTableManager(_$AppDatabase db, $CachedDevicesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedDevicesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedDevicesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedDevicesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> deviceId = const Value.absent(),
                Value<String> homeId = const Value.absent(),
                Value<String> roomId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> product = const Value.absent(),
                Value<int> gangsCount = const Value.absent(),
                Value<String> gangsJson = const Value.absent(),
                Value<String> fwVersion = const Value.absent(),
                Value<String> gatewayId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedDevicesCompanion(
                deviceId: deviceId,
                homeId: homeId,
                roomId: roomId,
                name: name,
                product: product,
                gangsCount: gangsCount,
                gangsJson: gangsJson,
                fwVersion: fwVersion,
                gatewayId: gatewayId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String deviceId,
                required String homeId,
                required String roomId,
                required String name,
                required String product,
                required int gangsCount,
                required String gangsJson,
                required String fwVersion,
                required String gatewayId,
                Value<int> rowid = const Value.absent(),
              }) => CachedDevicesCompanion.insert(
                deviceId: deviceId,
                homeId: homeId,
                roomId: roomId,
                name: name,
                product: product,
                gangsCount: gangsCount,
                gangsJson: gangsJson,
                fwVersion: fwVersion,
                gatewayId: gatewayId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CachedDevicesTable, CachedDevice>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $CachedDevicesTable,
                    CachedDevice
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedDevicesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedDevicesTable,
      CachedDevice,
      $$CachedDevicesTableFilterComposer,
      $$CachedDevicesTableOrderingComposer,
      $$CachedDevicesTableAnnotationComposer,
      $$CachedDevicesTableCreateCompanionBuilder,
      $$CachedDevicesTableUpdateCompanionBuilder,
      (
        CachedDevice,
        BaseReferences<_$AppDatabase, $CachedDevicesTable, CachedDevice>,
      ),
      CachedDevice,
      PrefetchHooks Function()
    >;
typedef $$CachedShadowsTableCreateCompanionBuilder =
    CachedShadowsCompanion Function({
      required String deviceId,
      required String desiredJson,
      required String reportedJson,
      required int ver,
      required bool online,
      Value<int> rowid,
    });
typedef $$CachedShadowsTableUpdateCompanionBuilder =
    CachedShadowsCompanion Function({
      Value<String> deviceId,
      Value<String> desiredJson,
      Value<String> reportedJson,
      Value<int> ver,
      Value<bool> online,
      Value<int> rowid,
    });

class $$CachedShadowsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedShadowsTable> {
  $$CachedShadowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get desiredJson => $composableBuilder(
    column: $table.desiredJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reportedJson => $composableBuilder(
    column: $table.reportedJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ver => $composableBuilder(
    column: $table.ver,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get online => $composableBuilder(
    column: $table.online,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedShadowsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedShadowsTable> {
  $$CachedShadowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get desiredJson => $composableBuilder(
    column: $table.desiredJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reportedJson => $composableBuilder(
    column: $table.reportedJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ver => $composableBuilder(
    column: $table.ver,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get online => $composableBuilder(
    column: $table.online,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedShadowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedShadowsTable> {
  $$CachedShadowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get desiredJson => $composableBuilder(
    column: $table.desiredJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reportedJson => $composableBuilder(
    column: $table.reportedJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get ver =>
      $composableBuilder(column: $table.ver, builder: (column) => column);

  GeneratedColumn<bool> get online =>
      $composableBuilder(column: $table.online, builder: (column) => column);
}

class $$CachedShadowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedShadowsTable,
          CachedShadow,
          $$CachedShadowsTableFilterComposer,
          $$CachedShadowsTableOrderingComposer,
          $$CachedShadowsTableAnnotationComposer,
          $$CachedShadowsTableCreateCompanionBuilder,
          $$CachedShadowsTableUpdateCompanionBuilder,
          (
            CachedShadow,
            BaseReferences<_$AppDatabase, $CachedShadowsTable, CachedShadow>,
          ),
          CachedShadow,
          PrefetchHooks Function()
        > {
  $$CachedShadowsTableTableManager(_$AppDatabase db, $CachedShadowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedShadowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedShadowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedShadowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> deviceId = const Value.absent(),
                Value<String> desiredJson = const Value.absent(),
                Value<String> reportedJson = const Value.absent(),
                Value<int> ver = const Value.absent(),
                Value<bool> online = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedShadowsCompanion(
                deviceId: deviceId,
                desiredJson: desiredJson,
                reportedJson: reportedJson,
                ver: ver,
                online: online,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String deviceId,
                required String desiredJson,
                required String reportedJson,
                required int ver,
                required bool online,
                Value<int> rowid = const Value.absent(),
              }) => CachedShadowsCompanion.insert(
                deviceId: deviceId,
                desiredJson: desiredJson,
                reportedJson: reportedJson,
                ver: ver,
                online: online,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CachedShadowsTable, CachedShadow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $CachedShadowsTable,
                    CachedShadow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedShadowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedShadowsTable,
      CachedShadow,
      $$CachedShadowsTableFilterComposer,
      $$CachedShadowsTableOrderingComposer,
      $$CachedShadowsTableAnnotationComposer,
      $$CachedShadowsTableCreateCompanionBuilder,
      $$CachedShadowsTableUpdateCompanionBuilder,
      (
        CachedShadow,
        BaseReferences<_$AppDatabase, $CachedShadowsTable, CachedShadow>,
      ),
      CachedShadow,
      PrefetchHooks Function()
    >;
typedef $$CachedSchedulesTableCreateCompanionBuilder =
    CachedSchedulesCompanion Function({
      required String scheduleId,
      required String deviceId,
      required String gangId,
      required int hour,
      required int minute,
      required String repeatDaysJson,
      required String action,
      required bool isEnabled,
      required bool syncedToDevice,
      Value<int> rowid,
    });
typedef $$CachedSchedulesTableUpdateCompanionBuilder =
    CachedSchedulesCompanion Function({
      Value<String> scheduleId,
      Value<String> deviceId,
      Value<String> gangId,
      Value<int> hour,
      Value<int> minute,
      Value<String> repeatDaysJson,
      Value<String> action,
      Value<bool> isEnabled,
      Value<bool> syncedToDevice,
      Value<int> rowid,
    });

class $$CachedSchedulesTableFilterComposer
    extends Composer<_$AppDatabase, $CachedSchedulesTable> {
  $$CachedSchedulesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get scheduleId => $composableBuilder(
    column: $table.scheduleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gangId => $composableBuilder(
    column: $table.gangId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get hour => $composableBuilder(
    column: $table.hour,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get minute => $composableBuilder(
    column: $table.minute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get repeatDaysJson => $composableBuilder(
    column: $table.repeatDaysJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get syncedToDevice => $composableBuilder(
    column: $table.syncedToDevice,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedSchedulesTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedSchedulesTable> {
  $$CachedSchedulesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get scheduleId => $composableBuilder(
    column: $table.scheduleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gangId => $composableBuilder(
    column: $table.gangId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hour => $composableBuilder(
    column: $table.hour,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get minute => $composableBuilder(
    column: $table.minute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get repeatDaysJson => $composableBuilder(
    column: $table.repeatDaysJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get syncedToDevice => $composableBuilder(
    column: $table.syncedToDevice,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedSchedulesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedSchedulesTable> {
  $$CachedSchedulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get scheduleId => $composableBuilder(
    column: $table.scheduleId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get gangId =>
      $composableBuilder(column: $table.gangId, builder: (column) => column);

  GeneratedColumn<int> get hour =>
      $composableBuilder(column: $table.hour, builder: (column) => column);

  GeneratedColumn<int> get minute =>
      $composableBuilder(column: $table.minute, builder: (column) => column);

  GeneratedColumn<String> get repeatDaysJson => $composableBuilder(
    column: $table.repeatDaysJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<bool> get isEnabled =>
      $composableBuilder(column: $table.isEnabled, builder: (column) => column);

  GeneratedColumn<bool> get syncedToDevice => $composableBuilder(
    column: $table.syncedToDevice,
    builder: (column) => column,
  );
}

class $$CachedSchedulesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedSchedulesTable,
          CachedSchedule,
          $$CachedSchedulesTableFilterComposer,
          $$CachedSchedulesTableOrderingComposer,
          $$CachedSchedulesTableAnnotationComposer,
          $$CachedSchedulesTableCreateCompanionBuilder,
          $$CachedSchedulesTableUpdateCompanionBuilder,
          (
            CachedSchedule,
            BaseReferences<
              _$AppDatabase,
              $CachedSchedulesTable,
              CachedSchedule
            >,
          ),
          CachedSchedule,
          PrefetchHooks Function()
        > {
  $$CachedSchedulesTableTableManager(
    _$AppDatabase db,
    $CachedSchedulesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedSchedulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedSchedulesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedSchedulesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> scheduleId = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<String> gangId = const Value.absent(),
                Value<int> hour = const Value.absent(),
                Value<int> minute = const Value.absent(),
                Value<String> repeatDaysJson = const Value.absent(),
                Value<String> action = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<bool> syncedToDevice = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedSchedulesCompanion(
                scheduleId: scheduleId,
                deviceId: deviceId,
                gangId: gangId,
                hour: hour,
                minute: minute,
                repeatDaysJson: repeatDaysJson,
                action: action,
                isEnabled: isEnabled,
                syncedToDevice: syncedToDevice,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String scheduleId,
                required String deviceId,
                required String gangId,
                required int hour,
                required int minute,
                required String repeatDaysJson,
                required String action,
                required bool isEnabled,
                required bool syncedToDevice,
                Value<int> rowid = const Value.absent(),
              }) => CachedSchedulesCompanion.insert(
                scheduleId: scheduleId,
                deviceId: deviceId,
                gangId: gangId,
                hour: hour,
                minute: minute,
                repeatDaysJson: repeatDaysJson,
                action: action,
                isEnabled: isEnabled,
                syncedToDevice: syncedToDevice,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CachedSchedulesTable, CachedSchedule>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $CachedSchedulesTable,
                    CachedSchedule
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedSchedulesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedSchedulesTable,
      CachedSchedule,
      $$CachedSchedulesTableFilterComposer,
      $$CachedSchedulesTableOrderingComposer,
      $$CachedSchedulesTableAnnotationComposer,
      $$CachedSchedulesTableCreateCompanionBuilder,
      $$CachedSchedulesTableUpdateCompanionBuilder,
      (
        CachedSchedule,
        BaseReferences<_$AppDatabase, $CachedSchedulesTable, CachedSchedule>,
      ),
      CachedSchedule,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CachedHomesTableTableManager get cachedHomes =>
      $$CachedHomesTableTableManager(_db, _db.cachedHomes);
  $$CachedRoomsTableTableManager get cachedRooms =>
      $$CachedRoomsTableTableManager(_db, _db.cachedRooms);
  $$CachedDevicesTableTableManager get cachedDevices =>
      $$CachedDevicesTableTableManager(_db, _db.cachedDevices);
  $$CachedShadowsTableTableManager get cachedShadows =>
      $$CachedShadowsTableTableManager(_db, _db.cachedShadows);
  $$CachedSchedulesTableTableManager get cachedSchedules =>
      $$CachedSchedulesTableTableManager(_db, _db.cachedSchedules);
}
