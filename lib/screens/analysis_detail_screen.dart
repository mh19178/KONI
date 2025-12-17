import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
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

  VideoPlayerController? _userVideoController;
  VideoPlayerController? _idealVideoController;

  List<Pose?> _userPoses = [];
  List<Pose?> _idealPoses = [];

  bool _isV3Analysis = false;
  bool _isPlaying = false;
  bool _playRequested = false;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController(text: widget.session.coachComment);

    if (widget.session.analysisType == "V3_RangeDTW") {
      _isV3Analysis = true;

      if (widget.session.videoPath != null && widget.session.idealVideoPath != null) {

        _userVideoController = VideoPlayerController.file(
          File(widget.session.videoPath!),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        )
          ..initialize().then((_) {
            _userVideoController!.seekTo(Duration(milliseconds: widget.session.userStartTimeMs?.toInt() ?? 0));
            _userVideoController!.addListener(_checkIfVideoEnded);
            _userVideoController!.setVolume(0.0);
            setState(() {});
          });

        _idealVideoController = VideoPlayerController.file(
          File(widget.session.idealVideoPath!),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        )
          ..initialize().then((_) {
            _idealVideoController!.seekTo(Duration(milliseconds: widget.session.idealStartTimeMs?.toInt() ?? 0));
            _idealVideoController!.addListener(_checkIfVideoEnded);
            _idealVideoController!.setVolume(0.0);
            setState(() {});
          });

        _userPoses = (widget.session.userPoseLandmarks as List).map((frameData) {
          if (frameData is List && frameData.isNotEmpty) {
            return Pose(landmarks: _reconstructLandmarks(frameData));
          } return null;
        }).toList();
        _idealPoses = (widget.session.idealPoseLandmarks as List).map((frameData) {
          if (frameData is List && frameData.isNotEmpty) {
            return Pose(landmarks: _reconstructLandmarks(frameData));
          } return null;
        }).toList();
      }

    } else {
      _isV3Analysis = false;
      if (widget.session.videoPath != null) {
        _userVideoController = VideoPlayerController.file(
          File(widget.session.videoPath!),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        )
          ..initialize().then((_) {
            setState(() {});
            _userVideoController?.setLooping(true);
            _userVideoController!.addListener(_checkIfVideoEnded);
            _userVideoController!.setVolume(0.0);
          });
        _userPoses = (widget.session.userPoseLandmarks as List).map((frameData) {
          if (frameData is List && frameData.isNotEmpty) {
            return Pose(landmarks: _reconstructLandmarks(frameData));
          } return null;
        }).toList();
      }
      _idealPoses.add(Pose(landmarks: _reconstructLandmarks(widget.session.idealPoseLandmarks)));
    }
  }

  @override
  void dispose() {
    _userVideoController?.removeListener(_checkIfVideoEnded);
    _idealVideoController?.removeListener(_checkIfVideoEnded);
    _userVideoController?.dispose();
    _idealVideoController?.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Map<PoseLandmarkType, PoseLandmark> _reconstructLandmarks(List<dynamic> landmarkData) {
    final landmarks = <PoseLandmarkType, PoseLandmark>{};
    List<dynamic> dataToParse = landmarkData;
    if (landmarkData.isNotEmpty && landmarkData.first is List) {
      dataToParse = (landmarkData as List).firstWhere(
            (frame) => frame is List && frame.isNotEmpty,
        orElse: () => [],
      );
    }
    try {
      for (int i = 0; i < dataToParse.length; i += 2) {
        final type = dataToParse[i] as PoseLandmarkType;
        final point = dataToParse[i + 1] as LandmarkPoint;
        landmarks[type] = PoseLandmark(
            type: type, x: point.x, y: point.y, z: 0, likelihood: 1.0);
      }
    } catch (e) {
      print('Error reconstructing landmarks: $e');
    }
    return landmarks;
  }

  Future<void> _saveComment() async {
    widget.session.coachComment = _commentController.text;
    await DatabaseService().updateSession(widget.session);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('コメントを保存しました。')));
      FocusScope.of(context).unfocus();
    }
  }

  void _checkIfVideoEnded() {
    if (!_playRequested) return;
    bool oneVideoEnded = false;
    if (_isV3Analysis) {
      final userEndMs = (widget.session.userEndTimeMs ?? 0).toInt();
      final userCurrentMs = _userVideoController?.value.position.inMilliseconds ?? 0;
      final idealEndMs = (widget.session.idealEndTimeMs ?? 0).toInt();
      final idealCurrentMs = _idealVideoController?.value.position.inMilliseconds ?? 0;
      if ((userCurrentMs >= userEndMs - 100) || (idealCurrentMs >= idealEndMs - 100)) {
        oneVideoEnded = true;
      }
    } else if (_userVideoController != null && _userVideoController!.value.isInitialized && _userVideoController!.value.isLooping == false) {
      final duration = _userVideoController!.value.duration.inMilliseconds;
      final position = _userVideoController!.value.position.inMilliseconds;
      if (duration > 0 && position >= duration - 100) {
        oneVideoEnded = true;
      }
    }
    if (oneVideoEnded) {
      _userVideoController?.pause();
      _idealVideoController?.pause();
      if (_isV3Analysis) {
        _userVideoController?.seekTo(Duration(milliseconds: widget.session.userStartTimeMs?.toInt() ?? 0));
        _idealVideoController?.seekTo(Duration(milliseconds: widget.session.idealStartTimeMs?.toInt() ?? 0));
      } else {
        _userVideoController?.seekTo(Duration.zero);
      }
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _isPlaying = false;
              _playRequested = false;
            });
          }
        });
      }
    }
  }

  void _togglePlayPause() async {
    final bool currentlyPlaying = _isPlaying;
    setState(() {
      _isPlaying = !currentlyPlaying;
    });
    if (currentlyPlaying) {
      _playRequested = false;
      await Future.wait([
        if (_userVideoController != null) _userVideoController!.pause(),
        if (_idealVideoController != null) _idealVideoController!.pause(),
      ]);
    } else {
      if (_isV3Analysis) {
        final userEndMs = (widget.session.userEndTimeMs ?? 0).toInt();
        final userStartMs = (widget.session.userStartTimeMs ?? 0).toInt();
        if ((_userVideoController?.value.position.inMilliseconds ?? 0) >= userEndMs - 100) {
          await _userVideoController?.seekTo(Duration(milliseconds: userStartMs));
        }
        final idealEndMs = (widget.session.idealEndTimeMs ?? 0).toInt();
        final idealStartMs = (widget.session.idealStartTimeMs ?? 0).toInt();
        if ((_idealVideoController?.value.position.inMilliseconds ?? 0) >= idealEndMs - 100) {
          await _idealVideoController?.seekTo(Duration(milliseconds: idealStartMs));
        }
      } else if (_userVideoController != null && !_userVideoController!.value.isLooping) {
        if (_userVideoController!.value.position >= _userVideoController!.value.duration) {
          await _userVideoController?.seekTo(Duration.zero);
        }
      }

      if (_isPlaying && mounted) {
        _playRequested = true;
        Future.wait([
          if (_userVideoController != null) _userVideoController!.play(),
          if (_idealVideoController != null) _idealVideoController!.play(),
        ]);
      } else {
        _playRequested = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedback = FeedbackEngine.generateFeedback(widget.session.score);

    Widget userPoseWidget;
    Widget idealPoseWidget;

    if (_userVideoController != null && _userVideoController!.value.isInitialized) {
      userPoseWidget = Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: _userVideoController!.value.aspectRatio,
            child: VideoPlayer(_userVideoController!),
          ),
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: _userVideoController!,
            builder: (context, value, child) {
              double intervalMs = 100.0;
              final double startMs = _isV3Analysis ? (widget.session.userStartTimeMs ?? 0) : 0;
              if (_isV3Analysis && _userPoses.isNotEmpty) {
                final double endMs = widget.session.userEndTimeMs ?? _userVideoController!.value.duration.inMilliseconds.toDouble();
                final double durationMs = endMs - startMs;
                if (durationMs > 0 && _userPoses.length > 0) {
                  intervalMs = durationMs / _userPoses.length;
                }
              }
              final int frameIndex = ((value.position.inMilliseconds - startMs) / intervalMs).floor();
              if (frameIndex < 0 || frameIndex >= _userPoses.length) return const SizedBox.shrink();
              final currentPose = _userPoses[frameIndex];
              if (currentPose == null) return const SizedBox.shrink();
              return CustomPaint(
                size: _userVideoController!.value.size,
                painter: PosePainter(
                  [currentPose],
                  _userVideoController!.value.size,
                  InputImageRotation.rotation0deg,
                ),
              );
            },
          ),
        ],
      );
    } else {
      final userPose = Pose(landmarks: _reconstructLandmarks(widget.session.userPoseLandmarks));
      userPoseWidget = Stack(
        children: [
          Image.file(File(widget.session.imagePath), fit: BoxFit.contain,
            errorBuilder: (c, e, s) => Container(color: Colors.black, child: Icon(Icons.broken_image, color: Colors.white)),
          ),
          CustomPaint(
            size: Size.infinite,
            painter: PosePainter(
              [userPose],
              Size(widget.session.imageWidth, widget.session.imageHeight),
              InputImageRotationValue.fromRawValue(widget.session.imageRotation) ?? InputImageRotation.rotation0deg,
            ),
          ),
        ],
      );
    }

    if (_isV3Analysis && _idealVideoController != null && _idealVideoController!.value.isInitialized) {
      idealPoseWidget = Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: _idealVideoController!.value.aspectRatio,
            child: VideoPlayer(_idealVideoController!),
          ),
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: _idealVideoController!,
            builder: (context, value, child) {
              double intervalMs = 100.0;
              final double startMs = widget.session.idealStartTimeMs ?? 0;
              if (_idealPoses.isNotEmpty) {
                final double endMs = widget.session.idealEndTimeMs ?? _idealVideoController!.value.duration.inMilliseconds.toDouble();
                final double durationMs = endMs - startMs;
                if (durationMs > 0 && _idealPoses.length > 0) {
                  intervalMs = durationMs / _idealPoses.length;
                }
              }
              final int frameIndex = ((value.position.inMilliseconds - startMs) / intervalMs).floor();
              if (frameIndex < 0 || frameIndex >= _idealPoses.length) return const SizedBox.shrink();
              final currentPose = _idealPoses[frameIndex];
              if (currentPose == null) return const SizedBox.shrink();
              return CustomPaint(
                size: _idealVideoController!.value.size,
                painter: PosePainter(
                  [currentPose],
                  _idealVideoController!.value.size,
                  InputImageRotation.rotation0deg,
                ),
              );
            },
          ),
        ],
      );
    } else {
      final idealPose = _idealPoses.isNotEmpty ? _idealPoses.first! : Pose(landmarks: {});
      idealPoseWidget = Stack(
        children: [
          Image.file(File(widget.session.idealImagePath), fit: BoxFit.contain,
            errorBuilder: (c, e, s) => Container(color: Colors.black, child: Icon(Icons.broken_image, color: Colors.white)),
          ),
          CustomPaint(
            size: Size.infinite,
            painter: PosePainter(
              [idealPose],
              Size(widget.session.idealImageWidth, widget.session.idealImageHeight),
              InputImageRotation.rotation0deg,
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat('yyyy/MM/dd HH:mm').format(widget.session.createdAt)),
        actions: [
          if (!_isV3Analysis)
            TextButton.icon(
              icon: const Icon(Icons.star, color: Colors.white),
              label: const Text('お手本に設定', style: TextStyle(color: Colors.white)),
              onPressed: () async { },
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
                  child: Column(
                    children: [
                      const Text('総合スコア (DTW)', style: TextStyle(fontSize: 16, color: Colors.grey)),
                      Text(
                        widget.session.score.toStringAsFixed(1),
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ピッチング用
            if (widget.session.idealSSEAngle != null)
              _buildPitchingMetricsCard(
                idealSSE: widget.session.idealSSEAngle!,
                userSSE: widget.session.userSSEAngle!,
                idealTilt: widget.session.idealBodyTilt,
                userTilt: widget.session.userBodyTilt,
                idealHead: widget.session.idealHeadStability,
                userHead: widget.session.userHeadStability,
                idealRelH: widget.session.idealReleaseHeight,
                userRelH: widget.session.userReleaseHeight,
              ),

            // バッティング用
            if (widget.session.idealBodyTilt != null && widget.session.idealSSEAngle == null)
              _buildBattingMetricsCard(
                idealTilt: widget.session.idealBodyTilt!,
                userTilt: widget.session.userBodyTilt!,
                idealShift: (widget.session.idealWeightShift ?? 0) * 100,
                userShift: (widget.session.userWeightShift ?? 0) * 100,
                idealHead: (widget.session.idealHeadStability ?? 0) * 100,
                userHead: (widget.session.userHeadStability ?? 0) * 100,
              ),

            // 関節別スコア
            if (widget.session.shoulderScore != null)
              _buildJointScoreCard(
                shoulderScore: widget.session.shoulderScore!,
                hipScore: widget.session.hipScore!,
                elbowScore: widget.session.elbowScore!,
                kneeScore: widget.session.kneeScore!,
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
                  Expanded(child: userPoseWidget),
                  const VerticalDivider(width: 24, thickness: 1),
                  Expanded(child: idealPoseWidget),
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
      floatingActionButton: (_userVideoController != null)
          ? FloatingActionButton(
        onPressed: _togglePlayPause,
        child: Icon(
          _isPlaying ? Icons.pause : Icons.play_arrow,
        ),
      )
          : null,
    );
  }

  /// ★★★ ピッチング指標カード (修正) ★★★
  Widget _buildPitchingMetricsCard({
    required double idealSSE, required double userSSE,
    double? idealTilt, double? userTilt,
    double? idealHead, double? userHead,
    double? idealRelH, double? userRelH,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ピッチング指標', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildMetricRow("SSE角度 (肩-肘)", idealSSE, userSSE, "°", isAngle: true),
            if (idealTilt != null && userTilt != null) ...[
              const Divider(),
              _buildMetricRow("体軸の傾き", idealTilt, userTilt, "°", isAngle: true),
            ],
            if (idealHead != null && userHead != null) ...[
              const Divider(),
              _buildMetricRow("頭の移動量", idealHead * 100, userHead * 100, "%", isAngle: false),
            ],
            if (idealRelH != null && userRelH != null) ...[
              const Divider(),
              // ★ 修正: リリース高さも 100倍して % で表示
              _buildMetricRow("リリース高さ", idealRelH * 100, userRelH * 100, "%", isAngle: false),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBattingMetricsCard({
    required double idealTilt, required double userTilt,
    required double idealShift, required double userShift,
    required double idealHead, required double userHead,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('バッティング指標 (平均)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildMetricRow("上体の前傾", idealTilt, userTilt, "°", isAngle: true),
            const Divider(),
            _buildMetricRow("体重移動", idealShift, userShift, "%", isAngle: false),
            const Divider(),
            _buildMetricRow("頭の安定性", idealHead, userHead, "%", isAngle: false),
          ],
        ),
      ),
    );
  }

  /// ★★★ 色判定ロジックの修正 ★★★
  Widget _buildMetricRow(String label, double ideal, double user, String unit, {required bool isAngle}) {
    final double diff = (ideal - user).abs();
    Color diffColor = Colors.green;

    if (isAngle) {
      // 角度の場合 (5度, 10度)
      if (diff > 5) diffColor = Colors.orange;
      if (diff > 10) diffColor = Colors.red;
    } else {
      // ★ %の場合 (10%, 20%)
      if (diff > 10.0) diffColor = Colors.orange;
      if (diff > 20.0) diffColor = Colors.red;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        Column(children: [
          const Text("お手本", style: TextStyle(fontSize: 12, color: Colors.grey)),
          Text('${ideal.toStringAsFixed(1)}$unit', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 18)),
        ]),
        const SizedBox(width: 16),
        Column(children: [
          const Text("あなた", style: TextStyle(fontSize: 12, color: Colors.grey)),
          Text('${user.toStringAsFixed(1)}$unit', style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 18)),
        ]),
        const SizedBox(width: 16),
        Column(children: [
          const Text("ズレ", style: TextStyle(fontSize: 12, color: Colors.grey)),
          Text('${diff.toStringAsFixed(1)}$unit', style: TextStyle(color: diffColor, fontWeight: FontWeight.bold, fontSize: 18)),
        ]),
      ],
    );
  }

  Widget _buildJointScoreCard({
    required double shoulderScore,
    required double hipScore,
    required double elbowScore,
    required double kneeScore,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('関節別スコア', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildScoreIndicator("肩", shoulderScore, _getScoreColor(shoulderScore)),
                _buildScoreIndicator("腰", hipScore, _getScoreColor(hipScore)),
                _buildScoreIndicator("肘", elbowScore, _getScoreColor(elbowScore)),
                _buildScoreIndicator("膝", kneeScore, _getScoreColor(kneeScore)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 90) return Colors.green;
    if (score >= 70) return Colors.orange;
    return Colors.red;
  }

  Widget _buildAngleIndicator(String label, double angle, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.grey),
          overflow: TextOverflow.ellipsis,
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '${angle.toStringAsFixed(1)}°',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
            softWrap: false,
          ),
        ),
      ],
    );
  }

  Widget _buildScoreIndicator(String label, double score, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.grey),
          overflow: TextOverflow.ellipsis,
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '${score.toStringAsFixed(1)}点',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
            softWrap: false,
          ),
        ),
      ],
    );
  }
}