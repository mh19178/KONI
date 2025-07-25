// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'analysis_session.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AnalysisSessionAdapter extends TypeAdapter<AnalysisSession> {
  @override
  final int typeId = 2;

  @override
  AnalysisSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AnalysisSession(
      id: fields[0] as String,
      createdAt: fields[1] as DateTime,
      imagePath: fields[2] as String,
      idealImagePath: fields[6] as String,
      score: fields[3] as double,
      userPoseLandmarks: (fields[4] as List).cast<dynamic>(),
      idealPoseLandmarks: (fields[5] as List).cast<dynamic>(),
      coachComment: fields[7] as String?,
      imageWidth: fields[8] as double,
      imageHeight: fields[9] as double,
      idealImageWidth: fields[10] as double,
      idealImageHeight: fields[11] as double,
      imageRotation: fields[12] as int,
    );
  }

  @override
  void write(BinaryWriter writer, AnalysisSession obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.createdAt)
      ..writeByte(2)
      ..write(obj.imagePath)
      ..writeByte(3)
      ..write(obj.score)
      ..writeByte(4)
      ..write(obj.userPoseLandmarks)
      ..writeByte(5)
      ..write(obj.idealPoseLandmarks)
      ..writeByte(6)
      ..write(obj.idealImagePath)
      ..writeByte(7)
      ..write(obj.coachComment)
      ..writeByte(8)
      ..write(obj.imageWidth)
      ..writeByte(9)
      ..write(obj.imageHeight)
      ..writeByte(10)
      ..write(obj.idealImageWidth)
      ..writeByte(11)
      ..write(obj.idealImageHeight)
      ..writeByte(12)
      ..write(obj.imageRotation);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnalysisSessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
