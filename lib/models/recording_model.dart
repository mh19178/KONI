import 'package:hive/hive.dart';

// この行はHiveのコードジェネレータがよしなにファイルを生成するために必要です
part 'recording_model.g.dart';

@HiveType(typeId: 0)
class Recording extends HiveObject {

  @HiveField(0)
  final String id;

  @HiveField(1)
  final String videoPath; // 録画した動画ファイルの保存場所

  @HiveField(2)
  final DateTime createdAt; // 作成日時

  // まだ分析結果はないので、一旦コメントアウトしておきます
  // @HiveField(3)
  // final AnalysisResult result;

  Recording({
    required this.id,
    required this.videoPath,
    required this.createdAt,
  });
}