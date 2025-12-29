import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/state_machine.dart';
import '../core/theme.dart';
import 'mock_app.dart';

class QueueViewScreen extends StatelessWidget {
  final Try12Machine m;
  const QueueViewScreen({super.key, required this.m});

  @override
  Widget build(BuildContext context) {
    final mine = m.myApp;
    final position = m.myQueuePosition;
    final hasSession = m.hasActiveSession;
    final session = m.session;

    return Scaffold(
      appBar: AppBar(
        title: const Text('QUEUE', style: TextStyle(fontFamily: 'RobotoMono')),
        backgroundColor: Try12Colors.bg,
        actions: [
          IconButton(
            onPressed: () => m.refresh(),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          TextButton(
            onPressed: m.goToAdmin,
            child: const Text('ADMIN', style: TextStyle(fontFamily: 'RobotoMono')),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Card(
                title: 'YOUR APP',
                child: mine == null
                    ? const Text(
                        'No submission.',
                        style: TextStyle(fontFamily: 'RobotoMono', color: Try12Colors.dim),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            mine.appName,
                            style: const TextStyle(
                              fontFamily: 'RobotoMono',
                              fontSize: 13,
                              color: Try12Colors.text,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            mine.storeLink,
                            style: const TextStyle(
                              fontFamily: 'RobotoMono',
                              fontSize: 10,
                              color: Try12Colors.dim,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              if (position != null)
                                Text(
                                  'POSITION: $position',
                                  style: const TextStyle(
                                    fontFamily: 'RobotoMono',
                                    fontSize: 11,
                                    color: Try12Colors.highlight,
                                  ),
                                )
                              else
                                const Text(
                                  'POSITION: —',
                                  style: TextStyle(
                                    fontFamily: 'RobotoMono',
                                    fontSize: 11,
                                    color: Try12Colors.dim,
                                  ),
                                ),
                              const Spacer(),
                              TextButton(
                                onPressed: () => _open(context, mine.storeLink),
                                child: const Text(
                                  'OPEN LINK',
                                  style: TextStyle(fontFamily: 'RobotoMono'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 12),
              _Card(
                title: 'SESSION',
                child: !hasSession || session == null
                    ? const Text(
                        'No active session. Waiting for 12 verified apps in the queue.',
                        style: TextStyle(fontFamily: 'RobotoMono', color: Try12Colors.dim, height: 1.4),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'ACTIVE • ${session.sessionId}',
                            style: const TextStyle(
                              fontFamily: 'RobotoMono',
                              fontSize: 11,
                              color: Try12Colors.accent,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'START: ${session.startTime.toIso8601String()}',
                            style: const TextStyle(fontFamily: 'RobotoMono', fontSize: 10, color: Try12Colors.dim),
                          ),
                          Text(
                            'END:   ${session.endTime.toIso8601String()}',
                            style: const TextStyle(fontFamily: 'RobotoMono', fontSize: 10, color: Try12Colors.dim),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: m.goToAssignmentMap,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Try12Colors.panel,
                              foregroundColor: Try12Colors.text,
                            ),
                            child: const Text('VIEW ASSIGNMENT MAP', style: TextStyle(fontFamily: 'RobotoMono')),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 12),
              const _Card(
                title: 'NOTES',
                child: Text(
                  'Testing is encouraged but never enforced.\n'
                  'No tracking of installs or reviews.\n'
                  'Presence is sufficient.',
                  style: TextStyle(fontFamily: 'RobotoMono', fontSize: 10, color: Try12Colors.dim, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, String url) async {
    final id = MockAppScreen.tryParseMockAppId(url);
    if (id != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => MockAppScreen(m: m, appId: id)),
      );
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;

  const _Card({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Try12Colors.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Try12Colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'RobotoMono',
              fontSize: 10,
              letterSpacing: 0.8,
              color: Try12Colors.highlight,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
