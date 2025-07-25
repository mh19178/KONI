import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/analysis_session.dart';
import '../providers/services_provider.dart';
import 'video_analysis_screen.dart'; // ★★★ このimport文が重要です ★★★

class HomeScreen extends ConsumerWidget {
  final void Function(int) onTabTapped;
  const HomeScreen({super.key, required this.onTabTapped});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latestSession = ref.watch(latestSessionProvider);
    final recentSessions = ref.watch(recentSessionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ホーム'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 最新スコア表示カード
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const Text('最新のスコア', style: TextStyle(fontSize: 18, color: Colors.grey)),
                    const SizedBox(height: 16),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      transitionBuilder: (child, animation) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                      child: latestSession == null
                          ? const Text(
                        'データなし',
                        key: ValueKey('no_data'),
                        style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
                      )
                          : Text(
                        latestSession.score.toStringAsFixed(1),
                        key: ValueKey(latestSession.id),
                        style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // スコア推移グラフカード
            const Text('スコア推移', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                child: SizedBox(
                  height: 150,
                  child: recentSessions.isEmpty
                      ? const Center(child: Text('データが不足しています'))
                      : LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: true),
                      titlesData: const FlTitlesData(
                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: true),
                      minY: 0,
                      maxY: 100,
                      lineBarsData: [
                        LineChartBarData(
                          spots: List.generate(recentSessions.length, (index) {
                            final session = recentSessions.reversed.toList()[index];
                            return FlSpot(index.toDouble(), session.score);
                          }).toList(),
                          isCurved: true,
                          color: Colors.deepPurple,
                          barWidth: 4,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(show: false),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            // 分析開始ボタン
            ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt, size: 28),
              label: const Text('写真から分析する', style: TextStyle(fontSize: 20)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.orangeAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                onTabTapped(1);
              },
            ),
            const SizedBox(height: 16),
            // 動画分析ボタン
            ElevatedButton.icon(
              icon: const Icon(Icons.movie, size: 28),
              label: const Text('動画から分析する', style: TextStyle(fontSize: 20)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const VideoAnalysisScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}