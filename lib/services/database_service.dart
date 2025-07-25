import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../models/analysis_session.dart';
import '../models/ideal_pose_model.dart';
import '../models/landmark_point.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Future<void> init() async {
    final appDocumentDir = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(appDocumentDir.path);

    Hive.registerAdapter(LandmarkPointAdapter());
    Hive.registerAdapter(PoseLandmarkTypeAdapter());
    Hive.registerAdapter(AnalysisSessionAdapter());
    Hive.registerAdapter(IdealPoseAdapter());

    await Hive.openBox<AnalysisSession>('sessions');
    await Hive.openBox<IdealPose>('ideal_pose_box');
  }

  Future<void> saveAnalysisSession(AnalysisSession session) async {
    final box = Hive.box<AnalysisSession>('sessions');
    await box.put(session.id, session);
    print('Session ${session.id} saved!');
  }

  List<AnalysisSession> getAllSessions() {
    final box = Hive.box<AnalysisSession>('sessions');
    final sessions = box.values.toList();
    sessions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sessions;
  }

  Future<void> updateSession(AnalysisSession session) async {
    await session.save();
    print('Session ${session.id} updated!');
  }

  Future<void> saveIdealPose(AnalysisSession session) async {
    final box = Hive.box<IdealPose>('ideal_pose_box');
    final idealPose = IdealPose(
      idealImagePath: session.imagePath,
      idealPoseLandmarks: session.userPoseLandmarks,
      // ★★★ 画像サイズも一緒に保存 ★★★
      imageWidth: session.imageWidth,
      imageHeight: session.imageHeight,
    );
    await box.put('default', idealPose);
    print('New Ideal Pose has been set!');
  }
  IdealPose? getIdealPose() {
    final box = Hive.box<IdealPose>('ideal_pose_box');
    return box.get('default');
  }

  Future<void> deleteSession(String sessionId) async {
    final box = Hive.box<AnalysisSession>('sessions');
    await box.delete(sessionId);
    print('Session $sessionId deleted.');
  }
}