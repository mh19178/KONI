import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../services/pose_detection_service.dart';
import '../services/video_processing_service.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class VideoAnalysisScreen extends StatefulWidget {
  const VideoAnalysisScreen({super.key});

  @override
  State<VideoAnalysisScreen> createState() => _VideoAnalysisScreenState();
}

class _VideoAnalysisScreenState extends State<VideoAnalysisScreen> {
  VideoPlayerController? _controller;
  File? _selectedVideo;
  bool _isProcessing = false;

  final VideoProcessingService _videoProcessingService = VideoProcessingService();
  final PoseDetectionService _poseDetectionService = PoseDetectionService();

  Future<void> _pickVideo() async {
    await _controller?.dispose();
    setState(() { _controller = null; _selectedVideo = null; });

    final picker = ImagePicker();
    final pickedFile = await picker.pickVideo(source: ImageSource.gallery);

    if (pickedFile != null) {
      final videoFile = File(pickedFile.path);
      final controller = VideoPlayerController.file(videoFile);
      setState(() { _controller = controller; _selectedVideo = videoFile; });

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

    setState(() { _isProcessing = true; });

    // 1. 動画から全フレームを抽出
    final List<File> frames = await _videoProcessingService.extractFrames(_selectedVideo!);
    print('${frames.length} フレームを抽出しました。');

    if (frames.isEmpty) {
      setState(() { _isProcessing = false; });
      return;
    }

    // 2. 各フレームをポーズ分析にかける
    int poseCount = 0;
    for (final frameFile in frames) {
      final inputImage = InputImage.fromFilePath(frameFile.path);
      final List<Pose> poses = await _poseDetectionService.processImage(inputImage);
      if (poses.isNotEmpty) {
        poseCount++;
      }
    }
    print('${poseCount} 個のポーズを検出しました。');

    // 3. 一時ファイルを削除
    await _videoProcessingService.clearTemporaryFrames();

    setState(() { _isProcessing = false; });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分析が完了しました！ ${frames.length}フレーム中、${poseCount}個のポーズを検出。'))
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
      body: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_controller != null && _controller!.value.isInitialized)
                  AspectRatio(
                    aspectRatio: _controller!.value.aspectRatio,
                    child: VideoPlayer(_controller!),
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
              Container(
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
          ],
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