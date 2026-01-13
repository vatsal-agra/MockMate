import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/session.dart';
import 'home_screen.dart';

class ResultsScreen extends StatefulWidget {
  final MockSession session;
  final String videoPath;

  const ResultsScreen({
    super.key,
    required this.session,
    required this.videoPath,
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen>
    with TickerProviderStateMixin {
  VideoPlayerController? _vp;
  late AnimationController _scoreAnimController;
  late AnimationController _fadeController;
  late Animation<double> _scoreAnimation;

  @override
  void initState() {
    super.initState();
    _vp = VideoPlayerController.file(File(widget.videoPath))
      ..initialize().then((_) => setState(() {}));

    _scoreAnimController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scoreAnimation = Tween<double>(
      begin: 0,
      end: widget.session.totalScore,
    ).animate(CurvedAnimation(
      parent: _scoreAnimController,
      curve: Curves.easeOutCubic,
    ));

    _scoreAnimController.forward();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _vp?.dispose();
    _scoreAnimController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Your Results',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
              (_) => false,
            );
          },
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0A0E21),
              Color(0xFF1D1F33),
              Color(0xFF0A0E21),
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeController,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildScoreCard(s),
                const SizedBox(height: 20),
                _buildVideoCard(),
                const SizedBox(height: 20),
                _buildMetricsCard(s),
                const SizedBox(height: 20),
                _buildTipsCard(s),
                const SizedBox(height: 20),
                _buildActionButtons(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScoreCard(MockSession s) {
    final scoreColor = _getScoreColor(s.totalScore);

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scoreColor.withOpacity(0.2),
            scoreColor.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: scoreColor.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: scoreColor.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Your Score',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.7),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: _scoreAnimation,
            builder: (context, child) {
              return ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [scoreColor, scoreColor.withOpacity(0.7)],
                ).createShader(bounds),
                child: Text(
                  '${_scoreAnimation.value.toInt()}',
                  style: const TextStyle(
                    fontSize: 72,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            _getScoreLabel(s.totalScore),
            style: TextStyle(
              fontSize: 18,
              color: scoreColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoCard() {
    final vp = _vp;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1D1F33),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: AspectRatio(
              aspectRatio: vp != null && vp.value.isInitialized
                  ? vp.value.aspectRatio
                  : 16 / 9,
              child: vp != null && vp.value.isInitialized
                  ? VideoPlayer(vp)
                  : Container(
                      color: Colors.black26,
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: (vp != null && vp.value.isInitialized)
                        ? () => setState(() =>
                            vp.value.isPlaying ? vp.pause() : vp.play())
                        : null,
                    icon: Icon(
                      vp != null && vp.value.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                    label: Text(
                      vp != null && vp.value.isPlaying ? 'Pause' : 'Play',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsCard(MockSession s) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1F33),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Performance Metrics',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          _buildMetricBar(
            'Eye Contact',
            s.eyeContactPct,
            Icons.visibility_rounded,
            const Color(0xFF6C63FF),
          ),
          const SizedBox(height: 16),
          _buildMetricBar(
            'Face Presence',
            s.facePresencePct,
            Icons.face_rounded,
            const Color(0xFF4CAF50),
          ),
          const SizedBox(height: 16),
          _buildMetricBar(
            'Smile',
            s.smilePct,
            Icons.sentiment_satisfied_rounded,
            const Color(0xFFFFA726),
          ),
          const SizedBox(height: 16),
          _buildMetricBar(
            'Head Stability',
            s.headStability,
            Icons.accessibility_new_rounded,
            const Color(0xFF00BCD4),
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.timer_rounded,
                size: 18,
                color: Colors.white.withOpacity(0.6),
              ),
              const SizedBox(width: 8),
              Text(
                'Duration: ${s.durationSeconds}s',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricBar(
    String label,
    double value,
    IconData icon,
    Color color,
  ) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1000),
      tween: Tween(begin: 0.0, end: value / 100),
      curve: Curves.easeOutCubic,
      builder: (context, animValue, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '${value.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 14,
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: animValue,
                backgroundColor: Colors.white.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 8,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTipsCard(MockSession s) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF6C63FF),
            Color(0xFF5A52D5),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.psychology_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Coach Tips',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...s.tips.asMap().entries.map((entry) {
            return TweenAnimationBuilder<double>(
              duration: Duration(milliseconds: 500 + (entry.key * 100)),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(20 * (1 - value), 0),
                  child: Opacity(
                    opacity: value,
                    child: child,
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: Color(0xFF6C63FF),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        entry.value,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const HomeScreen()),
                (_) => false,
              );
            },
            icon: const Icon(Icons.home_rounded),
            label: const Text('Back to Home'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 80) return const Color(0xFF4CAF50);
    if (score >= 60) return const Color(0xFF6C63FF);
    if (score >= 40) return const Color(0xFFFFA726);
    return const Color(0xFFFF6584);
  }

  String _getScoreLabel(double score) {
    if (score >= 80) return 'Excellent! 🎉';
    if (score >= 60) return 'Good Job! 👍';
    if (score >= 40) return 'Keep Practicing 💪';
    return 'Room for Improvement 📈';
  }
}
