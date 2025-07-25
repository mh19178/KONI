import 'dart:ui';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'dart:math';

class PoseNormalizer {
  // ポーズデータを入力として受け取り、正規化されたランドマークのマップを返す
  static Map<PoseLandmarkType, PoseLandmark> normalize(Pose pose) {

    // 体の中心を定義するために、左右の腰のランドマークを取得
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip]!;
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip]!;

    // 左右の腰の中点を体幹の中心とする
    final torsoCenter = Point(
      (leftHip.x + rightHip.x) / 2,
      (leftHip.y + rightHip.y) / 2,
    );

    // 正規化のためのスケール（縮尺）を計算
    // ここでは左右の肩の距離を基準とする
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder]!;
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder]!;

    final shoulderDistance = sqrt(
        pow(leftShoulder.x - rightShoulder.x, 2) +
            pow(leftShoulder.y - rightShoulder.y, 2)
    );

    // 正規化された新しいランドマークを格納するマップ
    final Map<PoseLandmarkType, PoseLandmark> normalizedLandmarks = {};

    // すべてのランドマークをループして正規化処理を適用
    pose.landmarks.forEach((type, landmark) {
      // 1. 体幹の中心が原点(0,0)になるように、すべての点を平行移動
      final translatedX = landmark.x - torsoCenter.x;
      final translatedY = landmark.y - torsoCenter.y;

      // 2. 肩幅が常に一定になるように、すべての点をスケーリング（拡大/縮小）
      final normalizedX = translatedX / shoulderDistance;
      final normalizedY = translatedY / shoulderDistance;

      // 新しい正規化済みのランドマークを作成してマップに追加
      normalizedLandmarks[type] = PoseLandmark(
        type: type,
        x: normalizedX,
        y: normalizedY,
        z: 0, // Z座標は今回は使わない
        likelihood: landmark.likelihood,
      );
    });

    return normalizedLandmarks;
  }
}