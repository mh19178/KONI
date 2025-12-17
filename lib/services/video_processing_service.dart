import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class VideoProcessingService {

  // (V2.0用の関数: 動画全体を抽出)
  Future<List<File>> extractFrames(File videoFile) async {
    print('フレーム抽出(V2.0 全体)を開始します...');
    // (中身は変更なし)
    final videoPlayerController = VideoPlayerController.file(videoFile);
    await videoPlayerController.initialize();
    final totalDuration = videoPlayerController.value.duration;
    await videoPlayerController.dispose();

    final List<File> frameFiles = [];
    const frameInterval = Duration(milliseconds: 100);
    final Directory tempDir = await getTemporaryDirectory();
    final String outputDir = '${tempDir.path}/frames';
    if (await Directory(outputDir).exists()) {
      await Directory(outputDir).delete(recursive: true);
    }
    await Directory(outputDir).create(recursive: true);

    for (var i = 0; i < totalDuration.inMilliseconds; i += frameInterval.inMilliseconds) {
      final Uint8List? frameBytes = await VideoThumbnail.thumbnailData(
        video: videoFile.path,
        imageFormat: ImageFormat.JPEG,
        timeMs: i,
        quality: 80,
      );
      if (frameBytes != null) {
        final frameFile = File('$outputDir/frame_${i.toString().padLeft(6, '0')}.jpeg');
        await frameFile.writeAsBytes(frameBytes);
        frameFiles.add(frameFile);
      }
    }
    print('${frameFiles.length} フレームの抽出に成功しました。');
    return frameFiles;
  }

  // ★★★ ここから追加 (V3.0用) ★★★

  /// (V3.0用) 指定された時間範囲（ミリ秒）からフレームを抽出する
  Future<List<File>> extractFramesFromRange({
    required File videoFile,
    required double startTimeMs,
    required double endTimeMs,
    required String outputDirName, // (例: 'frames_ideal' または 'frames_user')
  }) async {
    print('フレーム抽出(V3.0 区間)を開始します...');
    print('区間: $startTimeMs ms ～ $endTimeMs ms');

    final List<File> frameFiles = [];
    // 1秒あたり10フレーム（100ms間隔）で抽出
    const frameInterval = Duration(milliseconds: 100);

    // 一時フォルダ作成 (V2.0とフォルダを分ける)
    final Directory tempDir = await getTemporaryDirectory();
    final String outputDir = '${tempDir.path}/$outputDirName';
    if (await Directory(outputDir).exists()) {
      await Directory(outputDir).delete(recursive: true);
    }
    await Directory(outputDir).create(recursive: true);

    // 指定された区間（startTimeMs から endTimeMs まで）をループ
    for (var i = startTimeMs; i < endTimeMs; i += frameInterval.inMilliseconds) {
      final Uint8List? frameBytes = await VideoThumbnail.thumbnailData(
        video: videoFile.path,
        imageFormat: ImageFormat.JPEG,
        timeMs: i.toInt(), // 指定時間 (ms)
        quality: 80,
      );

      if (frameBytes != null) {
        // ファイル名を時系列に（0埋め）
        final fileName = 'frame_${i.toInt().toString().padLeft(8, '0')}.jpeg';
        final frameFile = File('$outputDir/$fileName');
        await frameFile.writeAsBytes(frameBytes);
        frameFiles.add(frameFile);
      }
    }

    print('区間から ${frameFiles.length} フレームの抽出に成功しました。');
    return frameFiles;
  }
  // ★★★ ここまで追加 ★★★

  /// 一時フォルダを削除 (V2.0用)
  Future<void> clearTemporaryFrames() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final framesDir = Directory('${tempDir.path}/frames');
      if (await framesDir.exists()) {
        await framesDir.delete(recursive: true);
        print('一時フレームファイル(V2.0)を削除しました。');
      }
    } catch (e) {
      print('一時ファイルの削除に失敗しました: $e');
    }
  }

  // ★★★ ここから追加 (V3.0用) ★★★
  /// 一時フォルダ（V3.0用）を削除
  Future<void> clearTemporaryRangeFrames(String outputDirName) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final framesDir = Directory('${tempDir.path}/$outputDirName');
      if (await framesDir.exists()) {
        await framesDir.delete(recursive: true);
        print('一時フレームファイル($outputDirName)を削除しました。');
      }
    } catch (e) {
      print('一時ファイルの削除に失敗しました: $e');
    }
  }
// ★★★ ここまで追加 ★★★
}