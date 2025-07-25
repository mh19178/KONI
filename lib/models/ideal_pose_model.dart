import 'package:hive/hive.dart';

part 'ideal_pose_model.g.dart';

@HiveType(typeId: 4)
class IdealPose extends HiveObject {
  @HiveField(0)
  final String idealImagePath;

  @HiveField(1)
  final List<dynamic> idealPoseLandmarks;

  // ★★★ 画像サイズを追加 ★★★
  @HiveField(2)
  final double imageWidth;

  @HiveField(3)
  final double imageHeight;

  IdealPose({
    required this.idealImagePath,
    required this.idealPoseLandmarks,
    required this.imageWidth,
    required this.imageHeight,
  });
}