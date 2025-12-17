// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'analysis_session.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PoseLandmarkTypeAdapterAdapter
    extends TypeAdapter<PoseLandmarkTypeAdapter> {
  @override
  final int typeId = 3;

  @override
  PoseLandmarkTypeAdapter read(BinaryReader reader) {
    return PoseLandmarkTypeAdapter();
  }

  @override
  void write(BinaryWriter writer, PoseLandmarkTypeAdapter obj) {
    writer.writeByte(0);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PoseLandmarkTypeAdapterAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

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
      videoPath: fields[13] as String?,
      analysisType: fields[14] as String?,
      idealVideoPath: fields[15] as String?,
      idealStartTimeMs: fields[16] as double?,
      idealEndTimeMs: fields[17] as double?,
      userStartTimeMs: fields[18] as double?,
      userEndTimeMs: fields[19] as double?,
      idealSSEAngle: fields[20] as double?,
      userSSEAngle: fields[21] as double?,
      shoulderScore: fields[26] as double?,
      hipScore: fields[27] as double?,
      elbowScore: fields[28] as double?,
      kneeScore: fields[29] as double?,
      idealBodyTilt: fields[30] as double?,
      userBodyTilt: fields[31] as double?,
      idealWeightShift: fields[32] as double?,
      userWeightShift: fields[33] as double?,
      idealHeadStability: fields[34] as double?,
      userHeadStability: fields[35] as double?,
      idealXFactorAngle: fields[22] as double?,
      userXFactorAngle: fields[23] as double?,
      idealElbowAngle: fields[24] as double?,
      userElbowAngle: fields[25] as double?,
      idealReleaseHeight: fields[36] as double?,
      userReleaseHeight: fields[37] as double?,
      idealReleaseSide: fields[38] as double?,
      userReleaseSide: fields[39] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, AnalysisSession obj) {
    writer
      ..writeByte(40)
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
      ..write(obj.imageRotation)
      ..writeByte(13)
      ..write(obj.videoPath)
      ..writeByte(14)
      ..write(obj.analysisType)
      ..writeByte(15)
      ..write(obj.idealVideoPath)
      ..writeByte(16)
      ..write(obj.idealStartTimeMs)
      ..writeByte(17)
      ..write(obj.idealEndTimeMs)
      ..writeByte(18)
      ..write(obj.userStartTimeMs)
      ..writeByte(19)
      ..write(obj.userEndTimeMs)
      ..writeByte(20)
      ..write(obj.idealSSEAngle)
      ..writeByte(21)
      ..write(obj.userSSEAngle)
      ..writeByte(30)
      ..write(obj.idealBodyTilt)
      ..writeByte(31)
      ..write(obj.userBodyTilt)
      ..writeByte(32)
      ..write(obj.idealWeightShift)
      ..writeByte(33)
      ..write(obj.userWeightShift)
      ..writeByte(34)
      ..write(obj.idealHeadStability)
      ..writeByte(35)
      ..write(obj.userHeadStability)
      ..writeByte(26)
      ..write(obj.shoulderScore)
      ..writeByte(27)
      ..write(obj.hipScore)
      ..writeByte(28)
      ..write(obj.elbowScore)
      ..writeByte(29)
      ..write(obj.kneeScore)
      ..writeByte(22)
      ..write(obj.idealXFactorAngle)
      ..writeByte(23)
      ..write(obj.userXFactorAngle)
      ..writeByte(24)
      ..write(obj.idealElbowAngle)
      ..writeByte(25)
      ..write(obj.userElbowAngle)
      ..writeByte(36)
      ..write(obj.idealReleaseHeight)
      ..writeByte(37)
      ..write(obj.userReleaseHeight)
      ..writeByte(38)
      ..write(obj.idealReleaseSide)
      ..writeByte(39)
      ..write(obj.userReleaseSide);
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
