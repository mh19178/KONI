import 'dart:io';
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'package:path_provider/path_provider.dart';

class VideoProcessingService {
  // 動画ファイルを受け取り、抽出したフレーム画像のリストを返す
  Future<List<File>> extractFrames(File videoFile) async {
    final Directory tempDir = await getTemporaryDirectory();
    final String outputDir = '${tempDir.path}/frames';

    if (await Directory(outputDir).exists()) {
      await Directory(outputDir).delete(recursive: true);
    }
    await Directory(outputDir).create(recursive: true);

    final String command = '-i ${videoFile.path} -vf fps=10 $outputDir/frame_%04d.png';

    print('FFmpegコマンドを実行します: $command');
    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (returnCode!.isValueSuccess()) {
      print('フレーム抽出に成功しました。');
      final List<File> frameFiles = Directory(outputDir).listSync()
          .where((item) => item.path.endsWith('.png'))
          .map((item) => File(item.path))
          .toList();
      frameFiles.sort((a, b) => a.path.compareTo(b.path));
      return frameFiles;
    } else {
      print('フレーム抽出に失敗しました。');
      final logs = await session.getLogsAsString();
      print('FFmpeg logs: $logs');
      // 失敗した場合も一時ディレクトリを削除
      await clearTemporaryFrames();
      return [];
    }
  }

  // ★★★ このメソッドが追加されていることを確認 ★★★
  // フレームを保存した一時ディレクトリを削除する
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