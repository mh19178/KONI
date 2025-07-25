import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

class CameraService extends ChangeNotifier {
  CameraController? _controller;
  CameraController? get controller => _controller;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  CameraDescription? _cameraDescription;
  CameraDescription? get cameraDescription => _cameraDescription;

  Future<void> initialize() async {
    if (_isInitialized) return;

    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      print('No cameras available');
      return;
    }
    _cameraDescription = cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      _cameraDescription!,
      ResolutionPreset.high,
      enableAudio: false,
    );

    await _controller!.initialize();
    _isInitialized = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _isInitialized = false;
    super.dispose();
  }
}