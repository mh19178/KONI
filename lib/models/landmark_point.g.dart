// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'landmark_point.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LandmarkPointAdapter extends TypeAdapter<LandmarkPoint> {
  @override
  final int typeId = 1;

  @override
  LandmarkPoint read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LandmarkPoint(
      x: fields[0] as double,
      y: fields[1] as double,
    );
  }

  @override
  void write(BinaryWriter writer, LandmarkPoint obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.x)
      ..writeByte(1)
      ..write(obj.y);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LandmarkPointAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
