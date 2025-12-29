import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/state_machine.dart';
import '../core/theme.dart';

class GateReadFirst extends StatefulWidget {
  final Try12Machine m;
  const GateReadFirst({super.key, required this.m});

  @override
  State<GateReadFirst> createState() => _GateReadFirstState();
}

class _GateReadFirstState extends State<GateReadFirst> {
  static const String _siteBaseUrl = String.fromEnvironment(
    'TRY12_SITE_URL',
    defaultValue: 'https://test-12test.netlify.app',
  );

  late final TextEditingController _userIdCtrl;
  late final TextEditingController _appNameCtrl;
  late final TextEditingController _storeLinkCtrl;

  bool _userOk = false;
  bool _nameOk = false;
  bool _linkOk = false;

  bool get _allOk => _userOk && _nameOk && _linkOk;
  bool get _canLoad => _userOk;

  @override
  void initState() {
    super.initState();
    _userIdCtrl = TextEditingController(text: widget.m.userId ?? '');
    _appNameCtrl = TextEditingController();
    _storeLinkCtrl = TextEditingController();
    _userIdCtrl.addListener(_revalidate);
    _appNameCtrl.addListener(_revalidate);
    _storeLinkCtrl.addListener(_revalidate);
    _revalidate();
  }

  @override
  void dispose() {
    _userIdCtrl.dispose();
    _appNameCtrl.dispose();
    _storeLinkCtrl.dispose();
    super.dispose();
  }

  void _revalidate() {
    final nextUserOk = _userIdCtrl.text.trim().isNotEmpty;
    final nextNameOk = _appNameCtrl.text.trim().isNotEmpty;
    final nextLinkOk = _isLinkValid(_storeLinkCtrl.text);

    if (nextUserOk != _userOk || nextNameOk != _nameOk || nextLinkOk != _linkOk) {
      setState(() {
        _userOk = nextUserOk;
        _nameOk = nextNameOk;
        _linkOk = nextLinkOk;
      });
    }
  }

  bool _isLinkValid(String raw) {
    final normalized = _normalizeLink(raw);
    if (normalized.isEmpty) return false;
    final uri = Uri.tryParse(normalized);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  String _normalizeLink(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return '';
    final collapsed = trimmed.replaceAll(RegExp(r'\\s+'), '');
    if (collapsed.startsWith(RegExp(r'https?://'))) return collapsed;
    return 'https://$collapsed';
  }

  Future<void> _submit() async {
    if (!_allOk) return;
    await widget.m.submitAndVerify(
      userIdInput: _userIdCtrl.text,
      appNameInput: _appNameCtrl.text,
      storeLinkInput: _storeLinkCtrl.text,
    );
  }

  Future<void> _load() async {
    if (!_canLoad) return;
    widget.m.userId = _userIdCtrl.text.trim();
    await widget.m.refresh();
  }

  Future<void> _openSite(String path) async {
    final base = _siteBaseUrl.trim();
    if (base.isEmpty) return;
    final uri = Uri.tryParse('$base$path');
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Try12Colors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'TEST 12',
                style: TextStyle(
                  fontFamily: 'RobotoMono',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: Try12Colors.text,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Identity + verification gate.\n'
                'One verified user = one free app at a time.\n'
                'Apps are metadata + store links only.',
                style: TextStyle(
                  fontFamily: 'RobotoMono',
                  fontSize: 11,
                  height: 1.4,
                  color: Try12Colors.dim,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton(
                    onPressed: () => _openSite('/'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Try12Colors.highlight,
                      side: const BorderSide(color: Try12Colors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('WEBSITE', style: TextStyle(fontFamily: 'RobotoMono')),
                  ),
                  OutlinedButton(
                    onPressed: () => _openSite('/privacy'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Try12Colors.highlight,
                      side: const BorderSide(color: Try12Colors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('PRIVACY', style: TextStyle(fontFamily: 'RobotoMono')),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _Field(
                label: 'USER_ID',
                controller: _userIdCtrl,
                ok: _userOk,
              ),
              const SizedBox(height: 10),
              if (widget.m.remoteEnabled)
                ElevatedButton(
                  onPressed: _canLoad ? _load : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Try12Colors.board,
                    foregroundColor: Try12Colors.text,
                    disabledBackgroundColor: Try12Colors.panel.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'LOAD FROM SERVER',
                    style: TextStyle(fontFamily: 'RobotoMono'),
                  ),
                ),
              if (widget.m.remoteEnabled) const SizedBox(height: 10),
              _Field(
                label: 'APP_NAME',
                controller: _appNameCtrl,
                ok: _nameOk,
              ),
              const SizedBox(height: 10),
              _Field(
                label: 'STORE_LINK',
                controller: _storeLinkCtrl,
                ok: _linkOk,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _allOk ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Try12Colors.panel,
                  foregroundColor: Try12Colors.text,
                  disabledBackgroundColor: Try12Colors.panel.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'SUBMIT',
                  style: TextStyle(fontFamily: 'RobotoMono'),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.m.remoteEnabled
                    ? 'If you already submitted on the website, enter USER_ID and tap LOAD.'
                    : 'Participation is optional. Presence is sufficient.',
                style: const TextStyle(
                  fontFamily: 'RobotoMono',
                  fontSize: 10,
                  color: Try12Colors.dim,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool ok;

  const _Field({
    required this.label,
    required this.controller,
    required this.ok,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Try12Colors.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ok ? Try12Colors.border : Try12Colors.red.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'RobotoMono',
              fontSize: 10,
              color: Try12Colors.highlight,
            ),
          ),
          TextField(
            controller: controller,
            style: const TextStyle(fontFamily: 'RobotoMono', fontSize: 12),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
            ),
          ),
        ],
      ),
    );
  }
}
