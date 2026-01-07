import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/background.dart';
import '../core/state_machine.dart';
import '../core/theme.dart';

class CerebrumScreen extends StatefulWidget {
  final Try12Machine m;
  const CerebrumScreen({super.key, required this.m});

  @override
  State<CerebrumScreen> createState() => _CerebrumScreenState();
}

class _CerebrumScreenState extends State<CerebrumScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.m.refresh(silent: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.m;
    final session = m.session;
    final appIds = session?['app_ids'] is List ? (session?['app_ids'] as List).whereType<String>().toList() : const <String>[];
    final end = session?['end_time'];
    final start = session?['start_time'];
    final nowMs = m.nowMsFromServer;
    final remaining = (nowMs != null && end is num) ? (end.toInt() - nowMs) : null;
    final remainingText = remaining == null
        ? '—'
        : remaining <= 0
            ? 'COMPLETE'
            : _fmtDurationMs(remaining);

    final apps = appIds
        .map((id) => _CerebrumApp.from(
              id: id,
              appMeta: m.appsById[id] is Map ? (m.appsById[id] as Map).cast<String, dynamic>() : const <String, dynamic>{},
              isMine: m.myAppId == id,
              done: m.isTargetDone(id) || (m.myAppId == id && m.testsComplete),
            ))
        .toList();

    return Stack(
      children: [
        const Try12Background(),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('CEREBRUM', style: TextStyle(fontFamily: 'RobotoMono')),
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            leading: IconButton(
              onPressed: m.backToTerminal,
              icon: const Icon(Icons.arrow_back),
            ),
            actions: [
              IconButton(
                tooltip: 'Refresh',
                onPressed: () => m.refresh(),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: appIds.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: Try12Gradients.panel,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Try12Colors.border),
                      ),
                      child: const Text(
                        'No session data to map. Join a session or refresh.',
                        style: TextStyle(fontFamily: 'RobotoMono', fontSize: 11, color: Try12Colors.dim, height: 1.35),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: Try12Gradients.panel,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Try12Colors.border.withValues(alpha: 0.75)),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 30, offset: const Offset(0, 18)),
                              BoxShadow(color: Try12Colors.accent.withValues(alpha: 0.05), blurRadius: 24, offset: const Offset(0, 12)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'POINT ROOM • 14-DAY WINDOW',
                                style: TextStyle(fontFamily: 'RobotoMono', fontSize: 11, color: Try12Colors.text, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Apps in your current session. Active ones glow. Tap to open on-device.',
                                style: TextStyle(fontFamily: 'RobotoMono', fontSize: 10, color: Try12Colors.dim, height: 1.35),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 10,
                                runSpacing: 8,
                                children: [
                                  _Chip(label: 'APPS', value: '${apps.length}'),
                                  _Chip(label: 'REMAINING', value: remainingText),
                                  _Chip(label: 'START', value: _fmtMs(start)),
                                  _Chip(label: 'END', value: _fmtMs(end)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Expanded(
                          child: GridView.builder(
                            itemCount: apps.length,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 1,
                            ),
                            itemBuilder: (context, i) {
                              final app = apps[i];
                              return _CerebrumCard(app: app);
                            },
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CerebrumApp {
  final String id;
  final String name;
  final String storeLink;
  final Color accent;
  final IconData icon;
  final bool isMine;
  final bool done;

  _CerebrumApp({
    required this.id,
    required this.name,
    required this.storeLink,
    required this.accent,
    required this.icon,
    required this.isMine,
    required this.done,
  });

  factory _CerebrumApp.from({
    required String id,
    required Map<String, dynamic> appMeta,
    required bool isMine,
    required bool done,
  }) {
    final name = (appMeta['app_name'] ?? id).toString().toUpperCase();
    final store = (appMeta['store_link'] ?? '').toString();
    return _CerebrumApp(
      id: id,
      name: name,
      storeLink: store,
      accent: _accentForId(id),
      icon: _iconForId(id),
      isMine: isMine,
      done: done,
    );
  }
}

class _CerebrumCard extends StatelessWidget {
  final _CerebrumApp app;
  const _CerebrumCard({required this.app});

  @override
  Widget build(BuildContext context) {
    final glow = app.isMine ? Try12Colors.highlight : app.accent;
    final tag = app.isMine ? 'YOU' : (app.done ? 'DONE' : 'ACTIVE');

    return AnimatedContainer(
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Try12Colors.panel,
            app.accent.withValues(alpha: 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: glow.withValues(alpha: app.done ? 0.45 : 0.25)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 14)),
          BoxShadow(color: glow.withValues(alpha: app.done ? 0.16 : 0.10), blurRadius: 28),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -30,
            child: Transform.rotate(
              angle: -0.6,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      glow.withValues(alpha: 0.28),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            glow.withValues(alpha: 0.95),
                            glow.withValues(alpha: 0.45),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(color: glow.withValues(alpha: 0.18), blurRadius: 20),
                        ],
                      ),
                      child: Icon(app.icon, size: 22, color: Try12Colors.bg),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '${app.id} • ${app.name}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontFamily: 'RobotoMono', fontSize: 12, color: Try12Colors.text, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tag,
                            style: TextStyle(fontFamily: 'RobotoMono', fontSize: 10, color: glow, letterSpacing: 0.8),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        app.storeLink.isEmpty ? '(no store link)' : app.storeLink,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: 'RobotoMono', fontSize: 10, color: Try12Colors.dim, height: 1.35),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Open on device',
                      onPressed: app.storeLink.isEmpty
                          ? null
                          : () async {
                              final uri = Uri.tryParse(app.storeLink);
                              if (uri == null) return;
                              await launchUrl(uri, mode: LaunchMode.platformDefault);
                            },
                      icon: Icon(Icons.open_in_new, color: glow, size: 18),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final String value;
  const _Chip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Try12Colors.board.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Try12Colors.border.withValues(alpha: 0.65)),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontFamily: 'RobotoMono', fontSize: 10, color: Try12Colors.text, height: 1.1),
      ),
    );
  }
}

String _fmtDurationMs(int ms) {
  final d = Duration(milliseconds: ms);
  final days = d.inDays;
  final hours = d.inHours.remainder(24);
  final minutes = d.inMinutes.remainder(60);
  if (days > 0) return '${days}d ${hours}h';
  if (hours > 0) return '${hours}h ${minutes}m';
  return '${minutes}m';
}

String _fmtMs(Object? ms) {
  final n = ms is num ? ms.toInt() : null;
  if (n == null || n <= 0) return '—';
  final dt = DateTime.fromMillisecondsSinceEpoch(n);
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} $hh:$mm';
}

const _palette = <Color>[
  Color(0xFF6CE4BA),
  Color(0xFFFEDB7E),
  Color(0xFF7C9CFF),
  Color(0xFFB48CFF),
  Color(0xFF54D2FF),
  Color(0xFFFFA24A),
  Color(0xFFFF6BD6),
  Color(0xFF6BFFB1),
  Color(0xFFFFE27B),
  Color(0xFF7BFFFD),
  Color(0xFF9FB2C7),
  Color(0xFF7EFF86),
];

const _icons = <IconData>[
  Icons.public,
  Icons.note,
  Icons.favorite,
  Icons.timelapse,
  Icons.cloud,
  Icons.email,
  Icons.qr_code_scanner,
  Icons.photo_camera,
  Icons.book,
  Icons.graphic_eq,
  Icons.event,
  Icons.account_balance_wallet,
];

Color _accentForId(String id) {
  final h = _stableHash(id);
  return _palette[h % _palette.length];
}

IconData _iconForId(String id) {
  final h = _stableHash(id);
  return _icons[h % _icons.length];
}

int _stableHash(String s) {
  var h = 0;
  for (final c in s.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return h;
}
