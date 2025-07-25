// lib/models/analysis_session.dart

import 'package:hive/hive.dart';
import 'landmark_point.dart';
// ★★★ export を import に修正 ★★★
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart' show PoseLandmarkType;

part 'analysis_session.g.dart';

// PoseLandmarkTypeの値を保存可能にするためのアダプター
class PoseLandmarkTypeAdapter extends TypeAdapter<PoseLandmarkType> {
  @override
  final int typeId = 3;

  @override
  PoseLandmarkType read(BinaryReader reader) {
    final index = reader.readByte();
    // PoseLandmarkType.valuesが使えないため、手動でマッピング
    const List<PoseLandmarkType> types = [
      PoseLandmarkType.nose, PoseLandmarkType.leftEyeInner, PoseLandmarkType.leftEye,
      PoseLandmarkType.leftEyeOuter, PoseLandmarkType.rightEyeInner, PoseLandmarkType.rightEye,
      PoseLandmarkType.rightEyeOuter, PoseLandmarkType.leftEar, PoseLandmarkType.rightEar,
      PoseLandmarkType.leftMouth, PoseLandmarkType.rightMouth, PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder, PoseLandmarkType.leftElbow, PoseLandmarkType.rightElbow,
      PoseLandmarkType.leftWrist, PoseLandmarkType.rightWrist, PoseLandmarkType.leftPinky,
      PoseLandmarkType.rightPinky, PoseLandmarkType.leftIndex, PoseLandmarkType.rightIndex,
      PoseLandmarkType.leftThumb, PoseLandmarkType.rightThumb, PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip, PoseLandmarkType.leftKnee, PoseLandmarkType.rightKnee,
      PoseLandmarkType.leftAnkle, PoseLandmarkType.rightAnkle, PoseLandmarkType.leftHeel,
      PoseLandmarkType.rightHeel, PoseLandmarkType.leftFootIndex, PoseLandmarkType.rightFootIndex,
    ];
    return types[index];
  }

  @override
  void write(BinaryWriter writer, PoseLandmarkType obj) {
    writer.writeByte(obj.index);
  }
}

@HiveType(typeId: 2)
class AnalysisSession extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final DateTime createdAt;
  @HiveField(2)
  final String imagePath;
  @HiveField(3)
  final double score;
  @HiveField(4)
  final List<dynamic> userPoseLandmarks;
  @HiveField(5)
  final List<dynamic> idealPoseLandmarks;
  @HiveField(6)
  final String idealImagePath;
  @HiveField(7)
  String? coachComment;
  @HiveField(8)
  final double imageWidth;
  @HiveField(9)
  final double imageHeight;
  @HiveField(10)
  final double idealImageWidth;
  @HiveField(11)
  final double idealImageHeight;

  // ★★★ フィールド番号を12に修正 ★★★
  @HiveField(12)
  final int imageRotation;

  AnalysisSession({
    required this.id,
    required this.createdAt,
    required this.imagePath,
    required this.idealImagePath,
    required this.score,
    required this.userPoseLandmarks,
    required this.idealPoseLandmarks,
    this.coachComment,
    required this.imageWidth,
    required this.imageHeight,
    required this.idealImageWidth,
    required this.idealImageHeight,
    required this.imageRotation,
  });
}