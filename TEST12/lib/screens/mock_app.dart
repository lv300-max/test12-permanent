import 'package:flutter/material.dart';

import '../core/state_machine.dart';
import '../core/theme.dart';

class MockAppScreen extends StatelessWidget {
  final Try12Machine m;
  final String appId;

  const MockAppScreen({super.key, required this.m, required this.appId});

  static String? tryParseMockAppId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    if (uri.scheme != 'try12') return null;
    if (uri.host != 'mock') return null;
    final id = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    return id.isEmpty ? null : id;
  }

  @override
  Widget build(BuildContext context) {
    final meta = m.appsById[appId];
    final name = meta?.appName ?? appId;
    final downloaded = m.isDownloaded(appId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('MOCK APP', style: TextStyle(fontFamily: 'RobotoMono')),
        backgroundColor: Try12Colors.bg,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
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
                      name,
                      style: const TextStyle(
                        fontFamily: 'RobotoMono',
                        fontSize: 14,
                        color: Try12Colors.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This is a placeholder app used to simulate the Test 12 session.',
                      style: TextStyle(fontFamily: 'RobotoMono', fontSize: 11, color: Try12Colors.dim, height: 1.4),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      downloaded ? 'STATUS: DOWNLOADED' : 'STATUS: NOT DOWNLOADED',
                      style: TextStyle(
                        fontFamily: 'RobotoMono',
                        fontSize: 11,
                        color: downloaded ? Try12Colors.green : Try12Colors.dim,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () async {
                  await m.setDownloaded(appId, !downloaded);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Try12Colors.panel,
                  foregroundColor: Try12Colors.text,
                ),
                child: Text(
                  downloaded ? 'MARK NOT DOWNLOADED' : 'MARK DOWNLOADED',
                  style: const TextStyle(fontFamily: 'RobotoMono'),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
