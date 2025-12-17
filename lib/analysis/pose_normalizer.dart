import 'dart:math';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PoseNormalizer {
  static Map<PoseLandmarkType, PoseLandmark> normalize(Pose pose) {

    // ★ 1. 4つの主要なランドマークを取得
    final PoseLandmark? leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final PoseLandmark? rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final PoseLandmark? leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final PoseLandmark? rightHip = pose.landmarks[PoseLandmarkType.rightHip];

    // ★ 2. 安全性のための NULL チェック (4点すべてが必要)
    if (leftShoulder == null || rightShoulder == null || leftHip == null || rightHip == null) {
      print("Warning: Key landmarks (Shoulders/Hips) not found. Skipping normalization.");
      return pose.landmarks; // 生のデータを返す
    }

    // 3. 体幹の中心 (腰の中点) (変更なし)
    final torsoCenter = Point(
      (leftHip.x + rightHip.x) / 2,
      (leftHip.y + rightHip.y) / 2,
    );

    // ★ 4. 修正: 正規化の基準を「肩の距離」から「体幹の長さ」に変更

    // 肩の中点を計算
    final shoulderMidpoint = Point(
      (leftShoulder.x + rightShoulder.x) / 2,
      (leftShoulder.y + rightShoulder.y) / 2,
    );

    // 体幹の長さ (肩の中点と腰の中点の距離)
    final double torsoLength = sqrt(
        pow(shoulderMidpoint.x - torsoCenter.x, 2) +
            pow(shoulderMidpoint.y - torsoCenter.y, 2)
    );

    // 5. ゼロ除算を防止
    if (torsoLength < 1e-6) {
      return pose.landmarks;
    }

    final Map<PoseLandmarkType, PoseLandmark> normalizedLandmarks = {};

    // 6. すべてのランドマークをスケーリング
    pose.landmarks.forEach((type, landmark) {
      final translatedX = landmark.x - torsoCenter.x;
      final translatedY = landmark.y - torsoCenter.y;

      // ★ 7. 修正: shoulderDistance ではなく torsoLength で割る
      final normalizedX = translatedX / torsoLength;
      final normalizedY = translatedY / torsoLength;

      normalizedLandmarks[type] = PoseLandmark(
        type: type,
        x: normalizedX,
        y: normalizedY,
        z: 0,
        likelihood: landmark.likelihood,
      );
    });

    return normalizedLandmarks;
  }
}