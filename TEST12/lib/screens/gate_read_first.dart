import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/background.dart';
import '../core/state_machine.dart';
import '../core/theme.dart';

class GateReadFirst extends StatefulWidget {
  final Try12Machine m;
  const GateReadFirst({super.key, required this.m});

  @override
  State<GateReadFirst> createState() => _GateReadFirstState();
}

class _GateReadFirstState extends State<GateReadFirst> {
  final appNameCtrl = TextEditingController();
  final appAddrCtrl = TextEditingController();
  final sudoNameCtrl = TextEditingController();
  final phoneNumCtrl = TextEditingController();
  final emailCtrl = TextEditingController(); // New email field
  final bundleIdCtrl = TextEditingController();
  final proDevAccessCtrl = TextEditingController();
  final GoogleSignIn _google = GoogleSignIn();
  bool _authBusy = false;

  @override
  void initState() {
    super.initState();
    _restoreGoogle();
    _restoreAdminToken();
  }

  Future<void> _restoreGoogle() async {
    try {
      final account = await _google.signInSilently();
      if (!mounted) return;
      if (account == null) return;
      widget.m.setGoogleIdentity(id: account.id, email: account.email, displayName: account.displayName);
      if (emailCtrl.text.trim().isEmpty) emailCtrl.text = account.email;
    } catch (_) {
      // Ignore — user can still submit with phone number.
    }
  }

  Future<void> _restoreAdminToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('adminToken') ?? '';
      if (!mounted) return;
      if (token.trim().isNotEmpty) proDevAccessCtrl.text = token.trim();
    } catch (_) {
      // ignore
    }
  }

  Future<void> _saveAdminToken(String raw) async {
    final token = raw.trim();
    final prefs = await SharedPreferences.getInstance();
    if (token.isEmpty) {
      await prefs.remove('adminToken');
    } else {
      await prefs.setString('adminToken', token);
    }
  }

  Future<void> _signInGoogle() async {
    if (_authBusy) return;
    setState(() => _authBusy = true);
    try {
      final account = await _google.signIn();
      if (!mounted) return;
      if (account == null) return;
      widget.m.setGoogleIdentity(id: account.id, email: account.email, displayName: account.displayName);
      emailCtrl.text = account.email;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('GOOGLE CONNECTED', style: TextStyle(fontFamily: 'RobotoMono')),
          duration: Duration(milliseconds: 900),
          backgroundColor: Try12Colors.board,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Google sign-in failed: $e', style: const TextStyle(fontFamily: 'RobotoMono')),
          duration: const Duration(milliseconds: 1600),
          backgroundColor: Try12Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _authBusy = false);
    }
  }

  Future<void> _signOutGoogle() async {
    if (_authBusy) return;
    setState(() => _authBusy = true);
    try {
      await _google.signOut();
      if (!mounted) return;
      widget.m.clearGoogleIdentity();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('GOOGLE SIGNED OUT', style: TextStyle(fontFamily: 'RobotoMono')),
          duration: Duration(milliseconds: 900),
          backgroundColor: Try12Colors.board,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Google sign-out failed: $e', style: const TextStyle(fontFamily: 'RobotoMono')),
          duration: const Duration(milliseconds: 1600),
          backgroundColor: Try12Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _authBusy = false);
    }
  }

  @override
  void dispose() {
    appNameCtrl.dispose();
    appAddrCtrl.dispose();
    sudoNameCtrl.dispose();
    phoneNumCtrl.dispose();
    emailCtrl.dispose();
    bundleIdCtrl.dispose();
    proDevAccessCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.m.scanning) {
      return _ScanPanelPage(m: widget.m);
    }

    final googleOn = widget.m.hasGoogleIdentity;
    final phoneLabel = googleOn ? 'PHONE NUMBER (OPTIONAL)' : 'PHONE NUMBER';
    final emailLabel = googleOn ? 'EMAIL (AUTO-FILLED)' : 'EMAIL';

    // Using LayoutBuilder + SingleChildScrollView to prevent overflow
    return Stack(
      children: [
        const Try12Background(),
        Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // TOP SECTION: Logo and Rules
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _LogoBanner(
                                onSecret: () {
                                  HapticFeedback.heavyImpact();
                                  widget.m.openCerebrum();
                                  widget.m.refresh(silent: true);
                                },
                              ),
                              const SizedBox(height: 22),
                              const Text('READ FIRST', style: TextStyle(letterSpacing: 1.2, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 10),
                              Text('STEPS REQUIRED TO PROCEED', style: Theme.of(context).textTheme.bodySmall),
                              const SizedBox(height: 8),
                              const _Bullet('Follow steps in order.'),
                              const _Bullet('No alternate paths.'),
                              const _Bullet('You are processed, not coached.'),
                              const _Bullet('The terminal confirms alignment when input is valid.'),
                            ],
                          ),

                          // BOTTOM SECTION: Inputs + Submit Action
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 40),
                              GestureDetector(
                                onTap: _authBusy ? null : (googleOn ? _signOutGoogle : _signInGoogle),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Try12Colors.panel,
                                    border: Border.all(color: googleOn ? Try12Colors.green : Try12Colors.border),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              googleOn ? 'GOOGLE CONNECTED' : 'SIGN IN WITH GOOGLE (RECOMMENDED)',
                                              style: const TextStyle(fontFamily: 'RobotoMono', fontSize: 11, color: Try12Colors.text, letterSpacing: 0.6),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              googleOn ? (widget.m.googleEmail ?? '(no email)') : 'Locks your slot to your Google account.',
                                              style: const TextStyle(fontFamily: 'RobotoMono', fontSize: 10, color: Try12Colors.dim, height: 1.25),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      if (_authBusy)
                                        const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      else
                                        Text(
                                          googleOn ? 'SIGN OUT' : 'SIGN IN',
                                          style: const TextStyle(fontFamily: 'RobotoMono', fontSize: 11, color: Try12Colors.highlight, letterSpacing: 0.6),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Warning Text
                              const Text(
                                'One account = one active app.\nMultiple submissions reduce visibility.',
                                style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Try12Colors.amber, height: 1.4),
                              ),
                              const SizedBox(height: 12),

                              // Inputs
                              _InputBox(label: 'APP NAME', controller: appNameCtrl),
                              const SizedBox(height: 8),
                              _InputBox(label: 'APP LINK', controller: appAddrCtrl),
                              const SizedBox(height: 8),
                              _InputBox(label: 'SENDER NAME', controller: sudoNameCtrl),
                              const SizedBox(height: 8),
                              _InputBox(label: phoneLabel, controller: phoneNumCtrl, isNumeric: true),
                              const SizedBox(height: 8),
                              _InputBox(label: emailLabel, controller: emailCtrl, isEmail: true),
                              const SizedBox(height: 8),
                              _InputBox(label: 'BUNDLE ID (OPTIONAL)', controller: bundleIdCtrl),

                              const SizedBox(height: 24),

                              // ACTION BUTTON
                              GestureDetector(
                                onTap: () {
                                  final appName = appNameCtrl.text;
                                  final appAddr = appAddrCtrl.text;
                                  final sudoName = sudoNameCtrl.text;
                                  final phoneNum = phoneNumCtrl.text;
                                  final email = emailCtrl.text;
                                  final bundleId = bundleIdCtrl.text;
                                  final googleKey = widget.m.googleUserId;
                                  final effectiveEmail = email.trim().isNotEmpty ? email.trim() : (widget.m.googleEmail ?? '');
                                  final hasIdentity = (googleKey?.trim().isNotEmpty == true) || phoneNum.trim().isNotEmpty;
                                  if (appName.trim().isNotEmpty &&
                                      appAddr.trim().isNotEmpty &&
                                      sudoName.trim().isNotEmpty &&
                                      hasIdentity &&
                                      effectiveEmail.trim().isNotEmpty) {
                                    widget.m.passGateAndSubmit(
                                      appName: appName,
                                      storeLink: appAddr,
                                      sudoName: sudoName,
                                      phoneNum: phoneNum,
                                      email: effectiveEmail,
                                      bundleId: bundleId,
                                      userKey: googleKey,
                                    );
                                  }
                                },
                                child: Container(
                                  height: 56,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: Try12Colors.panel,
                                    border: Border.all(color: Try12Colors.border),
                                  ),
                                  child: const Row(
                                    children: [
                                      Text(
                                        'INITIALIZE >',
                                        style: TextStyle(fontFamily: 'monospace', color: Try12Colors.text, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 12),

                              // PRO🗂️DEV ACCESS (subtle admin shortcut)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Try12Colors.board.withValues(alpha: 0.28),
                                  border: Border.all(color: Try12Colors.border.withValues(alpha: 0.65)),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: proDevAccessCtrl,
                                        obscureText: true,
                                        obscuringCharacter: '•',
                                        style: const TextStyle(fontFamily: 'RobotoMono', fontSize: 11, color: Try12Colors.text, letterSpacing: 0.4),
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          border: InputBorder.none,
                                          hintText: 'PRO🗂️DEV ACCESS',
                                          hintStyle: TextStyle(fontFamily: 'RobotoMono', fontSize: 11, color: Try12Colors.dim, letterSpacing: 0.6),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    GestureDetector(
                                      onTap: () async {
                                        await _saveAdminToken(proDevAccessCtrl.text);
                                        if (!mounted) return;
                                        widget.m.openControlRoom();
                                      },
                                      child: const Text(
                                        'ENTER',
                                        style: TextStyle(fontFamily: 'RobotoMono', fontSize: 11, color: Try12Colors.highlight, letterSpacing: 0.8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _LogoBanner extends StatefulWidget {
  final VoidCallback onSecret;
  const _LogoBanner({required this.onSecret});

  @override
  State<_LogoBanner> createState() => _LogoBannerState();
}

class _LogoBannerState extends State<_LogoBanner> {
  final Map<int, Offset> _pointers = {};
  Size _lastSize = Size.zero;
  bool _triggered = false;
  bool _holding = false;

  void _clearHold() {
    _holding = false;
  }

  bool _inCircle(Offset p, Offset c, double r) => (p - c).distance <= r;

  void _evaluateHold() {
    if (_triggered) return;
    final size = _lastSize;
    if (size.width <= 0 || size.height <= 0) return;

    final leftEye = Offset(size.width * 0.38, size.height * 0.43);
    final rightEye = Offset(size.width * 0.62, size.height * 0.43);
    final r = math.min(size.width, size.height) * 0.14;

    bool hasLeft = false;
    bool hasRight = false;
    for (final p in _pointers.values) {
      hasLeft = hasLeft || _inCircle(p, leftEye, r);
      hasRight = hasRight || _inCircle(p, rightEye, r);
    }

    final ok = hasLeft && hasRight;
    if (ok && !_holding) {
      _holding = true;
      Future.delayed(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        if (_triggered) return;
        _evaluateHold();
        if (!_holding) return;
        _triggered = true;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('CEREBRUM', style: TextStyle(fontFamily: 'RobotoMono')),
            duration: Duration(milliseconds: 900),
            backgroundColor: Try12Colors.board,
          ),
        );
        widget.onSecret();
      });
    } else if (!ok && _holding) {
      _clearHold();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _lastSize = Size(constraints.maxWidth, constraints.maxHeight);
          return Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.transparent,
                      Try12Colors.board.withValues(alpha: 0.92),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Try12Colors.accent.withValues(alpha: 0.14),
                        Colors.transparent,
                        Try12Colors.highlight.withValues(alpha: 0.14),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Column(
                  children: [
                    Container(height: 1, color: Try12Colors.highlight.withValues(alpha: 0.28)),
                    const Spacer(),
                    Container(height: 1, color: Try12Colors.accent.withValues(alpha: 0.22)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (rect) {
                    return const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.transparent,
                        Colors.black,
                        Colors.black,
                        Colors.transparent,
                      ],
                      stops: [0.0, 0.12, 0.88, 1.0],
                    ).createShader(rect);
                  },
                  child: Image.asset(
                    'assets/images/test12-official.png',
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
              Positioned.fill(
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (e) {
                    _pointers[e.pointer] = e.localPosition;
                    _evaluateHold();
                  },
                  onPointerMove: (e) {
                    _pointers[e.pointer] = e.localPosition;
                    _evaluateHold();
                  },
                  onPointerUp: (e) {
                    _pointers.remove(e.pointer);
                    _clearHold();
                  },
                  onPointerCancel: (e) {
                    _pointers.remove(e.pointer);
                    _clearHold();
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// This is the full-screen scan panel view
class _ScanPanelPage extends StatelessWidget {
  final Try12Machine m;
  const _ScanPanelPage({required this.m});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: Colors.black),
        const Positioned.fill(child: IgnorePointer(child: _TerminalScanlines())),
        Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'ASSESSING…',
                    style: TextStyle(fontFamily: 'RobotoMono', letterSpacing: 2.0, color: Try12Colors.green),
                  ),
                  const SizedBox(height: 10),
                  AnimatedBuilder(
                    animation: m,
                    builder: (_, __) {
                      return Column(
                        children: [
                          ClipRect(
                            child: SizedBox(
                              width: double.infinity,
                              child: Text(
                                m.scanLine,
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.fade,
                                style: TextStyle(
                                  fontFamily: 'RobotoMono',
                                  fontSize: 12,
                                  color: m.scanRedMoment ? Try12Colors.red : Try12Colors.green,
                                  height: 1.2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
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

class _TerminalScanlines extends StatelessWidget {
  const _TerminalScanlines();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TerminalScanlinesPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _TerminalScanlinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()..color = Colors.white.withValues(alpha: 0.05);
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


class _InputBox extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool isNumeric;
  final bool isEmail;

  const _InputBox({required this.label, required this.controller, this.isNumeric = false, this.isEmail = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Try12Colors.dim)),
        const SizedBox(height: 4),
        SizedBox(
          height: 36, // Slightly taller for touch targets
          child: TextField(
            controller: controller,
            keyboardType: isNumeric ? TextInputType.phone : (isEmail ? TextInputType.emailAddress : TextInputType.text),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Try12Colors.text),
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 10),
              filled: true,
              fillColor: Try12Colors.panel,
              border: OutlineInputBorder(borderSide: BorderSide(color: Try12Colors.border)),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Try12Colors.border)),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Try12Colors.green)),
            ),
          ),
        ),
      ],
    );
  }
}

class _Bullet extends StatelessWidget {
  final String t;
  const _Bullet(this.t);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text('• $t', style: const TextStyle(fontFamily: 'monospace')),
    );
  }
}
