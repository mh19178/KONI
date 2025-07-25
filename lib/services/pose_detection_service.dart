import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PoseDetectionService {
  // ストリームモードではなく、静止画用のデフォルトモードで初期化
  final PoseDetector _poseDetector = PoseDetector(options: PoseDetectorOptions());

  Future<List<Pose>> processImage(InputImage inputImage) async {
    try {
      return await _poseDetector.processImage(inputImage);
    } catch (e) {
      print('Error processing static image: $e');
      return [];
    }
  }

  void dispose() {
    _poseDetector.close();
  }
}