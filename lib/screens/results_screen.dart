import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/session.dart';
import 'home_screen.dart';

class ResultsScreen extends StatefulWidget {
  final MockSession session;
  final String videoPath;

  const ResultsScreen(
      {super.key, required this.session, required this.videoPath});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  VideoPlayerController? _vp;

  @override
  void initState() {
    super.initState();
    _vp = VideoPlayerController.file(File(widget.videoPath))
      ..initialize().then((_) => setState(() {}));
  }

  @override
  void dispose() {
    _vp?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;

    return Scaffold(
      appBar: AppBar(title: const Text("Results")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _videoCard(),
          const SizedBox(height: 14),
          Text("Score: ${s.totalScore.toStringAsFixed(0)}/100",
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          _metricRow(
              "Face presence", "${s.facePresencePct.toStringAsFixed(0)}%"),
          _metricRow(
              "Eye contact (proxy)", "${s.eyeContactPct.toStringAsFixed(0)}%"),
          _metricRow("Smile", "${s.smilePct.toStringAsFixed(0)}%"),
          _metricRow(
              "Head stability", "${s.headStability.toStringAsFixed(0)}/100"),
          _metricRow("Duration", "${s.durationSeconds}s"),
          const SizedBox(height: 16),
          const Text("Coach Tips",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ...s.tips.map((t) => _tip(t)),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const HomeScreen()),
                (_) => false,
              );
            },
            child: const Text("Done"),
          ),
        ],
      ),
    );
  }

  Widget _videoCard() {
    final vp = _vp;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12),
        color: Colors.black.withOpacity(0.03),
      ),
      child: Column(
        children: [
          if (vp != null && vp.value.isInitialized)
            AspectRatio(
                aspectRatio: vp.value.aspectRatio, child: VideoPlayer(vp))
          else
            Container(
                height: 200,
                alignment: Alignment.center,
                child: const CircularProgressIndicator()),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (vp != null && vp.value.isInitialized)
                      ? () => setState(
                          () => vp.value.isPlaying ? vp.pause() : vp.play())
                      : null,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text("Play/Pause"),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _metricRow(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
              child: Text(k, style: const TextStyle(color: Colors.black54))),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _tip(String t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.indigo.withOpacity(0.06),
        border: Border.all(color: Colors.indigo.withOpacity(0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(t)),
        ],
      ),
    );
  }
}
