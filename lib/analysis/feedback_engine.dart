import 'pose_comparator.dart';

class FeedbackEngine {
  // 引数をスコアに変更
  static String generateFeedback(double score) {
    if (score >= 95) {
      return '素晴らしい！ほぼ完璧なフォームです。';
    } else if (score >= 80) {
      return 'とても良いフォームです。細部を意識するとさらに良くなります。';
    } else if (score >= 60) {
      return '良いフォームですが、いくつか改善点があります。';
    } else if (score >= 40) {
      return '改善の余地が大きいようです。お手本と見比べてみましょう。';
    } else {
      return '基本から見直してみましょう。まずはお手本のポーズをじっくり観察することが重要です。';
    }
  }
}