import 'dart:math';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PoseComparator {
  // 2つの正規化済みポーズデータを受け取り、全関節の合計距離を計算する
  static double calculateTotalDistance(
      Map<PoseLandmarkType, PoseLandmark> pose1,
      Map<PoseLandmarkType, PoseLandmark> pose2,
      ) {
    double totalDistance = 0;

    pose1.forEach((type, landmark1) {
      if (pose2.containsKey(type)) {
        final landmark2 = pose2[type]!;
        final distance = sqrt(pow(landmark1.x - landmark2.x, 2) + pow(landmark1.y - landmark2.y, 2));
        totalDistance += distance;
      }
    });

    return totalDistance;
  }

  // 距離を100点満点のスコアに変換する
  static double calculateScore(double totalDistance) {
    const sensitivity = 5.0;
    final score = 100 - (totalDistance * sensitivity);

    if (score < 0) return 0;
    if (score > 100) return 100;
    return score;
  }
}