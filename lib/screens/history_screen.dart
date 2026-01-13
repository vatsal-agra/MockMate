import '../models/session.dart';
import 'package:flutter/material.dart';
import '../services/storage.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<MockSession> sessions = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await StorageService.loadSessions();
    if (!mounted) return;
    setState(() {
      sessions = s;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("History"),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              await StorageService.clearAll();
              await _load();
            },
            tooltip: "Clear all",
          )
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : sessions.isEmpty
              ? const Center(
                  child: Text("No sessions yet. Record your first answer!"))
              : ListView.separated(
                  itemCount: sessions.length,
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemBuilder: (context, i) {
                    final s = sessions[i];
                    return ListTile(
                      title:
                          Text("Score ${s.totalScore.toStringAsFixed(0)}/100"),
                      subtitle: Text(
                        "${s.createdAt.toLocal()} • Eye ${s.eyeContactPct.toStringAsFixed(0)}% • Presence ${s.facePresencePct.toStringAsFixed(0)}%",
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        // MVP: just show tips in a dialog
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: Text(
                                "Session ${s.totalScore.toStringAsFixed(0)}/100"),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: s.tips
                                  .map((t) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 6),
                                        child: Text("• $t"),
                                      ))
                                  .toList(),
                            ),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text("Close")),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}
