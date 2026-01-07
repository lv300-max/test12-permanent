import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/background.dart';
import '../core/state_machine.dart';
import '../core/theme.dart';

class AppDetailScreen extends StatelessWidget {
  final Try12Machine m;
  const AppDetailScreen({super.key, required this.m});

  @override
  Widget build(BuildContext context) {
    if (m.assigned.isEmpty && m.myAppCard == null) {
      return Stack(
        children: [
          const Try12Background(),
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: const Text('APP', style: TextStyle(fontFamily: 'RobotoMono')),
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              scrolledUnderElevation: 0,
              leading: IconButton(
                onPressed: m.backToTerminal,
                icon: const Icon(Icons.arrow_back),
              ),
            ),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: Try12Gradients.panel,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Try12Colors.border.withValues(alpha: 0.75)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 30, offset: const Offset(0, 18)),
                      BoxShadow(color: Try12Colors.highlight.withValues(alpha: 0.05), blurRadius: 26, offset: const Offset(0, 12)),
                    ],
                  ),
                  foregroundDecoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: Try12Gradients.sheen(0.16, intensity: 0.04),
                  ),
                  child: const Text(
                    'No session data yet. Return to Terminal and refresh.',
                    style: TextStyle(fontFamily: 'RobotoMono', fontSize: 11, color: Try12Colors.dim, height: 1.35),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    final app = m.selectedApp;
    final isMine = m.selectedIsMine;
    final inSession = m.inSession;
    final done = isMine ? m.testsComplete : m.isTargetDone(app.id);
    final canRecord = inSession && !isMine && !done;

    return Stack(
      children: [
        const Try12Background(),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('APP', style: TextStyle(fontFamily: 'RobotoMono')),
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            leading: IconButton(
              onPressed: m.backToTerminal,
              icon: const Icon(Icons.arrow_back),
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Try12Colors.panel,
                          app.accent.withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Try12Colors.border.withValues(alpha: 0.75)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 30, offset: const Offset(0, 18)),
                        BoxShadow(color: app.accent.withValues(alpha: 0.06), blurRadius: 26, offset: const Offset(0, 12)),
                      ],
                    ),
                    foregroundDecoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: Try12Gradients.sheen(0.20, intensity: 0.04),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    app.accent.withValues(alpha: 0.95),
                                    app.accent.withValues(alpha: 0.35),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(color: app.accent.withValues(alpha: 0.18), blurRadius: 18),
                                ],
                              ),
                              child: Icon(app.icon, size: 26, color: Try12Colors.bg),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    '${app.id} • ${app.name}',
                                    style: const TextStyle(
                                      fontFamily: 'RobotoMono',
                                      fontSize: 14,
                                      color: Try12Colors.text,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isMine ? 'YOUR APP' : (done ? 'DONE' : 'PENDING'),
                                    style: TextStyle(
                                      fontFamily: 'RobotoMono',
                                      fontSize: 11,
                                      color: done ? Try12Colors.green : Try12Colors.dim,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          app.storeLink.isEmpty ? '(no store link)' : app.storeLink,
                          style: const TextStyle(fontFamily: 'RobotoMono', fontSize: 10, color: Try12Colors.dim, height: 1.35),
                        ),
                        const SizedBox(height: 12),
                        if (isMine)
                          const Text(
                            'You cannot test your own app.\nUnlock turns green when you finish the other 12.',
                            style: TextStyle(fontFamily: 'RobotoMono', fontSize: 10, color: Try12Colors.dim, height: 1.35),
                          )
                        else if (!inSession)
                          const Text(
                            'Session not active yet.\nWait for the buzz, then test the other 12 apps.',
                            style: TextStyle(fontFamily: 'RobotoMono', fontSize: 10, color: Try12Colors.dim, height: 1.35),
                          )
                        else
                          const Text(
                            'Open the store link, install, open, then record completion.',
                            style: TextStyle(fontFamily: 'RobotoMono', fontSize: 10, color: Try12Colors.dim, height: 1.35),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: app.storeLink.isEmpty
                        ? null
                        : () async {
                            final uri = Uri.tryParse(app.storeLink);
                            if (uri == null) return;
                            await launchUrl(uri, mode: LaunchMode.platformDefault);
                          },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: app.accent,
                      side: BorderSide(color: app.accent.withValues(alpha: 0.55)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('OPEN STORE LINK', style: TextStyle(fontFamily: 'RobotoMono')),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: canRecord ? () => m.completeTest(app.id) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Try12Colors.board,
                      foregroundColor: Try12Colors.text,
                      disabledBackgroundColor: Try12Colors.board.withValues(alpha: 0.45),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(done ? 'RECORDED' : 'MARK TEST COMPLETE', style: const TextStyle(fontFamily: 'RobotoMono')),
                  ),
                  const SizedBox(height: 10),
                  if (m.loading) const LinearProgressIndicator(minHeight: 2),
                  if (m.lastError != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      m.lastError!,
                      style: const TextStyle(fontFamily: 'RobotoMono', fontSize: 11, color: Try12Colors.red, height: 1.35),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
