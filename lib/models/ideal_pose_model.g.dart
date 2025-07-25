// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ideal_pose_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class IdealPoseAdapter extends TypeAdapter<IdealPose> {
  @override
  final int typeId = 4;

  @override
  IdealPose read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return IdealPose(
      idealImagePath: fields[0] as String,
      idealPoseLandmarks: (fields[1] as List).cast<dynamic>(),
      imageWidth: fields[2] as double,
      imageHeight: fields[3] as double,
    );
  }

  @override
  void write(BinaryWriter writer, IdealPose obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.idealImagePath)
      ..writeByte(1)
      ..write(obj.idealPoseLandmarks)
      ..writeByte(2)
      ..write(obj.imageWidth)
      ..writeByte(3)
      ..write(obj.imageHeight);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IdealPoseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
