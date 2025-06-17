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
