import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/analysis_session.dart';
import '../services/camera_service.dart';
import '../services/database_service.dart';

final cameraServiceProvider = ChangeNotifierProvider((ref) {
  final service = CameraService();
  ref.onDispose(() => service.dispose());
  return service;
});

final sessionsProvider = FutureProvider<List<AnalysisSession>>((ref) {
  return DatabaseService().getAllSessions();
});

// ★★★ ロジックをProvider内に移動 ★★★
final latestSessionProvider = Provider<AnalysisSession?>((ref) {
  final sessions = ref.watch(sessionsProvider).asData?.value ?? [];
  if (sessions.isEmpty) return null;
  return sessions.first;
});

final recentSessionsProvider = Provider<List<AnalysisSession>>((ref) {
  final sessions = ref.watch(sessionsProvider).asData?.value ?? [];
  return sessions.take(5).toList();
});