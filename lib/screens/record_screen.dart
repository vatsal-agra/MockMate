import '../models/session.dart';
import 'dart:io';
import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path_provider/path_provider.dart';
import '../services/storage.dart';
import '../services/video_analyzer.dart';
import '../services/gemini_service.dart';
import 'results_screen.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen>
    with TickerProviderStateMixin {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];

  final _analyzer = VideoAnalyzer();

  bool _recording = false;
  bool _initializing = true;
  int _recordingSeconds = 0;
  Timer? _timer;

  late AnimationController _pulseController;
  late AnimationController _scaleController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _initCamera();
  }

  Future<void> _initCamera() async {
    setState(() => _initializing = true);
    try {
      _cameras = await availableCameras();
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Camera init failed: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _analyzer.dispose();
    _timer?.cancel();
    _pulseController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    print('🎥 Starting recording and analysis...');
    _analyzer.start();
    _recordingSeconds = 0;

    // Start timer
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _recordingSeconds++);
    });

    int streamFrameCount = 0;
    // Start image stream for analysis
    await _controller!.startImageStream((CameraImage image) async {
      if (!_recording) return;

      streamFrameCount++;
      if (streamFrameCount % 30 == 0) {
        print('📸 Camera stream frame #$streamFrameCount (${image.width}x${image.height})');
      }

      final input = _inputImageFromCameraImage(image, _controller!.description);
      if (input != null) {
        await _analyzer.analyzeFrame(input);
      } else {
        if (streamFrameCount % 30 == 0) {
          print('⚠️ Failed to convert camera image to InputImage');
        }
      }
    });

    // Start recording
    await _controller!.startVideoRecording();

    setState(() => _recording = true);
    _scaleController.forward();
    print('✅ Recording started');
  }

  Future<void> _stop() async {
    if (_controller == null) return;

    setState(() => _recording = false);
    _timer?.cancel();
    _scaleController.reverse();

    // Stop recording first
    final file = await _controller!.stopVideoRecording();

    // Stop image stream safely
    try {
      await _controller!.stopImageStream();
    } catch (_) {}

    // Show processing dialog
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          elevation: 24,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(strokeWidth: 6),
                ),
                const SizedBox(height: 24),
                const Text(
                  'AI is analyzing...',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Reviewing your eye contact, expressions,\nand answer quality.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withOpacity(0.6)),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Move to app directory
    final dir = await getApplicationDocumentsDirectory();
    final target = File(
        "${dir.path}/mockmate_${DateTime.now().millisecondsSinceEpoch}.mp4");
    final savedVideo = await File(file.path).copy(target.path);

    try {
      // Use Gemini to analyze the video
      final session = await GeminiService.analyzeVideo(savedVideo, _recordingSeconds);
      
      await StorageService.saveSession(session);

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ResultsScreen(session: session, videoPath: savedVideo.path),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("AI Analysis failed: $e. Using local results as fallback."),
          backgroundColor: Colors.red,
        ),
      );
      
      // Fallback to local analysis if Gemini fails
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
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ResultsScreen(session: session, videoPath: savedVideo.path),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Record Answer',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0A0E21),
              Color(0xFF1D1F33),
            ],
          ),
        ),
        child: _initializing
            ? const Center(child: CircularProgressIndicator())
            : (c == null || !c.value.isInitialized)
                ? _buildErrorState()
                : _buildRecordingUI(c),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.camera_alt_outlined,
            size: 64,
            color: Colors.white54,
          ),
          const SizedBox(height: 16),
          const Text(
            'Camera not available',
            style: TextStyle(fontSize: 18, color: Colors.white),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _initCamera,
            icon: const Icon(Icons.refresh),
            label: const Text("Retry"),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingUI(CameraController c) {
    return Stack(
      children: [
        // Camera Preview
        Positioned.fill(
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(32),
            ),
            child: CameraPreview(c),
          ),
        ),

        // Recording indicator overlay
        if (_recording)
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2 + _pulseController.value * 0.3),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.red.withOpacity(0.5 + _pulseController.value * 0.5),
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _formatDuration(_recordingSeconds),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

        // Bottom controls
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  const Color(0xFF0A0E21).withOpacity(0.9),
                  const Color(0xFF0A0E21),
                ],
              ),
            ),
            padding: const EdgeInsets.all(32),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _recording
                        ? "Speak naturally and maintain eye contact"
                        : "Tap the button to start recording",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Start button
                      ScaleTransition(
                        scale: Tween<double>(begin: 1.0, end: 0.9).animate(
                          CurvedAnimation(
                            parent: _scaleController,
                            curve: Curves.easeOut,
                          ),
                        ),
                        child: _buildControlButton(
                          onPressed: _recording ? null : _start,
                          icon: Icons.fiber_manual_record_rounded,
                          label: 'Start',
                          color: const Color(0xFF6C63FF),
                          enabled: !_recording,
                        ),
                      ),

                      // Stop button
                      ScaleTransition(
                        scale: Tween<double>(begin: 0.9, end: 1.0).animate(
                          CurvedAnimation(
                            parent: _scaleController,
                            curve: Curves.easeOut,
                          ),
                        ),
                        child: _buildControlButton(
                          onPressed: _recording ? _stop : null,
                          icon: Icons.stop_rounded,
                          label: 'Stop',
                          color: const Color(0xFFFF6584),
                          enabled: _recording,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C63FF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF6C63FF).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.tips_and_updates_rounded,
                          color: const Color(0xFF6C63FF),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Aim for 30-90 seconds • Good lighting helps',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    required Color color,
    required bool enabled,
  }) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: enabled
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color, color.withOpacity(0.7)],
                  )
                : null,
            color: enabled ? null : Colors.white.withOpacity(0.1),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              customBorder: const CircleBorder(),
              child: Icon(
                icon,
                color: enabled ? Colors.white : Colors.white.withOpacity(0.3),
                size: 36,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: enabled ? Colors.white : Colors.white.withOpacity(0.3),
          ),
        ),
      ],
    );
  }

  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  // ---- Convert CameraImage -> MLKit InputImage ----
  InputImage? _inputImageFromCameraImage(
    CameraImage image,
    CameraDescription camera,
  ) {
    final bytes = image.planes.first.bytes;

    // Get proper rotation based on device orientation
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
      print('🍎 iOS rotation: $sensorOrientation° -> $rotation');
    } else if (Platform.isAndroid) {
      var rotationCompensation = sensorOrientation;
      
      // For front camera, we need to flip the rotation
      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorOrientation + 90) % 360;
      }
      
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
      print('🤖 Android rotation: sensor=$sensorOrientation°, compensated=$rotationCompensation° -> $rotation');
    }
    
    if (rotation == null) {
      print('❌ Failed to determine rotation!');
      return null;
    }

    final metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: InputImageFormat.yuv420,
      bytesPerRow: image.planes.first.bytesPerRow,
    );

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: metadata,
    );
  }
}
