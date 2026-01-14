import 'package:flutter/material.dart';

class TipsScreen extends StatelessWidget {
  const TipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final categories = [
      {
        'title': 'Body Language',
        'icon': Icons.accessibility_new_rounded,
        'color': const Color(0xFF6C63FF),
        'tips': [
          'Maintain natural eye contact with the camera, not the screen.',
          'Sit up straight to project confidence and energy.',
          'Use hand gestures naturally to emphasize key points.',
          'Keep your facial expressions friendly and engaged.',
        ],
      },
      {
        'title': 'The STAR Method',
        'icon': Icons.star_rounded,
        'color': const Color(0xFFFF6584),
        'tips': [
          'Situation: Set the scene and provide necessary context.',
          'Task: Describe what your responsibility was in that situation.',
          'Action: Explain exactly what steps you took to address it.',
          'Result: Share the outcome and what you learned or achieved.',
        ],
      },
      {
        'title': 'Common Questions',
        'icon': Icons.question_answer_rounded,
        'color': const Color(0xFF4CAF50),
        'tips': [
          'Tell me about yourself: Keep it professional and relevant to the role.',
          'What is your greatest weakness? Show self-awareness and improvement.',
          'Why should we hire you? Focus on the unique value you bring.',
          'Where do you see yourself in 5 years? Show ambition and alignment.',
        ],
      },
      {
        'title': 'Closing Strong',
        'icon': Icons.door_front_door_rounded,
        'color': const Color(0xFFFFA726),
        'tips': [
          'Prepare 2-3 thoughtful questions for the interviewer.',
          'Summarize your interest in the role and the company.',
          'Thank the interviewer for their time and the opportunity.',
          'Ask about the next steps in the hiring process.',
        ],
      },
    ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Mastery Library',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                _buildHeroTip(),
                const SizedBox(height: 40),
                ...List.generate(categories.length, (index) {
                  final cat = categories[index];
                  return _buildCategorySection(cat, index);
                }),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroTip() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFFFF6584)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'Tip of the Day',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Text(
            'The first 30 seconds set the tone. Start with a clear, confident smile and a concise introduction.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(Map<String, dynamic> cat, int index) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Row(
            children: [
              Text(
                cat['title'] as String,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Divider(
                  color: (cat['color'] as Color).withOpacity(0.3),
                  thickness: 1,
                ),
              ),
            ],
          ),
        ),
        ... (cat['tips'] as List<String>).asMap().entries.map((entry) {
          return _buildTipItem(entry.value, cat['color'] as Color, entry.key, index);
        }),
      ],
    );
  }

  Widget _buildTipItem(String tip, Color color, int tipIndex, int catIndex) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 400 + (catIndex * 100) + (tipIndex * 50)),
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
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1D1F33),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.check_circle_outline_rounded, color: color, size: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                tip,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white.withOpacity(0.9),
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
