import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/state_machine.dart';
import '../core/theme.dart';
import 'mock_app.dart';

class AssignmentMapScreen extends StatelessWidget {
  final Try12Machine m;
  const AssignmentMapScreen({super.key, required this.m});

  @override
  Widget build(BuildContext context) {
    final mine = m.myApp;
    final assignedIds = m.assignmentMapAppIds;
    final myId = mine?.appId;
    final otherAssigned = assignedIds.where((id) => id != myId).toList();
    while (otherAssigned.length < 12) {
      otherAssigned.add('__OPEN__');
    }
    if (otherAssigned.length > 12) {
      otherAssigned.removeRange(12, otherAssigned.length);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('ASSIGNMENT MAP', style: TextStyle(fontFamily: 'RobotoMono')),
        backgroundColor: Try12Colors.bg,
        leading: IconButton(
          onPressed: m.goToQueue,
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
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
              const Text(
                'Exactly 13 icons in one horizontal row.',
                style: TextStyle(fontFamily: 'RobotoMono', fontSize: 10, color: Try12Colors.dim),
              ),
              const SizedBox(height: 6),
              Text(
                assignedIds.isEmpty ? 'No active session — showing open positions.' : 'Active session — 12 assigned apps.',
                style: const TextStyle(fontFamily: 'RobotoMono', fontSize: 10, color: Try12Colors.dim),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final iconSize = (width / 13).clamp(10.0, 44.0);
                  final labelSize = (iconSize / 3.2).clamp(7.0, 11.0);

                  final cells = <_AppCell>[
                    _AppCell(
                      label: mine == null ? '—' : _shortLabel(mine.appName, mine.appId),
                      url: mine?.storeLink,
                      appId: mine?.appId,
                      color: Try12Colors.highlight.withValues(alpha: 0.9),
                      textColor: Try12Colors.bg,
                    ),
                    ...otherAssigned.map((appId) {
                      if (appId == '__OPEN__') {
                        return const _AppCell(
                          label: 'OPEN',
                          url: null,
                          appId: null,
                          color: Try12Colors.board,
                          textColor: Try12Colors.dim,
                          borderColor: Try12Colors.border,
                        );
                      }
                      final app = m.appsById[appId];
                      final downloaded = app != null && m.isDownloaded(appId);
                      return _AppCell(
                        label: app == null ? appId : _shortLabel(app.appName, appId),
                        url: app?.storeLink,
                        appId: appId,
                        color: downloaded ? Try12Colors.accent.withValues(alpha: 0.18) : Try12Colors.panel,
                        textColor: downloaded ? Try12Colors.accent : Try12Colors.text,
                        borderColor: downloaded ? Try12Colors.accent.withValues(alpha: 0.55) : Try12Colors.border,
                      );
                    }),
                  ];

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (final cell in cells)
                        _IconTile(
                          size: iconSize,
                          labelSize: labelSize,
                          m: m,
                          cell: cell,
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              _MetaBox(m: m),
            ],
          ),
        ),
      ),
    );
  }

  static String _shortLabel(String name, String fallback) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return fallback;
    final up = trimmed.toUpperCase();
    return up.length <= 6 ? up : up.substring(0, 6);
  }
}

class _MetaBox extends StatelessWidget {
  final Try12Machine m;
  const _MetaBox({required this.m});

  @override
  Widget build(BuildContext context) {
    final session = m.session;
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
          const Text(
            'SESSION',
            style: TextStyle(
              fontFamily: 'RobotoMono',
              fontSize: 10,
              letterSpacing: 0.8,
              color: Try12Colors.highlight,
            ),
          ),
          const SizedBox(height: 8),
          if (session == null)
            const Text(
              '—',
              style: TextStyle(fontFamily: 'RobotoMono', fontSize: 10, color: Try12Colors.dim),
            )
          else ...[
            Text(
              session.sessionId,
              style: const TextStyle(fontFamily: 'RobotoMono', fontSize: 11, color: Try12Colors.text),
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
          ],
        ],
      ),
    );
  }
}

class _AppCell {
  final String label;
  final String? url;
  final String? appId;
  final Color color;
  final Color textColor;
  final Color? borderColor;

  const _AppCell({
    required this.label,
    required this.url,
    required this.appId,
    required this.color,
    required this.textColor,
    this.borderColor,
  });
}

class _IconTile extends StatelessWidget {
  final double size;
  final double labelSize;
  final Try12Machine m;
  final _AppCell cell;

  const _IconTile({
    required this.size,
    required this.labelSize,
    required this.m,
    required this.cell,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: cell.url == null ? null : () => _open(context, cell.url!),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: cell.color,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cell.borderColor ?? Colors.transparent),
        ),
        child: Text(
          cell.label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'RobotoMono',
            fontSize: labelSize,
            color: cell.textColor,
            fontWeight: FontWeight.w700,
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
