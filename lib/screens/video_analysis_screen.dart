import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart'; // FFmpegKit から戻す

import '../analysis/pose_comparator.dart';
import '../analysis/pose_normalizer.dart';
import '../models/analysis_session.dart';
import '../models/landmark_point.dart';
import '../services/database_service.dart';
import '../services/pose_detection_service.dart';
import '../services/video_processing_service.dart';
import 'pose_painter.dart';

class VideoAnalysisScreen extends StatefulWidget {
  const VideoAnalysisScreen({super.key});

  @override
  State<VideoAnalysisScreen> createState() => _VideoAnalysisScreenState();
}

class _VideoAnalysisScreenState extends State<VideoAnalysisScreen> {
  VideoPlayerController? _controller;
  File? _selectedVideo;
  bool _isProcessing = false;
  List<Pose?> _detectedPoses = [];

  final VideoProcessingService _videoProcessingService = VideoProcessingService();
  final PoseDetectionService _poseDetectionService = PoseDetectionService();

  Future<void> _pickVideo() async {
    await _controller?.dispose();
    setState(() {
      _controller = null;
      _selectedVideo = null;
      _detectedPoses = [];
    });

    final picker = ImagePicker();
    final pickedFile = await picker.pickVideo(source: ImageSource.gallery);

    if (pickedFile != null) {
      final videoFile = File(pickedFile.path);
      final controller = VideoPlayerController.file(videoFile);
      setState(() {
        _controller = controller;
        _selectedVideo = videoFile;
      });

      try {
        await controller.initialize();
        await controller.setLooping(true);
        setState(() {});
      } catch (e) {
        print("ビデオの初期化中にエラーが発生しました: $e");
      }
    } else {
      print('動画は選択されませんでした。');
    }
  }

  Future<void> _startAnalysis() async {
    if (_selectedVideo == null) return;

    final idealPoseData = DatabaseService().getIdealPose();
    if (idealPoseData == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('先にお手本となるフォームを履歴から設定してください。'))
        );
      }
      return;
    }

    setState(() { _isProcessing = true; });

    // video_processing_service (video_thumbnail版) を呼び出す
    final frames = await _videoProcessingService.extractFrames(_selectedVideo!);
    if (frames.isEmpty) {
      setState(() { _isProcessing = false; });
      return;
    }

    final idealPoseLandmarks = <PoseLandmarkType, PoseLandmark>{};
    for (int i = 0; i < idealPoseData.idealPoseLandmarks.length; i += 2) {
      final type = idealPoseData.idealPoseLandmarks[i] as PoseLandmarkType;
      final point = idealPoseData.idealPoseLandmarks[i + 1] as LandmarkPoint;
      idealPoseLandmarks[type] = PoseLandmark(type: type, x: point.x, y: point.y, z: 0, likelihood: 1.0);
    }
    final normalizedIdealPose = PoseNormalizer.normalize(Pose(landmarks: idealPoseLandmarks));

    List<Pose?> posesOverTime = [];
    List<double> allDistances = [];

    for (final frameFile in frames) {
      final inputImage = InputImage.fromFilePath(frameFile.path);
      final poses = await _poseDetectionService.processImage(inputImage);

      if (poses.isNotEmpty) {
        final currentPose = poses.first;
        posesOverTime.add(currentPose);

        final normalizedCurrentPose = PoseNormalizer.normalize(currentPose);
        final distance = PoseComparator.calculateTotalDistance(normalizedIdealPose, normalizedCurrentPose);
        allDistances.add(distance);
      } else {
        posesOverTime.add(null);
      }
    }

    double averageScore = 0.0;
    if (allDistances.isNotEmpty) {
      final averageDistance = allDistances.reduce((a, b) => a + b) / allDistances.length;
      averageScore = PoseComparator.calculateScore(averageDistance);
    }
    print('分析完了！平均スコア: $averageScore');

    // ★★★ 修正箇所: _generateThumbnail を VideoThumbnail.thumbnailFile に戻す ★★★
    final String? thumbnailPath = await VideoThumbnail.thumbnailFile(
      video: _selectedVideo!.path,
      thumbnailPath: (await getApplicationDocumentsDirectory()).path,
      imageFormat: ImageFormat.JPEG,
      quality: 75,
    );

    final allUserPoseLandmarks = <dynamic>[];
    for (final pose in posesOverTime) {
      final frameLandmarks = <dynamic>[];
      if (pose != null) {
        pose.landmarks.forEach((key, value) {
          frameLandmarks.add(key);
          frameLandmarks.add(LandmarkPoint(x: value.x, y: value.y));
        });
      }
      allUserPoseLandmarks.add(frameLandmarks);
    }

    final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    final session = AnalysisSession(
      id: sessionId,
      createdAt: DateTime.now(),
      imagePath: thumbnailPath ?? _selectedVideo!.path,
      videoPath: _selectedVideo!.path,
      idealImagePath: idealPoseData.idealImagePath,
      score: averageScore,
      userPoseLandmarks: allUserPoseLandmarks,
      idealPoseLandmarks: idealPoseData.idealPoseLandmarks,
      imageWidth: _controller?.value.size.width ?? 0,
      imageHeight: _controller?.value.size.height ?? 0,
      idealImageWidth: idealPoseData.imageWidth,
      idealImageHeight: idealPoseData.imageHeight,
      imageRotation: 0,
    );

    await DatabaseService().saveAnalysisSession(session);
    await _videoProcessingService.clearTemporaryFrames();

    setState(() {
      _isProcessing = false;
      _detectedPoses = posesOverTime;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分析完了！平均スコア: ${averageScore.toStringAsFixed(1)} 点。履歴に保存しました。'))
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _poseDetectionService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // (buildメソッドは V2.0 のまま変更なし)
    return Scaffold(
      appBar: AppBar(
        title: const Text('動画分析'),
        actions: [
          if (_controller != null && !_isProcessing)
            TextButton(
              onPressed: _startAnalysis,
              child: const Text('分析開始', style: TextStyle(color: Colors.white)),
            )
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_controller != null && _controller!.value.isInitialized)
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          AspectRatio(
                            aspectRatio: _controller!.value.aspectRatio,
                            child: VideoPlayer(_controller!),
                          ),
                          ValueListenableBuilder<VideoPlayerValue>(
                            valueListenable: _controller!,
                            builder: (context, value, child) {
                              if (_detectedPoses.isEmpty) return const SizedBox.shrink();

                              final frameIndex = (value.position.inMilliseconds / 100).floor();
                              if (frameIndex < 0 || frameIndex >= _detectedPoses.length) {
                                return const SizedBox.shrink();
                              }

                              final currentPose = _detectedPoses[frameIndex];
                              if (currentPose == null) return const SizedBox.shrink();

                              return CustomPaint(
                                size: Size(
                                  _controller!.value.size.width,
                                  _controller!.value.size.height,
                                ),
                                painter: PosePainter(
                                  [currentPose],
                                  _controller!.value.size,
                                  InputImageRotation.rotation0deg,
                                ),
                              );
                            },
                          ),
                        ],
                      )
                    else
                      Container(
                        width: double.infinity,
                        height: 200,
                        margin: const EdgeInsets.all(16),
                        color: Colors.black,
                        child: const Center(
                          child: Icon(Icons.videocam, color: Colors.white, size: 50),
                        ),
                      ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.video_library),
                      label: const Text('動画を選択'),
                      onPressed: _isProcessing ? null : _pickVideo,
                    ),
                  ],
                ),
                if (_isProcessing)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black54,
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('動画を分析中...', style: TextStyle(color: Colors.white, fontSize: 16)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _controller != null
          ? FloatingActionButton(
        onPressed: () {
          setState(() {
            _controller!.value.isPlaying
                ? _controller!.pause()
                : _controller!.play();
          });
        },
        child: Icon(
          _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
        ),
      )
          : null,
    );
  }
}