// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hive_adapters.dart';

// **************************************************************************
// AdaptersGenerator
// **************************************************************************

class HiveLatLngAdapter extends TypeAdapter<HiveLatLng> {
  @override
  final typeId = 0;

  @override
  HiveLatLng read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HiveLatLng(
      lat: (fields[0] as num).toDouble(),
      long: (fields[1] as num).toDouble(),
    );
  }

  @override
  void write(BinaryWriter writer, HiveLatLng obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.lat)
      ..writeByte(1)
      ..write(obj.long);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiveLatLngAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class UserStateAdapter extends TypeAdapter<UserState> {
  @override
  final typeId = 1;

  @override
  UserState read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserState(
      coords: fields[0] as HiveLatLng,
      ts: (fields[1] as num).toInt(),
      name: fields[2] as String,
      color: (fields[3] as num).toInt(),
    );
  }

  @override
  void write(BinaryWriter writer, UserState obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.coords)
      ..writeByte(1)
      ..write(obj.ts)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.color);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserStateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
