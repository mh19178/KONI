import 'dart:io';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../analysis/pose_comparator.dart';
import '../analysis/pose_normalizer.dart';
import '../models/analysis_session.dart';
import '../models/landmark_point.dart';
import '../providers/services_provider.dart';
import '../services/database_service.dart';
import '../services/pose_detection_service.dart';
import 'pose_painter.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> {
  final PoseDetectionService _poseDetectionService = PoseDetectionService();
  bool _isProcessing = false;
  List<Pose> _poses = [];
  Size? _imageSize;
  InputImageRotation _imageRotation = InputImageRotation.rotation0deg;

  @override
  void initState() {
    super.initState();
    ref.read(cameraServiceProvider).initialize();
  }

  @override
  void dispose() {
    _poseDetectionService.dispose();
    super.dispose();
  }

  Future<void> _takeAndProcessPicture() async {
    final cameraService = ref.read(cameraServiceProvider);
    if (cameraService.controller == null || !cameraService.isInitialized) return;

    setState(() { _isProcessing = true; });

    try {
      final idealPoseData = DatabaseService().getIdealPose();
      final picture = await cameraService.controller!.takePicture();
      final inputImage = InputImage.fromFilePath(picture.path);
      final poses = await _poseDetectionService.processImage(inputImage);

      if (poses.isNotEmpty) {
        final decodedImage = await decodeImageFromList(await picture.readAsBytes());
        final currentPose = poses.first; // ★★★ 生のポーズデータを取得 ★★★

        if (idealPoseData == null) {
          // --- 理想フォームの初回登録 ---
          final sessionId = DateTime.now().millisecondsSinceEpoch.toString();

          // ★★★ 生のランドマークデータをリストに変換 ★★★
          final rawLandmarksList = <dynamic>[];
          currentPose.landmarks.forEach((key, value) {
            rawLandmarksList.add(key);
            rawLandmarksList.add(LandmarkPoint(x: value.x, y: value.y));
          });

          final tempSessionForIdeal = AnalysisSession(
            id: sessionId,
            createdAt: DateTime.now(),
            imagePath: picture.path,
            idealImagePath: picture.path,
            score: 100.0,
            userPoseLandmarks: rawLandmarksList, // 生データを保存
            idealPoseLandmarks: rawLandmarksList, // 生データを保存
            imageWidth: decodedImage.width.toDouble(),
            imageHeight: decodedImage.height.toDouble(),
            idealImageWidth: decodedImage.width.toDouble(),
            idealImageHeight: decodedImage.height.toDouble(),
            imageRotation: 0,
          );
          await DatabaseService().saveIdealPose(tempSessionForIdeal);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('最初の理想のフォームを登録しました！')));
          }

        } else {
          // --- 既存のお手本との比較 ---

          // ★★★ 計算の直前に正規化を行う ★★★
          final normalizedCurrentUserPose = PoseNormalizer.normalize(currentPose);

          // DBから復元したお手本も、ここで初めて正規化する
          final idealPoseLandmarksMap = <PoseLandmarkType, PoseLandmark>{};
          for (int i = 0; i < idealPoseData.idealPoseLandmarks.length; i += 2) {
            final type = idealPoseData.idealPoseLandmarks[i] as PoseLandmarkType;
            final point = idealPoseData.idealPoseLandmarks[i + 1] as LandmarkPoint;
            idealPoseLandmarksMap[type] = PoseLandmark(type: type, x: point.x, y: point.y, z: 0, likelihood: 1.0);
          }
          final normalizedIdealPose = PoseNormalizer.normalize(Pose(landmarks: idealPoseLandmarksMap));

          // 正規化されたデータ同士でスコアを計算
          final totalDistance = PoseComparator.calculateTotalDistance(normalizedIdealPose, normalizedCurrentUserPose);
          final score = PoseComparator.calculateScore(totalDistance);

          // ★★★ データベースには生のランドマークデータを保存 ★★★
          final rawLandmarksList = <dynamic>[];
          currentPose.landmarks.forEach((key, value) {
            rawLandmarksList.add(key);
            rawLandmarksList.add(LandmarkPoint(x: value.x, y: value.y));
          });

          final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
          final session = AnalysisSession(
            id: sessionId,
            createdAt: DateTime.now(),
            imagePath: picture.path,
            idealImagePath: idealPoseData.idealImagePath,
            score: score,
            userPoseLandmarks: rawLandmarksList, // 生データを保存
            idealPoseLandmarks: idealPoseData.idealPoseLandmarks,
            imageWidth: decodedImage.width.toDouble(),
            imageHeight: decodedImage.height.toDouble(),
            idealImageWidth: idealPoseData.imageWidth,
            idealImageHeight: idealPoseData.imageHeight,
            imageRotation: 0,
          );
          await DatabaseService().saveAnalysisSession(session);
        }

        if (mounted) {
          setState(() {
            _poses = poses; // UI描画用に生のポーズを保持
            _imageSize = Size(decodedImage.width.toDouble(), decodedImage.height.toDouble());
            final camera = cameraService.cameraDescription;
            if (camera != null) {
              _imageRotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation) ?? InputImageRotation.rotation0deg;
            }
          });
        }
      }
    } catch (e) {
      print('Error taking or processing picture: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cameraService = ref.watch(cameraServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('フォーム撮影'),
        // ★★★ 不要になったactionsボタンを削除 ★★★
      ),
      body: !cameraService.isInitialized || cameraService.controller == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(cameraService.controller!),
          if (_imageSize != null)
            CustomPaint(
              painter: PosePainter(
                _poses,
                _imageSize!,
                _imageRotation,
              ),
            ),
          if (_isProcessing)
            const Center(
              child: CircularProgressIndicator(),
            )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isProcessing ? null : _takeAndProcessPicture,
        child: const Icon(Icons.camera_alt),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}