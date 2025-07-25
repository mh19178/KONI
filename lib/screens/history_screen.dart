import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../models/analysis_session.dart';
import '../providers/services_provider.dart';
import '../services/database_service.dart';
import 'analysis_detail_screen.dart';

class HistoryScreen extends ConsumerWidget {
  // ★★★ MainScreenからタブ切り替え用の関数を受け取る
  final void Function(int) onTabTapped;

  const HistoryScreen({super.key, required this.onTabTapped});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsyncValue = ref.watch(sessionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('分析履歴'),
      ),
      body: sessionsAsyncValue.when(
        data: (sessions) {
          if (sessions.isEmpty) {
            // ★★★ 空画面のUIを修正 ★★★
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.history_toggle_off, size: 80, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text('分析履歴はまだありません。', style: TextStyle(fontSize: 18)),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('最初の分析を始める'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      onPressed: () {
                        // ★★★ 受け取った関数を呼び出してタブを切り替える ★★★
                        onTabTapped(1);
                      },
                    )
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              return Dismissible(
                key: Key(session.id),
                onDismissed: (direction) {
                  DatabaseService().deleteSession(session.id);
                  ref.invalidate(sessionsProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${DateFormat('yyyy/MM/dd HH:mm').format(session.createdAt)} のデータを削除しました')),
                  );
                },
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: Image.file(
                      File(session.imagePath),
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                    ),
                    title: Text(
                      DateFormat('yyyy/MM/dd HH:mm').format(session.createdAt),
                    ),
                    subtitle: Text(
                      'Score: ${session.score.toStringAsFixed(1)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => AnalysisDetailScreen(session: session)),
                      ).then((_) {
                        // 詳細画面から戻ってきたときにリストを再読み込み
                        ref.invalidate(sessionsProvider);
                      });
                    },
                  ),
                ),
              );
            },
          );
        },
        loading: () => Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: ListView.builder(
            itemCount: 5,
            itemBuilder: (context, index) {
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: Container(width: 56, height: 56, color: Colors.white),
                  title: Container(
                    height: 16,
                    width: 150,
                    color: Colors.white,
                  ),
                  subtitle: Container(
                    height: 20,
                    width: 100,
                    color: Colors.white,
                    margin: const EdgeInsets.only(top: 8),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                ),
              );
            },
          ),
        ),
        error: (err, stack) => Center(child: Text('エラーが発生しました: $err')),
      ),
    );
  }
}