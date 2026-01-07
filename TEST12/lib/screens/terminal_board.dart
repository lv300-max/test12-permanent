import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/background.dart';
import '../core/models.dart';
import '../core/state_machine.dart';
import '../core/theme.dart';

class TerminalBoardScreen extends StatefulWidget {
  final Try12Machine m;
  const TerminalBoardScreen({super.key, required this.m});

  @override
  State<TerminalBoardScreen> createState() => _TerminalBoardScreenState();
}

class _TerminalBoardScreenState extends State<TerminalBoardScreen> with SingleTickerProviderStateMixin {
  late final AudioPlayer _chirp = AudioPlayer();
  late final AnimationController _saluteC = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  late final AnimationController _glideC = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 7200),
  )..repeat();

  bool _showSalute = false;
  String _saluteText = '';

  @override
  void dispose() {
    _saluteC.dispose();
    _glideC.dispose();
    _chirp.dispose();
    super.dispose();
  }

  Future<void> _triggerSalute(String message) async {
    if (_showSalute) return;
    if (!mounted) return;

    setState(() {
      _showSalute = true;
      _saluteText = message;
    });

    _saluteC.forward(from: 0);

    HapticFeedback.lightImpact();
    try {
      await _chirp.stop();
      await _chirp.play(
        AssetSource('sfx/coqui.wav'),
        volume: 1.0,
      );
    } catch (_) {
      // Best-effort only (audio can fail on some devices / silent mode).
    }

    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      setState(() => _showSalute = false);
    });
  }

  Future<void> _playSonarPing() async {
    HapticFeedback.mediumImpact();
    try {
      await _chirp.stop();
      await _chirp.play(
        AssetSource('sfx/coqui.wav'),
        volume: 1.0,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SONAR PING', style: TextStyle(fontFamily: 'RobotoMono')),
            duration: Duration(milliseconds: 900),
            backgroundColor: Try12Colors.board,
          ),
        );
      }
    } catch (_) {
      // ignore audio failures
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.m;

    if (m.buzzPending) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Try12Colors.panel,
            content: Text(
              m.buzzMessage ?? 'SESSION STARTED',
              style: const TextStyle(fontFamily: 'RobotoMono', color: Try12Colors.text, fontSize: 12),
            ),
            duration: const Duration(milliseconds: 1800),
            action: SnackBarAction(
              label: 'OK',
              textColor: Try12Colors.highlight,
              onPressed: () {},
            ),
          ),
        );
        m.clearBuzz();
      });
    }

    if (m.salutePending) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!context.mounted) return;
        final msg = m.saluteMessage ?? 'FAIR TESTER CONFIRMED';
        m.clearSalute();
        await _triggerSalute(msg);
      });
    }

    final inSession = m.inSession;
    final inRoom = m.inFormingRoom;
    final remaining = m.sessionRemaining;
    final testsRequired = m.testsRequired;
    final testsDone = m.testsDone;
    final targetTotal = m.targetTotal;

    final statusText = !m.apiReady
        ? 'BACKEND NOT SET'
        : (inSession
            ? 'SESSION ACTIVE'
            : (inRoom ? 'ROOM FILLING' : 'WAITING'));

    final targetFilled = m.roomTargetFilled ?? m.assigned.length;
    final targetNeeded = m.roomTargetNeeded ?? (targetTotal - targetFilled);

    final secondaryText = !m.apiReady
        ? 'Set `api_base_url` in config.json or pass `--dart-define=TRY12_API_BASE_URL=...`'
        : (inSession
            ? 'Complete $testsRequired tests (other apps).'
            : (inRoom
                ? 'Room: $targetFilled/$targetTotal • Needed: ${targetNeeded < 0 ? 0 : targetNeeded}'
                : 'Queue position: ${m.queuePosition ?? '—'}'));

    return Stack(
      children: [
        const Try12Background(),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('TERMINAL', style: TextStyle(fontFamily: 'RobotoMono')),
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            actions: [
              IconButton(
                tooltip: 'Sonar ping',
                onPressed: _playSonarPing,
                icon: const Icon(Icons.waves),
              ),
              IconButton(
                tooltip: 'Control room',
                onPressed: () => m.openControlRoom(),
                icon: const Icon(Icons.remove_red_eye_outlined),
              ),
              IconButton(
                tooltip: 'Backend',
                onPressed: () async {
                  final ctrl = TextEditingController(text: m.apiBaseUrl);
                  try {
                    final action = await showDialog<String>(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: Try12Colors.panel,
                        title: const Text('BACKEND URL', style: TextStyle(fontFamily: 'RobotoMono', color: Try12Colors.text)),
                        content: TextField(
                          controller: ctrl,
                          style: const TextStyle(fontFamily: 'RobotoMono', fontSize: 12, color: Try12Colors.text),
                          decoration: const InputDecoration(
                            hintText: 'https://your-backend',
                            hintStyle: TextStyle(fontFamily: 'RobotoMono', fontSize: 12, color: Try12Colors.dim),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop('cancel'),
                            child: const Text('CANCEL', style: TextStyle(fontFamily: 'RobotoMono')),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop('config'),
                            child: const Text('USE CONFIG', style: TextStyle(fontFamily: 'RobotoMono')),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop('save'),
                            child: const Text('SAVE', style: TextStyle(fontFamily: 'RobotoMono', color: Try12Colors.highlight)),
                          ),
                        ],
                      ),
                    );
                    if (action == 'save') {
                      await m.setApiBaseUrl(ctrl.text);
                    } else if (action == 'config') {
                      await m.useConfigApiBaseUrl();
                    }
                  } finally {
                    ctrl.dispose();
                  }
                },
                icon: const Icon(Icons.link),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: () => m.refresh(),
                icon: const Icon(Icons.refresh),
              ),
              IconButton(
                tooltip: 'Pulse',
                onPressed: () => m.pulse(),
                icon: const Icon(Icons.wifi_tethering),
              ),
              IconButton(
                tooltip: 'Reset',
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: Try12Colors.panel,
                      title: const Text('RESET?', style: TextStyle(fontFamily: 'RobotoMono', color: Try12Colors.text)),
                      content: const Text(
                        'This clears your local device state (user id + cached session view).',
                        style: TextStyle(fontFamily: 'RobotoMono', fontSize: 12, color: Try12Colors.dim, height: 1.35),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('CANCEL', style: TextStyle(fontFamily: 'RobotoMono')),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('RESET', style: TextStyle(fontFamily: 'RobotoMono', color: Try12Colors.red)),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) m.resetLocal();
                },
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (m.loading) ...[
                    const LinearProgressIndicator(minHeight: 2),
                    const SizedBox(height: 10),
                  ],
                  _GlideSheen(
                    t: _glideC,
                    phase: 0.0,
                    borderRadius: BorderRadius.circular(14),
                    child: _StatusCard(
                      apiBaseUrl: m.apiBaseUrl,
                      userId: m.userId,
                      statusText: statusText,
                      secondaryText: secondaryText,
                      remaining: remaining,
                      testsDone: testsDone,
                      testsRequired: testsRequired,
                      inSession: inSession,
                      testsComplete: m.testsComplete,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (m.myAppCard != null) ...[
                    _GlideSheen(
                      t: _glideC,
                      phase: 0.08,
                      borderRadius: BorderRadius.circular(14),
                      child: _MyAppCard(m: m),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _GlideSheen(
                    t: _glideC,
                    phase: 0.16,
                    borderRadius: BorderRadius.circular(14),
                    child: _AssignmentRow(m: m),
                  ),
                  const SizedBox(height: 12),
                  if (m.lastError != null) ...[
                    _GlideSheen(
                      t: _glideC,
                      phase: 0.24,
                      borderRadius: BorderRadius.circular(14),
                      sheenIntensity: 0.03,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: Try12Gradients.panel,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Try12Colors.red.withValues(alpha: 0.45)),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 30, offset: const Offset(0, 18)),
                            BoxShadow(color: Try12Colors.red.withValues(alpha: 0.10), blurRadius: 22, offset: const Offset(0, 12)),
                          ],
                        ),
                        child: Text(
                          m.lastError!,
                          style: const TextStyle(fontFamily: 'RobotoMono', fontSize: 11, color: Try12Colors.red, height: 1.35),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _AppList(m: m, t: _glideC),
                ],
              ),
            ),
          ),
        ),
        if (_showSalute)
          Positioned.fill(
            child: IgnorePointer(
              child: _SaluteOverlay(
                t: CurvedAnimation(parent: _saluteC, curve: Curves.easeOutCubic),
                message: _saluteText,
              ),
            ),
          ),
      ],
    );
  }
}

class _GlideSheen extends StatelessWidget {
  final Animation<double> t;
  final double phase;
  final double amplitude;
  final double sheenIntensity;
  final BorderRadius borderRadius;
  final Widget child;

  const _GlideSheen({
    required this.t,
    required this.borderRadius,
    required this.child,
    this.phase = 0.0,
    this.amplitude = 1.8,
    this.sheenIntensity = 0.04,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: t,
      child: child,
      builder: (context, child) {
        final v = (t.value + phase) % 1.0;
        final dy = math.sin(v * math.pi * 2) * amplitude;
        final sheenT = (v + 0.12) % 1.0;

        return Transform.translate(
          offset: Offset(0, dy),
          child: Stack(
            children: [
              child!,
              Positioned.fill(
                child: IgnorePointer(
                  child: ClipRRect(
                    borderRadius: borderRadius,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: Try12Gradients.sheen(sheenT, intensity: sheenIntensity),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String apiBaseUrl;
  final String? userId;
  final String statusText;
  final String secondaryText;
  final Duration? remaining;
  final int testsDone;
  final int testsRequired;
  final bool inSession;
  final bool testsComplete;

  const _StatusCard({
    required this.apiBaseUrl,
    required this.userId,
    required this.statusText,
    required this.secondaryText,
    required this.remaining,
    required this.testsDone,
    required this.testsRequired,
    required this.inSession,
    required this.testsComplete,
  });

  @override
  Widget build(BuildContext context) {
    final remText = remaining == null
        ? '—'
        : remaining == Duration.zero
            ? 'COMPLETE'
            : _formatDuration(remaining!);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: Try12Gradients.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Try12Colors.border.withValues(alpha: 0.75)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 30, offset: const Offset(0, 18)),
          BoxShadow(color: Try12Colors.highlight.withValues(alpha: 0.06), blurRadius: 26, offset: const Offset(0, 12)),
          BoxShadow(color: Try12Colors.accent.withValues(alpha: 0.05), blurRadius: 26, offset: const Offset(0, 12)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            statusText,
            style: const TextStyle(fontFamily: 'RobotoMono', color: Try12Colors.text, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.6),
          ),
          const SizedBox(height: 8),
          Text(
            secondaryText,
            style: const TextStyle(fontFamily: 'RobotoMono', color: Try12Colors.dim, fontSize: 11, height: 1.35),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Pill(label: 'BACKEND', value: apiBaseUrl.isEmpty ? '(not set)' : apiBaseUrl),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: userId == null || userId!.trim().isEmpty
                    ? const _Pill(label: 'USER', value: '(none)')
                    : _PulsePill(label: 'USER', value: userId!),
              ),
            ],
          ),
          if (inSession) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _Pill(label: 'REMAINING', value: remText)),
                const SizedBox(width: 10),
                Expanded(
                  child: _Pill(
                    label: 'TESTS',
                    value: '$testsDone/$testsRequired',
                    accent: testsComplete ? Try12Colors.green : Try12Colors.highlight,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _formatDuration(Duration d) {
    final totalMinutes = d.inMinutes;
    final days = totalMinutes ~/ (24 * 60);
    final hours = (totalMinutes % (24 * 60)) ~/ 60;
    final minutes = totalMinutes % 60;
    if (days > 0) return '${days}d ${hours}h';
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final String value;
  final Color? accent;

  const _Pill({required this.label, required this.value, this.accent});

  @override
  Widget build(BuildContext context) {
    final a = accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Try12Colors.board.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: (a ?? Try12Colors.border).withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: const TextStyle(fontFamily: 'RobotoMono', fontSize: 10, color: Try12Colors.dim, letterSpacing: 0.8),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: 'RobotoMono', fontSize: 11, color: a ?? Try12Colors.text, height: 1.2),
          ),
        ],
      ),
    );
  }
}

class _PulsePill extends StatefulWidget {
  final String label;
  final String value;

  const _PulsePill({required this.label, required this.value});

  @override
  State<_PulsePill> createState() => _PulsePillState();
}

class _PulsePillState extends State<_PulsePill> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat(reverse: true);

  late final Animation<double> _t = CurvedAnimation(parent: _c, curve: Curves.easeInOutSine);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      builder: (context, child) {
        final v = _t.value;
        final border = Color.lerp(
          Try12Colors.border.withValues(alpha: 0.55),
          Try12Colors.highlight.withValues(alpha: 0.75),
          v * 0.35,
        )!;
        final glow = Try12Colors.highlight.withValues(alpha: 0.10 * v);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: Try12Colors.board.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: glow,
                blurRadius: 18,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.label,
                style: const TextStyle(fontFamily: 'RobotoMono', fontSize: 10, color: Try12Colors.dim, letterSpacing: 0.8),
              ),
              const SizedBox(height: 6),
              Text(
                widget.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'RobotoMono', fontSize: 11, color: Try12Colors.text, height: 1.2),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MyAppCard extends StatelessWidget {
  final Try12Machine m;
  const _MyAppCard({required this.m});

  @override
  Widget build(BuildContext context) {
    final app = m.myAppCard!;
    final status = m.inSession
        ? (m.testsComplete ? 'UNLOCKED' : 'LOCKED')
        : 'WAITING';
    final color = m.testsComplete
        ? Try12Colors.green
        : (m.inSession ? Try12Colors.highlight : Try12Colors.dim);
    final borderColor = m.testsComplete ? Try12Colors.green.withValues(alpha: 0.55) : Try12Colors.border;

    return InkWell(
      onTap: () => m.openAppDetail(app.id),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Try12Colors.panel,
              Try12Colors.board.withValues(alpha: 0.92),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 30, offset: const Offset(0, 18)),
            BoxShadow(color: app.accent.withValues(alpha: 0.06), blurRadius: 28, offset: const Offset(0, 12)),
            if (m.testsComplete) BoxShadow(color: Try12Colors.green.withValues(alpha: 0.14), blurRadius: 26),
          ],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 42,
              height: 42,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (m.testsComplete ? Try12Colors.green : app.accent).withValues(alpha: 0.9),
                      ),
                      child: Icon(app.icon, size: 22, color: Try12Colors.bg),
                    ),
                  ),
                  if (m.testsComplete)
                    const Positioned(
                      right: -3,
                      bottom: -3,
                      child: Icon(Icons.check_circle, size: 18, color: Try12Colors.green),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
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
                    'YOUR APP • $status',
                    style: TextStyle(fontFamily: 'RobotoMono', fontSize: 10, color: color, letterSpacing: 0.6),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Try12Colors.dim),
          ],
        ),
      ),
    );
  }
}

class _AssignmentRow extends StatelessWidget {
  final Try12Machine m;
  const _AssignmentRow({required this.m});

  @override
  Widget build(BuildContext context) {
    final apps = m.assigned;
    final total = m.targetTotal;
    final ready = m.inSession && apps.length == total;
    final filled = apps.length.clamp(0, total);
    final showMap = m.inSession || m.inFormingRoom || apps.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
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
          Text(
            ready ? 'ASSIGNMENT MAP ($total)' : 'ROOM ( $filled / $total )',
            style: TextStyle(
              fontFamily: 'RobotoMono',
              fontSize: 10,
              letterSpacing: 0.8,
              color: ready ? Try12Colors.text : Try12Colors.dim,
            ),
          ),
          const SizedBox(height: 10),
          if (!showMap)
            const Text(
              'Waiting for session…',
              style: TextStyle(fontFamily: 'RobotoMono', fontSize: 11, color: Try12Colors.dim, height: 1.35),
            )
          else
            Row(
              children: [
                for (var i = 0; i < total; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: i < apps.length
                          ? _AppCell(
                              app: apps[i],
                              onTap: () => m.openAppDetail(apps[i].id),
                            )
                          : const _EmptyCell(),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 10),
          const Text(
            'Test your 12 assigned apps.',
            style: TextStyle(fontFamily: 'RobotoMono', fontSize: 10, color: Try12Colors.dim, height: 1.35),
          ),
        ],
      ),
    );
  }

  static Color _cellColor(MockApp app) {
    return app.opened ? Try12Colors.green : Try12Colors.border.withValues(alpha: 0.55);
  }
}

class _AppCell extends StatelessWidget {
  final MockApp app;
  final VoidCallback onTap;

  const _AppCell({required this.app, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            color: _AssignmentRow._cellColor(app),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Try12Colors.border.withValues(alpha: 0.6)),
          ),
          child: Icon(
            app.icon,
            size: 14,
            color: Try12Colors.bg.withValues(alpha: 0.9),
          ),
        ),
      ),
    );
  }
}

class _EmptyCell extends StatelessWidget {
  const _EmptyCell();

  @override
  Widget build(BuildContext context) {
    return const AspectRatio(
      aspectRatio: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color(0x33222B3A),
          borderRadius: BorderRadius.all(Radius.circular(6)),
        ),
        child: Icon(Icons.lock_outline, size: 14, color: Try12Colors.dim),
      ),
    );
  }
}

class _AppList extends StatelessWidget {
  final Try12Machine m;
  final Animation<double> t;
  const _AppList({required this.m, required this.t});

  @override
  Widget build(BuildContext context) {
    final apps = m.assigned;
    if (apps.isEmpty) {
      return _GlideSheen(
        t: t,
        phase: 0.30,
        borderRadius: BorderRadius.circular(14),
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
          child: const Text(
            'No session data yet. Submit your app on the Gate screen.',
            style: TextStyle(fontFamily: 'RobotoMono', fontSize: 11, color: Try12Colors.dim, height: 1.35),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < apps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _GlideSheen(
              t: t,
              phase: 0.36 + (i * 0.045),
              borderRadius: BorderRadius.circular(14),
              amplitude: 1.4,
              child: _AppRow(
                app: apps[i],
                onTap: () => m.openAppDetail(apps[i].id),
              ),
            ),
          ),
      ],
    );
  }
}

class _AppRow extends StatelessWidget {
  final MockApp app;
  final VoidCallback onTap;

  const _AppRow({required this.app, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final done = app.opened;
    final label = done ? 'DONE' : 'PENDING';
    final color = done ? Try12Colors.green : Try12Colors.dim;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
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
          border: Border.all(color: (done ? Try12Colors.green : Try12Colors.border).withValues(alpha: 0.75)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 30, offset: const Offset(0, 18)),
            BoxShadow(color: app.accent.withValues(alpha: 0.06), blurRadius: 26, offset: const Offset(0, 12)),
            if (done) BoxShadow(color: Try12Colors.green.withValues(alpha: 0.10), blurRadius: 26),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: app.accent.withValues(alpha: 0.9),
              ),
              child: Icon(app.icon, size: 22, color: Try12Colors.bg),
            ),
            const SizedBox(width: 12),
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
                    label,
                    style: TextStyle(fontFamily: 'RobotoMono', fontSize: 10, color: color, letterSpacing: 0.6),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Try12Colors.dim),
          ],
        ),
      ),
    );
  }
}

class _SaluteOverlay extends StatelessWidget {
  final Animation<double> t;
  final String message;

  const _SaluteOverlay({required this.t, required this.message});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: t,
      builder: (context, _) {
        final v = t.value.clamp(0.0, 1.0);
        final fadeIn = (v / 0.12).clamp(0.0, 1.0);
        final fadeOut = ((1.0 - v) / 0.18).clamp(0.0, 1.0);
        final opacity = math.min(1.0, fadeIn * fadeOut);

        return Opacity(
          opacity: opacity,
          child: Stack(
            children: [
              CustomPaint(
                painter: _RadarBurstPainter(v),
                child: const SizedBox.expand(),
              ),
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 96),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Try12Colors.panel.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Try12Colors.green.withValues(alpha: 0.38)),
                      boxShadow: [
                        BoxShadow(color: Try12Colors.green.withValues(alpha: 0.14), blurRadius: 30),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'RobotoMono',
                            fontSize: 12,
                            color: Try12Colors.text,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '12/12 COMPLETE',
                          style: TextStyle(
                            fontFamily: 'RobotoMono',
                            fontSize: 10,
                            color: Try12Colors.green,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RadarBurstPainter extends CustomPainter {
  final double t;
  _RadarBurstPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width * 0.78, 170);
    final maxR = math.sqrt(size.width * size.width + size.height * size.height);

    // Soft green wash
    final wash = Paint()
      ..shader = RadialGradient(
        center: Alignment((origin.dx / size.width) * 2 - 1, (origin.dy / size.height) * 2 - 1),
        radius: 1.0,
        colors: [
          Try12Colors.green.withValues(alpha: 0.16 * (1.0 - t)),
          Colors.transparent,
        ],
        stops: const [0.0, 0.9],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, wash);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 5; i++) {
      final p = ((t + i * 0.17) % 1.0).clamp(0.0, 1.0);
      final r = p * maxR;
      final a = (1.0 - p) * 0.22;
      ringPaint
        ..strokeWidth = 2.0 + (1.0 - p) * 1.5
        ..color = Try12Colors.green.withValues(alpha: a);
      canvas.drawCircle(origin, r, ringPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarBurstPainter oldDelegate) => oldDelegate.t != t;
}
