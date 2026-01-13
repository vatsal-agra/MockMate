import '../models/session.dart';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path_provider/path_provider.dart';
import '../services/storage.dart';
import '../services/video_analyzer.dart';
import 'results_screen.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];

  final _analyzer = VideoAnalyzer();

  bool _recording = false;
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    setState(() => _initializing = true);
    try {
      _cameras = await availableCameras();
      // Prefer front camera
      final front = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras.first,
      );

      _controller = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: true,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _controller!.initialize();
      await _controller!.setFlashMode(FlashMode.off);

      setState(() => _initializing = false);
    } catch (e) {
      setState(() => _initializing = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Camera init failed: $e")));
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _analyzer.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    _analyzer.start();

    // Start image stream for analysis
    await _controller!.startImageStream((CameraImage image) async {
      if (!_recording) return;

      final input = _inputImageFromCameraImage(image, _controller!.description);
      if (input != null) {
        await _analyzer.analyzeFrame(input);
      }
    });

    // Start recording
    await _controller!.startVideoRecording();

    setState(() => _recording = true);
  }

  Future<void> _stop() async {
    if (_controller == null) return;

    setState(() => _recording = false);

    // Stop recording first
    final file = await _controller!.stopVideoRecording();

    // Stop image stream safely
    try {
      await _controller!.stopImageStream();
    } catch (_) {}

    // Move to app directory (optional)
    final dir = await getApplicationDocumentsDirectory();
    final target = File(
        "${dir.path}/mockmate_${DateTime.now().millisecondsSinceEpoch}.mp4");
    final savedVideo = await File(file.path).copy(target.path);

    final r = _analyzer.finalizeResult();

    final session = MockSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      createdAt: DateTime.now(),
      durationSeconds: r.durationSeconds,
      facePresencePct: r.facePresencePct,
      eyeContactPct: r.eyeContactPct,
      smilePct: r.smilePct,
      headStability: r.headStability,
      totalScore: r.totalScore,
      tips: r.tips,
    );

    await StorageService.saveSession(session);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ResultsScreen(session: session, videoPath: savedVideo.path),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;

    return Scaffold(
      appBar: AppBar(title: const Text("Record Answer")),
      body: _initializing
          ? const Center(child: CircularProgressIndicator())
          : (c == null || !c.value.isInitialized)
              ? Center(
                  child: FilledButton(
                    onPressed: _initCamera,
                    child: const Text("Retry Camera"),
                  ),
                )
              : Column(
                  children: [
                    AspectRatio(
                      aspectRatio: c.value.aspectRatio,
                      child: CameraPreview(c),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            _recording
                                ? "Recording… Speak naturally (30–90s)"
                                : "Tap start and answer a question",
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _recording ? null : _start,
                                  icon: const Icon(Icons.fiber_manual_record),
                                  label: const Text("Start"),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _recording ? _stop : null,
                                  icon: const Icon(Icons.stop),
                                  label: const Text("Stop"),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            "Best results: good lighting + camera at eye level + face centered.",
                            style: TextStyle(color: Colors.black54),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  ],
                ),
    );
  }

  // ---- Convert CameraImage -> MLKit InputImage ----
  InputImage _inputImageFromCameraImage(
    CameraImage image,
    CameraDescription camera,
  ) {
    final bytes = image.planes.first.bytes;

    final metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: InputImageRotation.rotation0deg,
      format: InputImageFormat.yuv420,
      bytesPerRow: image.planes.first.bytesPerRow,
    );

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: metadata,
    );
  }

  InputImageRotation _rotationIntToImageRotation(int rotation) {
    switch (rotation) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      case 0:
      default:
        return InputImageRotation.rotation0deg;
    }
  }
}
