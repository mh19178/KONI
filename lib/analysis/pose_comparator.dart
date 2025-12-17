import 'dart:math';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'pose_normalizer.dart';
import '../models/landmark_point.dart';

class PoseComparator {

  // (V2.0用 静止画比較 - 変更なし)
  static double calculateTotalDistance(
      Map<PoseLandmarkType, PoseLandmark> pose1,
      Map<PoseLandmarkType, PoseLandmark> pose2,
      ) {
    double totalDistance = 0;
    int jointCount = 0;
    pose1.forEach((type, landmark1) {
      if (pose2.containsKey(type)) {
        final landmark2 = pose2[type]!;
        totalDistance += _getDistance(
            LandmarkPoint(x: landmark1.x, y: landmark1.y),
            LandmarkPoint(x: landmark2.x, y: landmark2.y)
        );
        jointCount++;
      }
    });
    return (jointCount > 0) ? (totalDistance / jointCount) : 0.0;
  }

  static double calculateScore(double totalDistance) {
    const double sensitivity = 0.07;
    final score = 100 * (1 - (totalDistance * sensitivity));
    if (score < 0) return 0;
    if (score > 100) return 100;
    return score;
  }

  static double calculateScoreFromDTW(double dtwDistance) {
    const double sensitivity = 0.07;
    final score = 100 * (1 - (dtwDistance * sensitivity));
    if (score < 0) return 0;
    if (score > 100) return 100;
    return score;
  }

  static List<Point<int>> getDTWPath(List<Pose> idealSequence, List<Pose> userSequence) {
    print('DTW (Path Finding): 計算を開始します (Ideal: ${idealSequence.length}件, User: ${userSequence.length}件)');
    final List<Map<PoseLandmarkType, PoseLandmark>> normalizedSeq1 =
    idealSequence.map((pose) => PoseNormalizer.normalize(pose)).toList();
    final List<Map<PoseLandmarkType, PoseLandmark>> normalizedSeq2 =
    userSequence.map((pose) => PoseNormalizer.normalize(pose)).toList();
    final int n = normalizedSeq1.length;
    final int m = normalizedSeq2.length;
    if (n == 0 || m == 0) return [];
    final List<List<double>> dtwMatrix = List.generate(
      n + 1, (_) => List.generate(m + 1, (_) => double.infinity),
    );
    for (int j = 0; j <= m; j++) { dtwMatrix[0][j] = 0.0; }
    for (int i = 1; i <= n; i++) {
      for (int j = 1; j <= m; j++) {
        final double cost = calculateTotalDistance(normalizedSeq1[i - 1], normalizedSeq2[j - 1]);
        final double minPrevCost = [
          dtwMatrix[i - 1][j], dtwMatrix[i][j - 1], dtwMatrix[i - 1][j - 1],
        ].reduce(min);
        dtwMatrix[i][j] = cost + minPrevCost;
      }
    }
    double minDistance = double.infinity;
    int bestEndIndex = -1;
    for (int j = 1; j <= m; j++) {
      if (dtwMatrix[n][j] < minDistance) {
        minDistance = dtwMatrix[n][j];
        bestEndIndex = j;
      }
    }
    if (bestEndIndex == -1) {
      print('DTW: エラー。マッチングパスが見つかりませんでした。');
      return [];
    }
    print('DTW: 計算完了。ゴール地点 (Ideal: $n, User: $bestEndIndex)');
    final List<Point<int>> path = _dtwBacktrack(dtwMatrix, n, bestEndIndex);
    print('DTW: 経路の復元完了。マッチングペア数: ${path.length}件');
    return path;
  }

  static List<Point<int>> _dtwBacktrack(List<List<double>> dtwMatrix, int n, int m) {
    int i = n;
    int j = m;
    final List<Point<int>> path = [];
    while (i > 0 && j > 0) {
      path.add(Point(i - 1, j - 1));
      final double costI = dtwMatrix[i - 1][j];
      final double costJ = dtwMatrix[i][j - 1];
      final double costIJ = dtwMatrix[i - 1][j - 1];
      if (costIJ <= costI && costIJ <= costJ) { i--; j--; }
      else if (costI <= costJ) { i--; }
      else { j--; }
    }
    while (i > 0) { path.add(Point(i - 1, j - 1)); i--; }
    return path.reversed.toList();
  }

  // --- ヘルパー関数群 ---
  static double _getDistance(LandmarkPoint p1, LandmarkPoint p2) {
    return sqrt(pow(p1.x - p2.x, 2) + pow(p1.y - p2.y, 2));
  }
  static double _calculateAngle(LandmarkPoint p1, LandmarkPoint p2, LandmarkPoint p3) {
    final v1 = LandmarkPoint(x: p1.x - p2.x, y: p1.y - p2.y);
    final v2 = LandmarkPoint(x: p3.x - p2.x, y: p3.y - p2.y);
    final double dotProduct = v1.x * v2.x + v1.y * v2.y;
    final double magnitudeV1 = sqrt(v1.x * v1.x + v1.y * v1.y);
    final double magnitudeV2 = sqrt(v2.x * v2.x + v2.y * v2.y);
    if (magnitudeV1 == 0 || magnitudeV2 == 0) return 0.0;
    double cosTheta = dotProduct / (magnitudeV1 * magnitudeV2);
    if (cosTheta > 1.0) cosTheta = 1.0;
    if (cosTheta < -1.0) cosTheta = -1.0;
    return acos(cosTheta) * (180.0 / pi);
  }
  static LandmarkPoint? _toPoint(Pose pose, PoseLandmarkType type) {
    final lm = pose.landmarks[type];
    return lm != null ? LandmarkPoint(x: lm.x, y: lm.y) : null;
  }
  static double getShoulderDistance(Pose pose) {
    final LandmarkPoint? ls = _toPoint(pose, PoseLandmarkType.leftShoulder);
    final LandmarkPoint? rs = _toPoint(pose, PoseLandmarkType.rightShoulder);
    return (ls != null && rs != null) ? _getDistance(ls, rs) : 0.0;
  }
  static double getSSEAngle(Pose pose, {required bool isRightHanded}) {
    final LandmarkPoint? p1, p2, p3;
    if (isRightHanded) {
      p1 = _toPoint(pose, PoseLandmarkType.leftShoulder);
      p2 = _toPoint(pose, PoseLandmarkType.rightShoulder);
      p3 = _toPoint(pose, PoseLandmarkType.rightElbow);
    } else {
      p1 = _toPoint(pose, PoseLandmarkType.rightShoulder);
      p2 = _toPoint(pose, PoseLandmarkType.leftShoulder);
      p3 = _toPoint(pose, PoseLandmarkType.leftElbow);
    }
    if (p1 != null && p2 != null && p3 != null) {
      return _calculateAngle(p1, p2, p3);
    }
    return -1.0;
  }
  static double _calculateLineAngle(LandmarkPoint p1, LandmarkPoint p2) {
    final double dx = p2.x - p1.x;
    final double dy = p2.y - p1.y;
    return atan2(dy, dx) * (180.0 / pi);
  }
  static double getXFactorAngle(Pose pose) {
    final LandmarkPoint? ls = _toPoint(pose, PoseLandmarkType.leftShoulder);
    final LandmarkPoint? rs = _toPoint(pose, PoseLandmarkType.rightShoulder);
    final LandmarkPoint? lh = _toPoint(pose, PoseLandmarkType.leftHip);
    final LandmarkPoint? rh = _toPoint(pose, PoseLandmarkType.rightHip);
    if (ls != null && rs != null && lh != null && rh != null) {
      final double shoulderAngle = _calculateLineAngle(ls, rs);
      final double hipAngle = _calculateLineAngle(lh, rh);
      double diff = (shoulderAngle - hipAngle).abs();
      if (diff > 180) diff = 360 - diff;
      return diff;
    }
    return -1.0;
  }
  static double getTopHandElbowAngle(Pose pose, {required bool isRightHanded}) {
    final LandmarkPoint? p1, p2, p3;
    if (isRightHanded) {
      p1 = _toPoint(pose, PoseLandmarkType.rightShoulder);
      p2 = _toPoint(pose, PoseLandmarkType.rightElbow);
      p3 = _toPoint(pose, PoseLandmarkType.rightHip);
    } else {
      p1 = _toPoint(pose, PoseLandmarkType.leftShoulder);
      p2 = _toPoint(pose, PoseLandmarkType.leftElbow);
      p3 = _toPoint(pose, PoseLandmarkType.leftHip);
    }
    if (p1 != null && p2 != null && p3 != null) {
      return _calculateAngle(p1, p2, p3);
    }
    return -1.0;
  }
  static double calculateAverageBodyTilt(List<Pose> poses) {
    if (poses.isEmpty) return 0.0;
    double totalTilt = 0;
    int count = 0;
    for (final pose in poses) {
      final ls = _toPoint(pose, PoseLandmarkType.leftShoulder);
      final rs = _toPoint(pose, PoseLandmarkType.rightShoulder);
      final lh = _toPoint(pose, PoseLandmarkType.leftHip);
      final rh = _toPoint(pose, PoseLandmarkType.rightHip);
      if (ls != null && rs != null && lh != null && rh != null) {
        final shoulderMidX = (ls.x + rs.x) / 2;
        final shoulderMidY = (ls.y + rs.y) / 2;
        final hipMidX = (lh.x + rh.x) / 2;
        final hipMidY = (lh.y + rh.y) / 2;
        final dx = shoulderMidX - hipMidX;
        final dy = shoulderMidY - hipMidY;
        final angleRad = atan2(dx.abs(), -dy);
        totalTilt += angleRad * (180.0 / pi);
        count++;
      }
    }
    return count > 0 ? totalTilt / count : 0.0;
  }
  static double calculateWeightShift(List<Pose> poses) {
    if (poses.isEmpty) return 0.0;
    double minHipX = double.infinity;
    double maxHipX = double.negativeInfinity;
    double totalTorsoLength = 0;
    int count = 0;
    for (final pose in poses) {
      final ls = _toPoint(pose, PoseLandmarkType.leftShoulder);
      final rs = _toPoint(pose, PoseLandmarkType.rightShoulder);
      final lh = _toPoint(pose, PoseLandmarkType.leftHip);
      final rh = _toPoint(pose, PoseLandmarkType.rightHip);
      if (ls != null && rs != null && lh != null && rh != null) {
        final hipMidX = (lh.x + rh.x) / 2;
        final hipMidY = (lh.y + rh.y) / 2;
        final shoulderMidX = (ls.x + rs.x) / 2;
        final shoulderMidY = (ls.y + rs.y) / 2;
        final torsoLen = sqrt(pow(shoulderMidX - hipMidX, 2) + pow(shoulderMidY - hipMidY, 2));
        if (torsoLen > 0) {
          totalTorsoLength += torsoLen;
          count++;
        }
        if (hipMidX < minHipX) minHipX = hipMidX;
        if (hipMidX > maxHipX) maxHipX = hipMidX;
      }
    }
    if (count == 0) return 0.0;
    final avgTorsoLength = totalTorsoLength / count;
    return (maxHipX - minHipX) / avgTorsoLength;
  }

  /// ★★★ 修正: 頭の安定性 (緩和条件) ★★★
  /// 鼻だけ、体幹だけ、それぞれ取得可能なフレームから計算して合わせる
  static double calculateHeadStability(List<Pose> poses) {
    if (poses.isEmpty) return 0.0;

    // 1. 体幹の平均長さを計算
    double totalTorsoLength = 0;
    int torsoCount = 0;
    for (final pose in poses) {
      final ls = _toPoint(pose, PoseLandmarkType.leftShoulder);
      final rs = _toPoint(pose, PoseLandmarkType.rightShoulder);
      final lh = _toPoint(pose, PoseLandmarkType.leftHip);
      final rh = _toPoint(pose, PoseLandmarkType.rightHip);

      if (ls != null && rs != null && lh != null && rh != null) {
        final shoulderMidX = (ls.x + rs.x) / 2;
        final shoulderMidY = (ls.y + rs.y) / 2;
        final hipMidX = (lh.x + rh.x) / 2;
        final hipMidY = (lh.y + rh.y) / 2;
        final len = sqrt(pow(shoulderMidX - hipMidX, 2) + pow(shoulderMidY - hipMidY, 2));
        if (len > 0) {
          totalTorsoLength += len;
          torsoCount++;
        }
      }
    }
    if (torsoCount == 0) return 0.0;
    final double avgTorsoLength = totalTorsoLength / torsoCount;

    // 2. 鼻の移動範囲を計算 (体幹が見えていなくても鼻さえあればOK)
    double minNoseX = double.infinity, maxNoseX = double.negativeInfinity;
    double minNoseY = double.infinity, maxNoseY = double.negativeInfinity;
    int noseCount = 0;

    for (final pose in poses) {
      final nose = _toPoint(pose, PoseLandmarkType.nose);
      if (nose != null) {
        if (nose.x < minNoseX) minNoseX = nose.x;
        if (nose.x > maxNoseX) maxNoseX = nose.x;
        if (nose.y < minNoseY) minNoseY = nose.y;
        if (nose.y > maxNoseY) maxNoseY = nose.y;
        noseCount++;
      }
    }

    if (noseCount < 2) return 0.0; // 少なくとも2フレームは必要

    final totalShake = (maxNoseX - minNoseX) + (maxNoseY - minNoseY);
    return totalShake / avgTorsoLength;
  }
  // ★★★ 修正ここまで ★★★

  // (リリースフレーム探索 - 変更なし)
  static int findReleaseFrameIndex(List<Pose> poses, {required bool isRightHanded}) {
    if (poses.length < 4) return 0;
    double maxAvgVelocity = -1.0;
    int releaseIndex = 1;
    final wristType = isRightHanded ? PoseLandmarkType.rightWrist : PoseLandmarkType.leftWrist;
    for (int i = 1; i < poses.length - 1; i++) {
      final p_prev = _toPoint(poses[i - 1], wristType);
      final p_curr = _toPoint(poses[i], wristType);
      final p_next = _toPoint(poses[i + 1], wristType);
      if (p_prev != null && p_curr != null && p_next != null) {
        final v1 = _getDistance(p_prev, p_curr);
        final v2 = _getDistance(p_curr, p_next);
        final avgVelocity = (v1 + v2) / 2.0;
        if (avgVelocity > maxAvgVelocity) {
          maxAvgVelocity = avgVelocity;
          releaseIndex = i;
        }
      }
    }
    return releaseIndex;
  }

  // (体軸の傾き - 変更なし)
  static double calculateSpineAngle(List<Pose> poses, int index) {
    if (index < 0 || index >= poses.length) return 0.0;
    final int start = max(0, index - 1);
    final int end = min(poses.length - 1, index + 1);
    double totalAngle = 0;
    int count = 0;
    for (int i = start; i <= end; i++) {
      final pose = poses[i];
      final ls = _toPoint(pose, PoseLandmarkType.leftShoulder);
      final rs = _toPoint(pose, PoseLandmarkType.rightShoulder);
      final lh = _toPoint(pose, PoseLandmarkType.leftHip);
      final rh = _toPoint(pose, PoseLandmarkType.rightHip);
      if (ls != null && rs != null && lh != null && rh != null) {
        final shoulderMidX = (ls.x + rs.x) / 2;
        final shoulderMidY = (ls.y + rs.y) / 2;
        final hipMidX = (lh.x + rh.x) / 2;
        final hipMidY = (lh.y + rh.y) / 2;
        final dx = shoulderMidX - hipMidX;
        final dy = shoulderMidY - hipMidY;
        final angleRad = atan2(dx.abs(), -dy);
        totalAngle += angleRad * (180.0 / pi);
        count++;
      }
    }
    return (count > 0) ? (totalAngle / count) : 0.0;
  }

  /// ★★★ 修正: リリースポイント (Y座標の符号反転 + 3フレーム平均) ★★★
  static List<double>? getReleasePoint(List<Pose> poses, int index, {required bool isRightHanded}) {
    if (index < 0 || index >= poses.length) return null;

    final int start = max(0, index - 1);
    final int end = min(poses.length - 1, index + 1);

    double totalX = 0;
    double totalY = 0;
    int count = 0;
    final wristType = isRightHanded ? PoseLandmarkType.rightWrist : PoseLandmarkType.leftWrist;

    for (int i = start; i <= end; i++) {
      final normalizedLandmarks = PoseNormalizer.normalize(poses[i]);
      final wrist = normalizedLandmarks[wristType];

      if (wrist != null) {
        totalX += wrist.x;
        // ★ 修正: Y座標の符号を反転 (上がプラスになるように)
        // PoseNormalizerでは translatedY = y - centerY なので、
        // 画面上(Y小)はマイナス、画面下(Y大)はプラスになっている。
        // これを直感的に「高い＝プラス」にするため -1 を掛ける。
        totalY += (-1 * wrist.y);
        count++;
      }
    }

    if (count > 0) {
      return [totalX / count, totalY / count];
    }
    return null;
  }
// ★★★ 修正ここまで ★★★
}