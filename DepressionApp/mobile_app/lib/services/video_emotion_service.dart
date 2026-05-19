import 'package:camera/camera.dart';
import 'dart:async';
import 'dart:io';

class VideoEmotionService {

  static CameraController? _controller;

  static Timer? _timer;

  static List<File> frames = [];

  static bool initialized = false;

  static Future<void> init(CameraDescription camera) async {

    if (initialized) return;

    _controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _controller!.initialize();

    initialized = true;
  }

  static CameraController? get controller => _controller;

  static Future<void> startContinuous() async {

  frames.clear();

  _timer?.cancel();

  // =========================================
  // CAPTURE FIRST FRAME IMMEDIATELY
  // =========================================

  try {

    if (_controller != null &&
        _controller!.value.isInitialized &&
        !_controller!.value.isTakingPicture) {

      final image =
          await _controller!.takePicture();

      frames.clear();

      frames.add(File(image.path));

      print("Initial frame captured");
    }

  } catch (e) {

    print("Initial frame error: $e");
  }

  // =========================================
  // CONTINUOUS CAPTURE EVERY 30 SEC
  // =========================================

  _timer = Timer.periodic(

    Duration(seconds: 30),

    (timer) async {

      if (_controller == null) return;

      if (!_controller!.value.isInitialized) {
        return;
      }

      if (_controller!.value.isTakingPicture) {
        return;
      }

      try {

        final image =
            await _controller!.takePicture();

        frames.clear();

        frames.add(File(image.path));

        print("Frame captured");

      } catch (e) {

        print("Frame capture error: $e");
      }
    },
  );
}

  static void stop() {

    _timer?.cancel();

  }

  static Future<void> dispose() async {

    _timer?.cancel();

    if (_controller != null) {
      await _controller!.dispose();
    }

    initialized = false;

    _controller = null;
  }
}