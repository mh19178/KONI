import 'package:hive/hive.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart' show PoseLandmarkType;
import 'landmark_point.dart';

part 'analysis_session.g.dart';

@HiveType(typeId: 3)
class PoseLandmarkTypeAdapter extends TypeAdapter<PoseLandmarkType> {
  @override
  final int typeId = 3;
  @override
  PoseLandmarkType read(BinaryReader reader) {
    final index = reader.readByte();
    return PoseLandmarkType.values[index];
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
  @HiveField(12)
  final int imageRotation;
  @HiveField(13)
  final String? videoPath;
  @HiveField(14)
  final String? analysisType;
  @HiveField(15)
  final String? idealVideoPath;
  @HiveField(16)
  final double? idealStartTimeMs;
  @HiveField(17)
  final double? idealEndTimeMs;
  @HiveField(18)
  final double? userStartTimeMs;
  @HiveField(19)
  final double? userEndTimeMs;

  // (ピッチング用 - SSE)
  @HiveField(20)
  final double? idealSSEAngle;
  @HiveField(21)
  final double? userSSEAngle;

  // (バッティング用 & 汎用)
  @HiveField(30)
  final double? idealBodyTilt; // バッティング:構え / ピッチング:リリース時
  @HiveField(31)
  final double? userBodyTilt;

  @HiveField(32)
  final double? idealWeightShift;
  @HiveField(33)
  final double? userWeightShift;

  @HiveField(34)
  final double? idealHeadStability; // 頭の移動量 (ピッチングでも使用)
  @HiveField(35)
  final double? userHeadStability;

  // (関節別スコア)
  @HiveField(26)
  final double? shoulderScore;
  @HiveField(27)
  final double? hipScore;
  @HiveField(28)
  final double? elbowScore;
  @HiveField(29)
  final double? kneeScore;

  // (古いバッティング指標 - 互換性のため残す)
  @HiveField(22) final double? idealXFactorAngle;
  @HiveField(23) final double? userXFactorAngle;
  @HiveField(24) final double? idealElbowAngle;
  @HiveField(25) final double? userElbowAngle;

  // ★★★ 新しいピッチング指標を追加 (V3.1) ★★★

  // リリースポイントの高さ (Y座標, 正規化値)
  @HiveField(36)
  final double? idealReleaseHeight;
  @HiveField(37)
  final double? userReleaseHeight;

  // リリースポイントの横位置 (X座標, 正規化値)
  @HiveField(38)
  final double? idealReleaseSide;
  @HiveField(39)
  final double? userReleaseSide;

  // ★★★ 追加ここまで ★★★

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
    this.videoPath,
    this.analysisType,
    this.idealVideoPath,
    this.idealStartTimeMs,
    this.idealEndTimeMs,
    this.userStartTimeMs,
    this.userEndTimeMs,
    this.idealSSEAngle,
    this.userSSEAngle,
    this.shoulderScore,
    this.hipScore,
    this.elbowScore,
    this.kneeScore,
    this.idealBodyTilt,
    this.userBodyTilt,
    this.idealWeightShift,
    this.userWeightShift,
    this.idealHeadStability,
    this.userHeadStability,
    this.idealXFactorAngle,
    this.userXFactorAngle,
    this.idealElbowAngle,
    this.userElbowAngle,

    // ★ 新しい引数
    this.idealReleaseHeight,
    this.userReleaseHeight,
    this.idealReleaseSide,
    this.userReleaseSide,
  });
}