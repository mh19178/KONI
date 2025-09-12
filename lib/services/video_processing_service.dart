import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:video_editor/video_editor.dart';

class VideoProcessingService {
  Future<List<File>> extractFrames(File videoFile) async {
    print('フレーム抽出を開始します...');

    final controller = VideoEditorController.file(videoFile);
    await controller.initialize();

    final List<File> frameFiles = [];
    // 1秒あたり10フレーム（100ミリ秒ごと）の間隔でフレームを抽出
    const frameInterval = Duration(milliseconds: 100);
    final totalDuration = controller.video.value.duration;

    final Directory tempDir = await getTemporaryDirectory();
    final String outputDir = '${tempDir.path}/frames';
    if (await Directory(outputDir).exists()) {
      await Directory(outputDir).delete(recursive: true);
    }
    await Directory(outputDir).create(recursive: true);

    // 動画の最初から最後まで、指定した間隔でループ
    for (var i = 0; i < totalDuration.inMilliseconds; i += frameInterval.inMilliseconds) {
      final time = Duration(milliseconds: i);

      // 指定した時間のフレームを画像データ(Uint8List)として生成
      final Uint8List? frameBytes = await controller.thumbnailData(
        time: time,
        quality: 80, // 画質を少し落として処理を高速化
      );

      if (frameBytes != null) {
        // 画像データをファイルとして一時保存
        final frameFile = File('$outputDir/frame_${i.toString().padLeft(6, '0')}.jpeg');
        await frameFile.writeAsBytes(frameBytes);
        frameFiles.add(frameFile);
      }
    }

    controller.dispose();

    print('${frameFiles.length} フレームの抽出に成功しました。');
    return frameFiles;
  }

  Future<void> clearTemporaryFrames() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final framesDir = Directory('${tempDir.path}/frames');
      if (await framesDir.exists()) {
        await framesDir.delete(recursive: true);
        print('一時フレームファイルを削除しました。');
      }
    } catch(e) {
      print('一時ファイルの削除に失敗しました: $e');
    }
  }
}