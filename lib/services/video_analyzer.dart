import 'dart:math';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class AnalysisResult {
  final int durationSeconds;

  final double facePresencePct;
  final double eyeContactPct;
  final double smilePct;
  final double headStability; // 0..100
  final double totalScore; // 0..100
  final List<String> tips;

  AnalysisResult({
    required this.durationSeconds,
    required this.facePresencePct,
    required this.eyeContactPct,
    required this.smilePct,
    required this.headStability,
    required this.totalScore,
    required this.tips,
  });
}

class VideoAnalyzer {
  final _detector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      enableClassification: true, // smile/eyes probability
      enableTracking: true,
      enableLandmarks: false,
      enableContours: false,
    ),
  );

  bool _busy = false;

  int frames = 0;
  int faceFrames = 0;
  int eyeContactFrames = 0;

  double smileSum = 0;
  int smileCount = 0;

  final List<double> yawSamples = [];
  final List<double> rollSamples = [];

  DateTime? _start;

  void start() {
    reset();
    _start = DateTime.now();
  }

  void reset() {
    frames = 0;
    faceFrames = 0;
    eyeContactFrames = 0;
    smileSum = 0;
    smileCount = 0;
    yawSamples.clear();
    rollSamples.clear();
    _start = null;
  }

  Future<void> dispose() async {
    await _detector.close();
  }

  // Call this repeatedly with MLKit InputImage frames
  Future<void> analyzeFrame(InputImage image) async {
    if (_busy) return;
    _busy = true;

    try {
      frames++;
      final faces = await _detector.processImage(image);

      if (faces.isNotEmpty) {
        faceFrames++;

        // We only look at the most prominent face for MVP
        final f = faces.first;

        final yaw = (f.headEulerAngleY ?? 0).toDouble();
        final roll = (f.headEulerAngleZ ?? 0).toDouble();
        yawSamples.add(yaw);
        rollSamples.add(roll);

        final leftOpen = f.leftEyeOpenProbability;
        final rightOpen = f.rightEyeOpenProbability;
        final smile = f.smilingProbability;

        // Smile metric
        if (smile != null) {
          smileSum += smile.clamp(0, 1);
          smileCount++;
        }

        // Eye contact proxy:
        // - face present
        // - both eyes somewhat open
        // - head yaw/roll not too extreme (means looking mostly at camera)
        final eyesOk = (leftOpen ?? 0.0) > 0.45 && (rightOpen ?? 0.0) > 0.45;
        final headOk = yaw.abs() < 12 && roll.abs() < 12;

        if (eyesOk && headOk) {
          eyeContactFrames++;
        }
      }
    } finally {
      _busy = false;
    }
  }

  AnalysisResult finalizeResult() {
    final durationSeconds = _start == null
        ? 0
        : max(1, DateTime.now().difference(_start!).inSeconds);

    double pct(int part, int total) => total == 0 ? 0 : (part / total) * 100;

    final facePresence = pct(faceFrames, frames);
    final eyeContact = pct(eyeContactFrames, frames);
    final smilePct = smileCount == 0 ? 0 : (smileSum / smileCount) * 100;

    // Head stability: lower std dev = better
    double std(List<double> xs) {
      if (xs.length < 2) return 0;
      final mean = xs.reduce((a, b) => a + b) / xs.length;
      final v = xs.map((x) => (x - mean) * (x - mean)).reduce((a, b) => a + b) /
          (xs.length - 1);
      return sqrt(v);
    }

    final yawStd = std(yawSamples);
    final rollStd = std(rollSamples);

    // Map std degrees to 0..100
    // 0-3 deg = very stable, 10+ deg = unstable
    double stabilityFromStd(double s) {
      final val = 100 - ((s / 10.0) * 100);
      return val.clamp(0, 100);
    }

    final stability =
        ((stabilityFromStd(yawStd) + stabilityFromStd(rollStd)) / 2);

    // Scoring (weights can be tuned)
    // Emphasis: eye contact + presence + stability; smile as bonus
    final totalScore = (0.35 * eyeContact +
            0.30 * facePresence +
            0.25 * stability +
            0.10 * smilePct)
        .clamp(0, 100);

    final tips = <String>[];

    if (facePresence < 75) {
      tips.add(
          "You were out of frame often. Keep your face centered and camera at eye level.");
    }
    if (eyeContact < 55) {
      tips.add(
          "Eye contact was low. Try looking at the camera lens, not the screen.");
    } else if (eyeContact > 80) {
      tips.add("Great eye contact. Keep this consistency across your answer.");
    }

    if (stability < 60) {
      tips.add(
          "Head movement was high. Sit upright and reduce frequent nodding or shifting.");
    }

    if (smilePct < 15) {
      tips.add(
          "Your expression was quite neutral. A light, natural smile improves friendliness.");
    }

    // Always add 1 structure tip (even without transcript)
    tips.add(
        "End with a 1-line conclusion summarizing your key point for a stronger finish.");

    return AnalysisResult(
      durationSeconds: durationSeconds,
      facePresencePct: facePresence,
      eyeContactPct: eyeContact,
      smilePct: smilePct.toDouble(),
      headStability: stability,
      totalScore: totalScore.toDouble(),
      tips: tips.take(5).toList(),
    );
  }
}
