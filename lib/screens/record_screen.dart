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
  final String? role;
  final String? jd;
  final List<String>? cvQuestions;

  const RecordScreen({super.key, this.role, this.jd, this.cvQuestions});

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
  
  String? _question;
  bool _loadingQuestion = false;
  int _currentQuestionIndex = 0; // Track which CV question is selected

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

    _generateQuestion();
    _initCamera();
  }

  Future<void> _generateQuestion() async {
    // Priority 1: Use CV questions if available
    if (widget.cvQuestions != null && widget.cvQuestions!.isNotEmpty) {
      setState(() {
        _question = widget.cvQuestions![_currentQuestionIndex];
        _loadingQuestion = false;
      });
      return;
    }
    
    // Priority 2: Generate from role/JD
    if (widget.role == null && widget.jd == null) return;
    
    setState(() => _loadingQuestion = true);
    final q = await GeminiService.generateQuestion(
      role: widget.role,
      jobDescription: widget.jd,
    );
    if (!mounted) return;
    setState(() {
      _question = q;
      _loadingQuestion = false;
    });
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

  void _previousQuestion() {
    if (widget.cvQuestions == null || widget.cvQuestions!.isEmpty) return;
    if (_recording) return; // Don't allow changing question while recording
    
    setState(() {
      if (_currentQuestionIndex > 0) {
        _currentQuestionIndex--;
      } else {
        _currentQuestionIndex = widget.cvQuestions!.length - 1; // Wrap to last
      }
      _question = widget.cvQuestions![_currentQuestionIndex];
    });
  }

  void _nextQuestion() {
    if (widget.cvQuestions == null || widget.cvQuestions!.isEmpty) return;
    if (_recording) return; // Don't allow changing question while recording
    
    setState(() {
      if (_currentQuestionIndex < widget.cvQuestions!.length - 1) {
        _currentQuestionIndex++;
      } else {
        _currentQuestionIndex = 0; // Wrap to first
      }
      _question = widget.cvQuestions![_currentQuestionIndex];
    });
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
      final session = await GeminiService.analyzeVideo(
        savedVideo, 
        _recordingSeconds,
        questionAsked: _question,
      );
      
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
        questionAsked: _question,
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
          color: Color(0xFF010101),
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

        // AI Question Overlay
        if (_question != null || _loadingQuestion)
          Positioned(
            top: 110,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.help_outline, color: Color(0xFF6C63FF), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'AI INTERVIEW QUESTION',
                          style: TextStyle(
                            color: const Color(0xFF6C63FF).withAlpha(150),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      // Show question counter if multiple CV questions
                      if (widget.cvQuestions != null && widget.cvQuestions!.length > 1)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6C63FF).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_currentQuestionIndex + 1}/${widget.cvQuestions!.length}',
                            style: const TextStyle(
                              color: Color(0xFF6C63FF),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_loadingQuestion)
                    const Center(child: LinearProgressIndicator(minHeight: 2))
                  else
                    Row(
                      children: [
                        // Left arrow for previous question
                        if (widget.cvQuestions != null && widget.cvQuestions!.length > 1 && !_recording)
                          IconButton(
                            onPressed: _previousQuestion,
                            icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
                            color: const Color(0xFF6C63FF),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        if (widget.cvQuestions != null && widget.cvQuestions!.length > 1 && !_recording)
                          const SizedBox(width: 8),
                        // Question text
                        Expanded(
                          child: Container(
                            constraints: const BoxConstraints(maxHeight: 120),
                            child: SingleChildScrollView(
                              child: Text(
                                _question!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Right arrow for next question
                        if (widget.cvQuestions != null && widget.cvQuestions!.length > 1 && !_recording)
                          const SizedBox(width: 8),
                        if (widget.cvQuestions != null && widget.cvQuestions!.length > 1 && !_recording)
                          IconButton(
                            onPressed: _nextQuestion,
                            icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
                            color: const Color(0xFF6C63FF),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),

        // Recording indicator overlay
        if (_recording)
          Positioned(
            top: 300,
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
                  const Color(0xFF010101).withOpacity(0.9),
                  const Color(0xFF010101),
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
                  const SizedBox(height: 32),
                  
                  // Modern Shutter Button
                  GestureDetector(
                    onTap: _recording ? _stop : _start,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 4,
                        ),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        decoration: BoxDecoration(
                          color: _recording ? const Color(0xFFFF6584) : const Color(0xFF6C63FF),
                          borderRadius: BorderRadius.circular(_recording ? 8 : 40),
                        ),
                        child: Center(
                          child: Icon(
                            _recording ? Icons.stop_rounded : Icons.videocam_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
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
