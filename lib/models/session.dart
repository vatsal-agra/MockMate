import 'dart:convert';

class MockSession {
  final String id;
  final DateTime createdAt;
  final int durationSeconds;

  final double facePresencePct;
  final double eyeContactPct;
  final double smilePct;
  final double headStability;
  final double totalScore;

  final List<String> tips;

  MockSession({
    required this.id,
    required this.createdAt,
    required this.durationSeconds,
    required this.facePresencePct,
    required this.eyeContactPct,
    required this.smilePct,
    required this.headStability,
    required this.totalScore,
    required this.tips,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'durationSeconds': durationSeconds,
        'facePresencePct': facePresencePct,
        'eyeContactPct': eyeContactPct,
        'smilePct': smilePct,
        'headStability': headStability,
        'totalScore': totalScore,
        'tips': tips,
      };

  factory MockSession.fromMap(Map<String, dynamic> m) => MockSession(
        id: m['id'],
        createdAt: DateTime.parse(m['createdAt']),
        durationSeconds: m['durationSeconds'],
        facePresencePct: (m['facePresencePct'] as num).toDouble(),
        eyeContactPct: (m['eyeContactPct'] as num).toDouble(),
        smilePct: (m['smilePct'] as num).toDouble(),
        headStability: (m['headStability'] as num).toDouble(),
        totalScore: (m['totalScore'] as num).toDouble(),
        tips: List<String>.from(m['tips']),
      );
  String toJson() {
    return jsonEncode(toMap());
  }

  factory MockSession.fromJson(String source) {
    final map = jsonDecode(source) as Map<String, dynamic>;
    return MockSession.fromMap(map);
  }
}
