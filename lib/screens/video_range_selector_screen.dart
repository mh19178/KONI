import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'dart:math';

import '../services/pose_detection_service.dart';
import '../services/video_processing_service.dart';
import '../analysis/pose_comparator.dart';
import '../analysis/pose_normalizer.dart';
import '../services/database_service.dart';
import '../models/analysis_session.dart';
import '../models/landmark_point.dart';

// 部位別スコアを定義するための Enum
enum JointGroup { shoulders, hips, elbows, knees }

class VideoRangeSelectorScreen extends StatefulWidget {
  const VideoRangeSelectorScreen({super.key});

  @override
  State<VideoRangeSelectorScreen> createState() => _VideoRangeSelectorScreenState();
}

class _VideoRangeSelectorScreenState extends State<VideoRangeSelectorScreen> {
  final ImagePicker _picker = ImagePicker();
  final VideoProcessingService _videoService = VideoProcessingService();
  final PoseDetectionService _poseService = PoseDetectionService();

  File? _idealVideoFile;
  File? _userVideoFile;
  VideoPlayerController? _idealController;
  VideoPlayerController? _userController;
  RangeValues? _idealRange;
  RangeValues? _userRange;

  bool _isLoadingIdeal = false;
  bool _isLoadingUser = false;
  bool _isAnalyzing = false;
  String _analysisStatus = '選択区間を分析中...';

  Future<void> _pickVideo(bool isIdeal) async {
    setState(() {
      if (isIdeal) _isLoadingIdeal = true;
      else _isLoadingUser = true;
    });
    if (isIdeal) {
      await _idealController?.dispose();
      _idealController = null;
      _idealRange = null;
    } else {
      await _userController?.dispose();
      _userController = null;
      _userRange = null;
    }
    try {
      final pickedFile = await _picker.pickVideo(source: ImageSource.gallery);
      if (pickedFile == null) {
        setState(() {
          if (isIdeal) _isLoadingIdeal = false;
          else _isLoadingUser = false;
        });
        return;
      }
      final file = File(pickedFile.path);
      final controller = VideoPlayerController.file(file);
      await controller.initialize();
      await controller.setLooping(true);
      final durationMs = controller.value.duration.inMilliseconds.toDouble();
      setState(() {
        if (isIdeal) {
          _idealVideoFile = file;
          _idealController = controller;
          _idealRange = RangeValues(0.0, durationMs);
        } else {
          _userVideoFile = file;
          _userController = controller;
          _userRange = RangeValues(0.0, durationMs);
        }
      });
    } catch (e) {
      print('動画の読み込み/初期化に失敗しました: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('動画の読み込みに失敗しました: $e')),
        );
      }
    } finally {
      setState(() {
        if (isIdeal) _isLoadingIdeal = false;
        else _isLoadingUser = false;
      });
    }
  }

  @override
  void dispose() {
    _idealController?.dispose();
    _userController?.dispose();
    _poseService.dispose();
    super.dispose();
  }

  /// ★★★ _startAnalysis を修正 (古い指標を削除) ★★★
  Future<void> _startAnalysis() async {
    if (_idealVideoFile == null || _userVideoFile == null || _idealRange == null || _userRange == null) {
      return;
    }

    const bool isRightHanded = true;

    setState(() {
      _isAnalyzing = true;
      _analysisStatus = '1/7: メモリを解放中...';
    });

    print('分析開始: 動画コントローラーを破棄してメモリを解放します...');
    await _idealController?.pause();
    await _userController?.pause();
    final Size idealVideoSize = _idealController?.value.size ?? Size.zero;
    final Size userVideoSize = _userController?.value.size ?? Size.zero;
    await _idealController?.dispose();
    await _userController?.dispose();
    setState(() {
      _idealController = null;
      _userController = null;
    });

    final Directory tempDir = await getTemporaryDirectory();
    final String tempFramePath = '${tempDir.path}/temp_frame.jpeg';
    final String idealThumbnailPath = '${(await getApplicationDocumentsDirectory()).path}/thumb_ideal_${DateTime.now().millisecondsSinceEpoch}.jpeg';
    final String userThumbnailPath = '${(await getApplicationDocumentsDirectory()).path}/thumb_user_${DateTime.now().millisecondsSinceEpoch}.jpeg';

    // 変数を準備
    double? idealSSEAngle, userSSEAngle;
    // (XFactor, ElbowAngle は削除)

    // 新しい指標
    double? idealBodyTilt, userBodyTilt;
    double? idealHeadStability, userHeadStability;
    double? idealReleaseHeight, userReleaseHeight;
    double? idealReleaseSide, userReleaseSide;
    double? idealWeightShift, userWeightShift;

    String analysisResultText = "";
    double shoulderScore = 0, hipScore = 0, elbowScore = 0, kneeScore = 0;
    double score = 0;

    try {
      setState(() { _analysisStatus = '2/7: お手本動画のサムネイル生成...'; });
      await _generateThumbnail(videoPath: _idealVideoFile!.path, timeMs: _idealRange!.start.toInt(), outputPath: idealThumbnailPath);

      setState(() { _analysisStatus = '3/7: お手本動画のポーズ分析...'; });
      final List<Pose> idealPoses = await _processVideoSequentially(videoFile: _idealVideoFile!, range: _idealRange!, tempFramePath: tempFramePath);

      setState(() { _analysisStatus = '4/7: ユーザー動画のサムネイル生成...'; });
      await _generateThumbnail(videoPath: _userVideoFile!.path, timeMs: _userRange!.start.toInt(), outputPath: userThumbnailPath);

      setState(() { _analysisStatus = '5/7: ユーザー動画のポーズ分析...'; });
      final List<Pose> userPoses = await _processVideoSequentially(videoFile: _userVideoFile!, range: _userRange!, tempFramePath: tempFramePath);

      if (idealPoses.isEmpty || userPoses.isEmpty) throw Exception('ポーズを検出できませんでした。');

      setState(() { _analysisStatus = '6/7: 動作詳細を分析中...'; });

      final bool isIdealPitching = _checkIsPitchingMotion(idealPoses);
      final bool isUserPitching = _checkIsPitchingMotion(userPoses);

      if (isIdealPitching != isUserPitching) {
        print('エラー: 動作タイプが異なります。');
        analysisResultText = '\n動作タイプが異なるため、比較できません。';
      } else {
        if (isIdealPitching) {
          // --- ピッチングの場合 ---
          print('タイプ: ピッチング');
          idealSSEAngle = _analyzePitchingSSE(idealPoses, isRightHanded: isRightHanded);
          userSSEAngle = _analyzePitchingSSE(userPoses, isRightHanded: isRightHanded);

          final int idealRelIdx = PoseComparator.findReleaseFrameIndex(idealPoses, isRightHanded: isRightHanded);
          final int userRelIdx = PoseComparator.findReleaseFrameIndex(userPoses, isRightHanded: isRightHanded);

          idealBodyTilt = PoseComparator.calculateSpineAngle(idealPoses, idealRelIdx);
          userBodyTilt = PoseComparator.calculateSpineAngle(userPoses, userRelIdx);
          idealHeadStability = PoseComparator.calculateHeadStability(idealPoses);
          userHeadStability = PoseComparator.calculateHeadStability(userPoses);

          final List<double>? idealRelPoint = PoseComparator.getReleasePoint(idealPoses, idealRelIdx, isRightHanded: isRightHanded);
          if (idealRelPoint != null) { idealReleaseSide = idealRelPoint[0]; idealReleaseHeight = idealRelPoint[1]; }
          final List<double>? userRelPoint = PoseComparator.getReleasePoint(userPoses, userRelIdx, isRightHanded: isRightHanded);
          if (userRelPoint != null) { userReleaseSide = userRelPoint[0]; userReleaseHeight = userRelPoint[1]; }

          analysisResultText = '\nSSE角度 (手本): ${idealSSEAngle.toStringAsFixed(1)}° (あなた): ${userSSEAngle.toStringAsFixed(1)}°'
              '\n体軸の傾き (手本): ${idealBodyTilt?.toStringAsFixed(1)}° (あなた): ${userBodyTilt?.toStringAsFixed(1)}°';

        } else {
          // --- バッティングの場合 (古い指標を削除) ---
          print('タイプ: バッティング (新指標のみ)');

          // ① 上体の前傾
          idealBodyTilt = PoseComparator.calculateAverageBodyTilt(idealPoses);
          userBodyTilt = PoseComparator.calculateAverageBodyTilt(userPoses);

          // ② 体重移動
          idealWeightShift = PoseComparator.calculateWeightShift(idealPoses);
          userWeightShift = PoseComparator.calculateWeightShift(userPoses);

          // ③ 頭の安定性
          idealHeadStability = PoseComparator.calculateHeadStability(idealPoses);
          userHeadStability = PoseComparator.calculateHeadStability(userPoses);

          // (古い _analyzeBattingMetrics は削除済み)

          analysisResultText = '\n上体前傾 (手本): ${idealBodyTilt!.toStringAsFixed(1)}° (あなた): ${userBodyTilt!.toStringAsFixed(1)}°'
              '\n体重移動 (手本): ${((idealWeightShift ?? 0)*100).toStringAsFixed(0)}% (あなた): ${((userWeightShift ?? 0)*100).toStringAsFixed(0)}%';
        }

        setState(() { _analysisStatus = '7/7: フォーム全体を比較中...'; });
        final List<Point<int>> path = PoseComparator.getDTWPath(idealPoses, userPoses);
        if (path.isNotEmpty) {
          double totalDistance = 0, shoulderDistance = 0, hipDistance = 0, elbowDistance = 0, kneeDistance = 0;

          for (final pair in path) {
            final normIdeal = PoseNormalizer.normalize(idealPoses[pair.x]);
            final normUser = PoseNormalizer.normalize(userPoses[pair.y]);

            totalDistance += PoseComparator.calculateTotalDistance(normIdeal, normUser);
            shoulderDistance += _calculatePartialDistance(normIdeal, normUser, JointGroup.shoulders);
            hipDistance += _calculatePartialDistance(normIdeal, normUser, JointGroup.hips);
            elbowDistance += _calculatePartialDistance(normIdeal, normUser, JointGroup.elbows);
            kneeDistance += _calculatePartialDistance(normIdeal, normUser, JointGroup.knees);
          }

          final double dtwDistance = totalDistance / path.length;
          score = PoseComparator.calculateScoreFromDTW(dtwDistance);
          shoulderScore = PoseComparator.calculateScoreFromDTW(shoulderDistance / path.length);
          hipScore = PoseComparator.calculateScoreFromDTW(hipDistance / path.length);
          elbowScore = PoseComparator.calculateScoreFromDTW(elbowDistance / path.length);
          kneeScore = PoseComparator.calculateScoreFromDTW(kneeDistance / path.length);

          print('V3.0 分析完了！ DTW距離: ${totalDistance / path.length}, 総合スコア: $score');
          analysisResultText += '\n\n部位別スコア:'
              '\n肩: ${shoulderScore.round()}点, 腰: ${hipScore.round()}点'
              '\n肘: ${elbowScore.round()}点, 膝: ${kneeScore.round()}点';
        }
      }

      setState(() { _analysisStatus = '結果を保存中...'; });
      final List<dynamic> idealPosesForDb = _convertPosesToDbFormat(idealPoses);
      final List<dynamic> userPosesForDb = _convertPosesToDbFormat(userPoses);

      final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
      final session = AnalysisSession(
        id: sessionId,
        createdAt: DateTime.now(),
        score: score,
        analysisType: "V3_RangeDTW",
        idealImagePath: idealThumbnailPath,
        idealVideoPath: _idealVideoFile!.path,
        idealStartTimeMs: _idealRange!.start,
        idealEndTimeMs: _idealRange!.end,
        idealPoseLandmarks: idealPosesForDb,
        idealImageWidth: idealVideoSize.width,
        idealImageHeight: idealVideoSize.height,
        imagePath: userThumbnailPath,
        videoPath: _userVideoFile!.path,
        userStartTimeMs: _userRange!.start,
        userEndTimeMs: _userRange!.end,
        userPoseLandmarks: userPosesForDb,
        imageWidth: userVideoSize.width,
        imageHeight: userVideoSize.height,
        imageRotation: 0,

        // ピッチング用
        idealSSEAngle: idealSSEAngle,
        userSSEAngle: userSSEAngle,
        idealReleaseHeight: idealReleaseHeight,
        userReleaseHeight: userReleaseHeight,
        idealReleaseSide: idealReleaseSide,
        userReleaseSide: userReleaseSide,

        // ★ バッティング用 (新指標のみ)
        idealBodyTilt: idealBodyTilt,
        userBodyTilt: userBodyTilt,
        idealWeightShift: idealWeightShift,
        userWeightShift: userWeightShift,
        idealHeadStability: idealHeadStability,
        userHeadStability: userHeadStability,

        // 古い指標 (XFactor等) は保存しない (null)

        shoulderScore: shoulderScore,
        hipScore: hipScore,
        elbowScore: elbowScore,
        kneeScore: kneeScore,
      );

      await DatabaseService().saveAnalysisSession(session);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 10),
            content: Text('分析完了！ 総合スコア: ${score.toStringAsFixed(1)} 点$analysisResultText'),
          ),
        );
      }
    } catch (e) {
      print('分析処理中にエラーが発生しました: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('分析エラー: $e')));
    } finally {
      try { if (await File(tempFramePath).exists()) await File(tempFramePath).delete(); } catch (_) {}
      await _videoService.clearTemporaryRangeFrames('frames_ideal');
      await _videoService.clearTemporaryRangeFrames('frames_user');
      setState(() { _isAnalyzing = false; });
      if (mounted) Navigator.of(context).pop();
    }
  }

  // (以下のヘルパー関数は変更なし)
  Future<List<Pose>> _processVideoSequentially({required File videoFile, required RangeValues range, required String tempFramePath}) async {
    final List<Pose> posesList = [];
    const frameInterval = Duration(milliseconds: 33); // 30fps
    final File tempFile = File(tempFramePath);
    for (var i = range.start.toInt(); i < range.end.toInt(); i += frameInterval.inMilliseconds) {
      final Uint8List? frameBytes = await VideoThumbnail.thumbnailData(video: videoFile.path, imageFormat: ImageFormat.JPEG, timeMs: i, quality: 70);
      if (frameBytes == null) continue;
      await tempFile.writeAsBytes(frameBytes);
      final inputImage = InputImage.fromFilePath(tempFile.path);
      final detectedPoses = await _poseService.processImage(inputImage);
      if (detectedPoses.isNotEmpty) posesList.add(detectedPoses.first);
    }
    return posesList;
  }
  List<dynamic> _convertPosesToDbFormat(List<Pose> poses) {
    final List<dynamic> allPosesLandmarks = [];
    for (final pose in poses) {
      final List<dynamic> frameLandmarks = [];
      pose.landmarks.forEach((key, value) { frameLandmarks.add(key); frameLandmarks.add(LandmarkPoint(x: value.x, y: value.y)); });
      allPosesLandmarks.add(frameLandmarks);
    }
    return allPosesLandmarks;
  }
  Future<void> _generateThumbnail({required String videoPath, required int timeMs, required String outputPath}) async {
    final Uint8List? frameBytes = await VideoThumbnail.thumbnailData(video: videoPath, imageFormat: ImageFormat.JPEG, timeMs: timeMs, quality: 80);
    if (frameBytes != null) await File(outputPath).writeAsBytes(frameBytes);
    else throw Exception('サムネイルの生成に失敗しました');
  }
  bool _checkIsPitchingMotion(List<Pose> poses) {
    if (poses.isEmpty) return false;
    for (final pose in poses) {
      final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
      final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];
      if (leftHip != null && leftKnee != null && leftKnee.y < leftHip.y) return true;
      final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
      final rightKnee = pose.landmarks[PoseLandmarkType.rightKnee];
      if (rightHip != null && rightKnee != null && rightKnee.y < rightHip.y) return true;
    }
    return false;
  }
  double _analyzePitchingSSE(List<Pose> poses, {required bool isRightHanded}) {
    if (poses.isEmpty) return -1.0;
    int maxDistanceIndex = 0;
    double maxDistance = -1.0;
    for (int i = 0; i < poses.length; i++) {
      final distance = PoseComparator.getShoulderDistance(poses[i]);
      if (distance > maxDistance) { maxDistance = distance; maxDistanceIndex = i; }
    }
    final int windowSize = 2;
    final int startIndex = max(0, maxDistanceIndex - windowSize);
    final int endIndex = min(poses.length - 1, maxDistanceIndex + windowSize);
    double totalAngle = 0;
    int validFrames = 0;
    for (int i = startIndex; i <= endIndex; i++) {
      final angle = PoseComparator.getSSEAngle(poses[i], isRightHanded: isRightHanded);
      if (angle != -1.0) { totalAngle += angle; validFrames++; }
    }
    return (validFrames > 0) ? (totalAngle / validFrames) : -1.0;
  }

  // ( _analyzeBattingMetrics は削除しました )

  double _calculatePartialDistance(Map<PoseLandmarkType, PoseLandmark> pose1, Map<PoseLandmarkType, PoseLandmark> pose2, JointGroup group) {
    const Map<JointGroup, List<PoseLandmarkType>> jointGroups = {
      JointGroup.shoulders: [PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder],
      JointGroup.hips: [PoseLandmarkType.leftHip, PoseLandmarkType.rightHip],
      JointGroup.elbows: [PoseLandmarkType.leftElbow, PoseLandmarkType.rightElbow],
      JointGroup.knees: [PoseLandmarkType.leftKnee, PoseLandmarkType.rightKnee],
    };
    final List<PoseLandmarkType> jointsToCompare = jointGroups[group] ?? [];
    double totalDistance = 0;
    int jointCount = 0;
    for (final type in jointsToCompare) {
      if (pose1.containsKey(type) && pose2.containsKey(type)) {
        final landmark1 = pose1[type]!;
        final landmark2 = pose2[type]!;
        totalDistance += sqrt(pow(landmark1.x - landmark2.x, 2) + pow(landmark1.y - landmark2.y, 2));
        jointCount++;
      }
    }
    return (jointCount > 0) ? (totalDistance / jointCount) : 0.0;
  }
  // (build メソッドは省略せず記述)
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('区間比較 (B案)')),
      body: Stack(children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _buildVideoSelectorCard(title: '1. お手本動画', icon: Icons.star, color: Colors.amber, isLoading: _isLoadingIdeal, selectedFile: _idealVideoFile, onPressed: () => _pickVideo(true)),
            if (_idealController != null && _idealRange != null) _buildVideoControls(controller: _idealController!, range: _idealRange!, onRangeChanged: (newRange) { setState(() { _idealRange = newRange; }); _idealController!.seekTo(Duration(milliseconds: newRange.start.toInt())); }, onPlayPause: () { setState(() { _idealController!.value.isPlaying ? _idealController!.pause() : _idealController!.play(); }); }),
            const SizedBox(height: 24),
            _buildVideoSelectorCard(title: '2. あなたの動画', icon: Icons.videocam, color: Colors.teal, isLoading: _isLoadingUser, selectedFile: _userVideoFile, onPressed: () => _pickVideo(false)),
            if (_userController != null && _userRange != null) _buildVideoControls(controller: _userController!, range: _userRange!, onRangeChanged: (newRange) { setState(() { _userRange = newRange; }); _userController!.seekTo(Duration(milliseconds: newRange.start.toInt())); }, onPlayPause: () { setState(() { _userController!.value.isPlaying ? _userController!.pause() : _userController!.play(); }); }),
            const SizedBox(height: 40),
            ElevatedButton.icon(icon: const Icon(Icons.analytics), label: const Text('分析開始'), style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, textStyle: const TextStyle(fontSize: 18)), onPressed: (_idealRange != null && _userRange != null && !_isAnalyzing) ? _startAnalysis : null),
            const SizedBox(height: 40),
          ]),
        ),
        if (_isAnalyzing) Container(color: Colors.black.withOpacity(0.5), child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const CircularProgressIndicator(), const SizedBox(height: 16), Text(_analysisStatus, style: const TextStyle(color: Colors.white, fontSize: 18))]))),
      ]),
    );
  }
  Widget _buildVideoSelectorCard({required String title, required IconData icon, required Color color, required bool isLoading, required File? selectedFile, required VoidCallback onPressed}) {
    return Card(elevation: 4, child: Padding(padding: const EdgeInsets.all(16.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 16), Center(child: ElevatedButton.icon(icon: Icon(icon), label: Text(selectedFile == null ? '動画を選択' : '動画を変更'), style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white), onPressed: isLoading ? null : onPressed)), const SizedBox(height: 16), if (isLoading) const Center(child: CircularProgressIndicator()) else if (selectedFile != null) Container(padding: const EdgeInsets.all(8.0), decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)), child: Row(children: [Icon(Icons.check_circle, color: Colors.green, size: 18), SizedBox(width: 8), Flexible(child: Text(selectedFile.path.split(Platform.pathSeparator).last, style: const TextStyle(fontStyle: FontStyle.italic), overflow: TextOverflow.ellipsis, softWrap: false))])) else const Center(child: Text('動画が選択されていません'))])));
  }
  Widget _buildVideoControls({required VideoPlayerController controller, required RangeValues range, required Function(RangeValues) onRangeChanged, required VoidCallback onPlayPause}) {
    final double maxDuration = controller.value.duration.inMilliseconds.toDouble();
    String _formatDuration(double ms) {
      final duration = Duration(milliseconds: ms.toInt());
      return '${duration.inMinutes.remainder(60).toString().padLeft(2, '0')}:${duration.inSeconds.remainder(60).toString().padLeft(2, '0')}.${(duration.inMilliseconds.remainder(1000) ~/ 100)}';
    }
    return Padding(padding: const EdgeInsets.only(top: 16.0), child: Column(children: [AspectRatio(aspectRatio: controller.value.aspectRatio, child: VideoPlayer(controller)), IconButton(icon: Icon(controller.value.isPlaying ? Icons.pause : Icons.play_arrow), onPressed: onPlayPause), RangeSlider(values: range, min: 0.0, max: maxDuration, labels: RangeLabels(_formatDuration(range.start), _formatDuration(range.end)), onChanged: onRangeChanged)]));
  }
}