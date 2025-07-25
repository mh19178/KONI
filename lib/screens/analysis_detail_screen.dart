import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:intl/intl.dart';
import '../analysis/feedback_engine.dart';
import '../models/analysis_session.dart';
import '../models/landmark_point.dart';
import '../services/database_service.dart';
import 'pose_painter.dart';

class AnalysisDetailScreen extends StatefulWidget {
  final AnalysisSession session;

  const AnalysisDetailScreen({super.key, required this.session});

  @override
  State<AnalysisDetailScreen> createState() => _AnalysisDetailScreenState();
}

class _AnalysisDetailScreenState extends State<AnalysisDetailScreen> {
  late final TextEditingController _commentController;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController(text: widget.session.coachComment);
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Map<PoseLandmarkType, PoseLandmark> _reconstructLandmarks(List<dynamic> landmarkData) {
    final landmarks = <PoseLandmarkType, PoseLandmark>{};
    for (int i = 0; i < landmarkData.length; i += 2) {
      final type = landmarkData[i] as PoseLandmarkType;
      final point = landmarkData[i + 1] as LandmarkPoint;
      landmarks[type] = PoseLandmark(
        type: type,
        x: point.x,
        y: point.y,
        z: 0,
        likelihood: 1.0,
      );
    }
    return landmarks;
  }

  Future<void> _saveComment() async {
    widget.session.coachComment = _commentController.text;
    await DatabaseService().updateSession(widget.session);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('コメントを保存しました。'))
      );
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final userPose = Pose(landmarks: _reconstructLandmarks(widget.session.userPoseLandmarks));
    final idealPose = Pose(landmarks: _reconstructLandmarks(widget.session.idealPoseLandmarks));
    final feedback = FeedbackEngine.generateFeedback(widget.session.score);

    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat('yyyy/MM/dd HH:mm').format(widget.session.createdAt)),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.star, color: Colors.white),
            label: const Text('お手本に設定', style: TextStyle(color: Colors.white)),
            onPressed: () async {
              // 詳細画面に表示されているのは、あくまで過去のセッションのデータ。
              // お手本として保存する際は、そのセッションの「ユーザーポーズ」をお手本として保存するのが直感的。
              // そのため、sessionオブジェクトのimagePathとuserPoseLandmarksをお手本として渡す。
              final idealSession = AnalysisSession(
                id: widget.session.id,
                createdAt: widget.session.createdAt,
                imagePath: widget.session.imagePath, // このセッションのユーザー画像を理想画像として使う
                idealImagePath: widget.session.imagePath,
                score: widget.session.score,
                userPoseLandmarks: widget.session.userPoseLandmarks,
                idealPoseLandmarks: widget.session.userPoseLandmarks,
                imageWidth: widget.session.imageWidth,
                imageHeight: widget.session.imageHeight,
                idealImageWidth: widget.session.imageWidth,
                idealImageHeight: widget.session.imageHeight,
                imageRotation: widget.session.imageRotation,
              );
              await DatabaseService().saveIdealPose(idealSession);

              if(mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('新しい理想のフォームとして設定しました！'))
                );
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: Text(
                    'Score: ${widget.session.score.toStringAsFixed(1)}',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text('Your Pose', style: Theme.of(context).textTheme.titleLarge),
                Text('Ideal Pose', style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 300,
              child: Row(
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        Image.file(File(widget.session.imagePath), fit: BoxFit.contain),
                        CustomPaint(
                          size: Size.infinite,
                          painter: PosePainter(
                            [userPose],
                            Size(widget.session.imageWidth, widget.session.imageHeight),
                            InputImageRotationValue.fromRawValue(widget.session.imageRotation) ?? InputImageRotation.rotation0deg,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const VerticalDivider(width: 24, thickness: 1),
                  Expanded(
                    child: Stack(
                      children: [
                        Image.file(File(widget.session.idealImagePath), fit: BoxFit.contain),
                        CustomPaint(
                          size: Size.infinite,
                          painter: PosePainter(
                            [idealPose],
                            Size(widget.session.idealImageWidth, widget.session.idealImageHeight),
                            InputImageRotationValue.fromRawValue(widget.session.imageRotation) ?? InputImageRotation.rotation0deg,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: ListTile(
                leading: const Icon(Icons.lightbulb, color: Colors.orangeAccent, size: 40),
                title: const Text('AIからのアドバイス', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(feedback),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.edit_note, color: Colors.purple, size: 40),
                      title: Text('コーチからのコメント', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _commentController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: '気づいた点をメモしましょう...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: _saveComment,
                        child: const Text('コメントを保存'),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}