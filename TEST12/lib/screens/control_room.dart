import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/background.dart';
import '../core/state_machine.dart';
import '../core/theme.dart';

class ControlRoomScreen extends StatefulWidget {
  final Try12Machine m;
  const ControlRoomScreen({super.key, required this.m});

  @override
  State<ControlRoomScreen> createState() => _ControlRoomScreenState();
}

class _ControlRoomScreenState extends State<ControlRoomScreen> {
  static const _pollEvery = Duration(seconds: 3);
  static const _httpTimeout = Duration(seconds: 8);

  Timer? _pollTimer;
  bool _auto = true;
  bool _refreshing = false;

  bool _loading = false;
  String? _error;
  DateTime? _lastUpdated;

  String _token = '';
  Map<String, dynamic>? _admin;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _boot() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('adminToken') ?? '';
    if (!mounted) return;
    setState(() => _token = token);
    _syncPolling();
    if (token.trim().isNotEmpty && widget.m.apiBaseUrl.trim().isNotEmpty) {
      await _refresh();
    }
  }

  void _syncPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;

    if (!_auto) return;
    if (_token.trim().isEmpty) return;
    if (widget.m.apiBaseUrl.trim().isEmpty) return;

    _pollTimer = Timer.periodic(_pollEvery, (_) {
      _refresh(silent: true);
    });
  }

  Future<void> _setAuto(bool v) async {
    setState(() => _auto = v);
    _syncPolling();
  }

  Future<void> _setToken(String raw) async {
    final token = raw.trim();
    final prefs = await SharedPreferences.getInstance();
    if (token.isEmpty) {
      await prefs.remove('adminToken');
    } else {
      await prefs.setString('adminToken', token);
    }
    if (!mounted) return;
    setState(() => _token = token);
    _syncPolling();
    await _refresh();
  }

  Future<void> _editToken() async {
    final ctrl = TextEditingController(text: _token);
    try {
      final next = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Try12Colors.panel,
          title: const Text('ADMIN TOKEN', style: TextStyle(fontFamily: 'RobotoMono', color: Try12Colors.text)),
          content: TextField(
            controller: ctrl,
            style: const TextStyle(fontFamily: 'RobotoMono', fontSize: 12, color: Try12Colors.text),
            decoration: const InputDecoration(
              hintText: '(paste token)',
              hintStyle: TextStyle(fontFamily: 'RobotoMono', fontSize: 12, color: Try12Colors.dim),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('cancel'),
              child: const Text('CANCEL', style: TextStyle(fontFamily: 'RobotoMono')),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('clear'),
              child: const Text('CLEAR', style: TextStyle(fontFamily: 'RobotoMono', color: Try12Colors.red)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('save'),
              child: const Text('SAVE', style: TextStyle(fontFamily: 'RobotoMono', color: Try12Colors.highlight)),
            ),
          ],
        ),
      );
      if (next == 'save') {
        await _setToken(ctrl.text);
      } else if (next == 'clear') {
        await _setToken('');
      }
    } finally {
      ctrl.dispose();
    }
  }

  Future<void> _refresh({bool silent = false}) async {
    if (_refreshing) return;
    final base = widget.m.apiBaseUrl.trim();
    final token = _token.trim();

    if (base.isEmpty) {
      setState(() => _error = 'Backend URL not set.');
      return;
    }
    if (token.isEmpty) {
      setState(() => _error = 'Admin token not set.');
      return;
    }

    _refreshing = true;
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final url = Uri.parse('$base/api/admin/state');
      final r = await http
          .get(
            url,
            headers: {
              'Cache-Control': 'no-store',
              'X-Admin-Token': token,
            },
          )
          .timeout(_httpTimeout);

      final decoded = r.body.isEmpty ? null : jsonDecode(r.body);
      if (r.statusCode < 200 || r.statusCode >= 300) {
        if (decoded is Map && decoded['note'] != null) {
          throw Exception(decoded['note']);
        }
        throw Exception('HTTP ${r.statusCode}');
      }
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Bad response');
      }
      if (decoded['ok'] != true) {
        throw Exception(decoded['note'] ?? 'Request failed');
      }

      if (!mounted) return;
      setState(() {
        _admin = decoded;
        _lastUpdated = DateTime.now();
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      _refreshing = false;
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  Future<void> _deleteApp({required String appId, required bool force}) async {
    final base = widget.m.apiBaseUrl.trim();
    final token = _token.trim();

    if (base.isEmpty) {
      setState(() => _error = 'Backend URL not set.');
      return;
    }
    if (token.isEmpty) {
      setState(() => _error = 'Admin token not set.');
      return;
    }

    try {
      final url = Uri.parse('$base/api/admin/apps/${Uri.encodeComponent(appId)}${force ? '?force=1' : ''}');
      final r = await http
          .delete(
            url,
            headers: {
              'Cache-Control': 'no-store',
              'X-Admin-Token': token,
            },
          )
          .timeout(_httpTimeout);

      final decoded = r.body.isEmpty ? null : jsonDecode(r.body);
      if (r.statusCode < 200 || r.statusCode >= 300) {
        if (decoded is Map && decoded['note'] != null) {
          throw Exception(decoded['note']);
        }
        throw Exception('HTTP ${r.statusCode}');
      }
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Bad response');
      }
      if (decoded['ok'] != true) {
        throw Exception(decoded['note'] ?? 'Request failed');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('REMOVED $appId', style: const TextStyle(fontFamily: 'RobotoMono')),
          duration: const Duration(milliseconds: 1100),
          backgroundColor: Try12Colors.board,
        ),
      );
      await _refresh(silent: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _confirmDelete({
    required String appId,
    required String status,
    String? userId,
    String? appName,
  }) async {
    final force = status == 'in_session';
    final title = force ? 'FORCE REMOVE?' : 'REMOVE?';
    final detail = [
      if (appName != null && appName.trim().isNotEmpty) appName.trim(),
      'APP: $appId',
      if (userId != null && userId.trim().isNotEmpty) 'USER: ${userId.trim()}',
      'STATUS: $status',
      if (force) 'This will also remove the app from its active session.',
    ].join('\n');

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Try12Colors.panel,
        title: Text(title, style: const TextStyle(fontFamily: 'RobotoMono', color: Try12Colors.text)),
        content: Text(detail, style: const TextStyle(fontFamily: 'RobotoMono', fontSize: 12, color: Try12Colors.dim, height: 1.35)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL', style: TextStyle(fontFamily: 'RobotoMono')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(force ? 'FORCE REMOVE' : 'REMOVE', style: const TextStyle(fontFamily: 'RobotoMono', color: Try12Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _deleteApp(appId: appId, force: force);
    }
  }

  static String _maskToken(String token) {
    final t = token.trim();
    if (t.isEmpty) return '(not set)';
    if (t.length <= 8) return t;
    return '${t.substring(0, 3)}…${t.substring(t.length - 3)}';
  }

  static String _fmtMs(Object? ms) {
    final n = ms is num ? ms.toInt() : null;
    if (n == null || n <= 0) return '—';
    final dt = DateTime.fromMillisecondsSinceEpoch(n);
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} $hh:$mm';
  }

  Widget _panel({required String title, required Widget child}) {
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
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: Try12Gradients.sheen(0.16, intensity: 0.04),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(fontFamily: 'RobotoMono', fontSize: 10, color: Try12Colors.dim, letterSpacing: 0.8),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final admin = _admin;
    final queue = (admin?['queue'] is List) ? (admin!['queue'] as List) : const [];
    final sessions = (admin?['sessions'] is List) ? (admin!['sessions'] as List) : const [];
    final appsById = (admin?['apps_by_id'] is Map) ? (admin!['apps_by_id'] as Map) : const {};
    final userStats = (admin?['user_stats'] is Map) ? (admin!['user_stats'] as Map) : const {};
    final testLog = (admin?['test_log'] is List) ? (admin!['test_log'] as List) : const [];

    final waiting = queue.where((e) => e is Map && e['status'] == 'waiting').length;
    final inSession = queue.where((e) => e is Map && e['status'] == 'in_session').length;
    final stale = queue.where((e) => e is Map && e['stale'] == true).length;
    final activeSessions = sessions.where((e) => e is Map && e['status'] == 'active').length;

    final nowMs = admin?['now_ms'] is num ? (admin?['now_ms'] as num).toInt() : null;

    return Stack(
      children: [
        const Try12Background(),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('CONTROL ROOM', style: TextStyle(fontFamily: 'RobotoMono')),
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            leading: IconButton(
              onPressed: widget.m.backToTerminal,
              icon: const Icon(Icons.arrow_back),
            ),
            actions: [
              IconButton(
                tooltip: 'Admin token',
                onPressed: _editToken,
                icon: const Icon(Icons.key),
              ),
              IconButton(
                tooltip: _auto ? 'Auto refresh: ON' : 'Auto refresh: OFF',
                onPressed: () => _setAuto(!_auto),
                icon: Icon(_auto ? Icons.pause_circle_outline : Icons.play_circle_outline),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _panel(
                    title: 'STATUS',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          widget.m.apiBaseUrl.trim().isEmpty ? '(backend not set)' : widget.m.apiBaseUrl,
                          style: const TextStyle(fontFamily: 'RobotoMono', fontSize: 11, color: Try12Colors.text, height: 1.35),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            _Chip(label: 'TOKEN', value: _maskToken(_token)),
                            _Chip(label: 'AUTO', value: _auto ? 'ON' : 'OFF'),
                            _Chip(label: 'UPDATED', value: _lastUpdated == null ? '—' : '${_lastUpdated!.hour.toString().padLeft(2, '0')}:${_lastUpdated!.minute.toString().padLeft(2, '0')}'),
                          ],
                        ),
                        if (_loading) ...[
                          const SizedBox(height: 10),
                          const LinearProgressIndicator(minHeight: 2),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            _error!,
                            style: const TextStyle(fontFamily: 'RobotoMono', fontSize: 11, color: Try12Colors.red, height: 1.35),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _panel(
                    title: 'SUMMARY',
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        _Chip(label: 'APPS', value: '${appsById.length}'),
                        _Chip(label: 'QUEUE', value: '${queue.length}'),
                        _Chip(label: 'WAITING', value: '$waiting'),
                        _Chip(label: 'IN SESSION', value: '$inSession'),
                        _Chip(label: 'STALE', value: '$stale'),
                        _Chip(label: 'SESSIONS', value: '$activeSessions'),
                        _Chip(label: 'TEST LOG', value: '${testLog.length}'),
                        _Chip(label: 'USER STATS', value: '${userStats.length}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _panel(
                    title: 'ACTIVE SESSIONS',
                    child: sessions.isEmpty
                        ? const Text(
                            '(none)',
                            style: TextStyle(fontFamily: 'RobotoMono', fontSize: 11, color: Try12Colors.dim, height: 1.35),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final s in sessions.whereType<Map>())
                                if (s['status'] == 'active') ...[
                                  _SessionRow(session: s, nowMs: nowMs),
                                  const SizedBox(height: 10),
                                ],
                            ],
                          ),
                  ),
                  const SizedBox(height: 12),
                  _panel(
                    title: 'QUEUE (TOP 40)',
                    child: queue.isEmpty
                        ? const Text(
                            '(empty)',
                            style: TextStyle(fontFamily: 'RobotoMono', fontSize: 11, color: Try12Colors.dim, height: 1.35),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final q in queue.take(40).whereType<Map>())
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _QueueRow(
                                    entry: q,
                                    meta: (appsById[(q['app_id'] ?? '').toString()] is Map)
                                        ? (appsById[(q['app_id'] ?? '').toString()] as Map)
                                        : null,
                                    onDelete: () {
                                      final appId = (q['app_id'] ?? '').toString();
                                      final status = (q['status'] ?? '').toString();
                                      if (appId.trim().isEmpty || status.trim().isEmpty) return;
                                      _confirmDelete(
                                        appId: appId,
                                        status: status,
                                        userId: (q['user_id'] ?? '').toString(),
                                        appName: ((appsById[appId] is Map) ? (appsById[appId] as Map)['app_name'] : null)?.toString(),
                                      );
                                    },
                                  ),
                                ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 12),
                  _panel(
                    title: 'RAW JSON (READ-ONLY)',
                    child: admin == null
                        ? const Text(
                            '(no data yet)',
                            style: TextStyle(fontFamily: 'RobotoMono', fontSize: 11, color: Try12Colors.dim, height: 1.35),
                          )
                        : SelectableText(
                            const JsonEncoder.withIndent('  ').convert(admin),
                            style: const TextStyle(fontFamily: 'RobotoMono', fontSize: 10, color: Try12Colors.text, height: 1.35),
                          ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'NOW: ${nowMs == null ? '—' : _fmtMs(nowMs)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: 'RobotoMono', fontSize: 10, color: Try12Colors.dim, letterSpacing: 0.8),
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

class _SessionRow extends StatelessWidget {
  final Map session;
  final int? nowMs;
  const _SessionRow({required this.session, required this.nowMs});

  static String _fmtDurationMs(int ms) {
    final d = Duration(milliseconds: ms);
    final days = d.inDays;
    final hours = d.inHours.remainder(24);
    final minutes = d.inMinutes.remainder(60);
    if (days > 0) return '${days}d ${hours}h';
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final id = (session['session_id'] ?? '—').toString();
    final start = session['start_time'];
    final end = session['end_time'];
    final appIds = session['app_ids'] is List ? (session['app_ids'] as List) : const [];
    final now = nowMs;
    final endMs = end is num ? end.toInt() : null;

    final remaining = (now != null && endMs != null) ? (endMs - now) : null;
    final remainingText = remaining == null ? '—' : (remaining <= 0 ? 'COMPLETE' : _fmtDurationMs(remaining));

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Try12Colors.board.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Try12Colors.border.withValues(alpha: 0.65)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            id,
            style: const TextStyle(fontFamily: 'RobotoMono', fontSize: 11, color: Try12Colors.text, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'APPS: ${appIds.length} • REMAINING: $remainingText',
            style: const TextStyle(fontFamily: 'RobotoMono', fontSize: 10, color: Try12Colors.dim, height: 1.35),
          ),
          const SizedBox(height: 4),
          Text(
            'START: ${_ControlRoomScreenState._fmtMs(start)} • END: ${_ControlRoomScreenState._fmtMs(end)}',
            style: const TextStyle(fontFamily: 'RobotoMono', fontSize: 10, color: Try12Colors.dim, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _QueueRow extends StatelessWidget {
  final Map entry;
  final Map? meta;
  final VoidCallback? onDelete;
  const _QueueRow({required this.entry, this.meta, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final appId = (entry['app_id'] ?? '—').toString();
    final userId = (entry['user_id'] ?? '—').toString();
    final status = (entry['status'] ?? '—').toString();
    final eligible = entry['eligible'] == true;
    final stale = entry['stale'] == true;
    final testsDone = entry['tests_done'] is num ? (entry['tests_done'] as num).toInt() : null;
    final testsReq = entry['tests_required'] is num ? (entry['tests_required'] as num).toInt() : null;
    final hb = entry['last_heartbeat_ms'];
    final appName = (meta?['app_name'] ?? '').toString().trim();

    final badgeColor = status == 'in_session'
        ? Try12Colors.highlight
        : (status == 'waiting' ? Try12Colors.dim : Try12Colors.border);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Try12Colors.board.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Try12Colors.border.withValues(alpha: 0.65)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  appName.isEmpty ? '$appId • $userId' : '$appId • $appName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'RobotoMono', fontSize: 11, color: Try12Colors.text, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.65)),
                  color: badgeColor.withValues(alpha: 0.12),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(fontFamily: 'RobotoMono', fontSize: 9, color: badgeColor, letterSpacing: 0.6),
                ),
              ),
              if (onDelete != null) ...[
                const SizedBox(width: 6),
                IconButton(
                  tooltip: status == 'in_session' ? 'Force remove' : 'Remove',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_forever, color: Try12Colors.red, size: 18),
                ),
              ],
            ],
          ),
          if (appName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              userId,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'RobotoMono', fontSize: 10, color: Try12Colors.dim, height: 1.25),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'HB: ${_ControlRoomScreenState._fmtMs(hb)} • ELIGIBLE: ${eligible ? 'YES' : 'NO'} • STALE: ${stale ? 'YES' : 'NO'} • TESTS: ${testsDone ?? '—'}/${testsReq ?? '—'}',
            style: const TextStyle(fontFamily: 'RobotoMono', fontSize: 10, color: Try12Colors.dim, height: 1.35),
          ),
        ],
      ),
    );
  }
}
