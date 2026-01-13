import 'package:shared_preferences/shared_preferences.dart';
import '../models/session.dart';

class StorageService {
  static const _key = 'mock_sessions';

  static Future<List<MockSession>> loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    return list.map((s) => MockSession.fromJson(s)).toList();
  }

  static Future<void> saveSession(MockSession session) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    list.add(session.toJson());
    await prefs.setStringList(_key, list);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
