import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'theme.dart';

class Try12Machine extends ChangeNotifier {
  Try12Route route = Try12Route.gateReadFirst;

  SharedPreferences? _prefs;

  // Backend
  String apiBaseUrl = '';
  bool apiReady = false;
  String? _manualApiBaseUrl;

  // Identity (server key)
  String? userId;

  // Optional Google identity (preferred user key + display)
  String? googleUserId;
  String? googleEmail;
  String? googleDisplayName;

  // Remote snapshot (raw JSON payload from backend)
  Map<String, dynamic>? _payload;

  // UI list (assignment map order)
  final List<MockApp> assigned = [];
  MockApp? myAppCard;
  String? selectedAppId;

  // Gate scan theatre
  bool scanning = false;
  String scanLine = '> READY';
  bool scanRedMoment = false;

  // Network state
  bool loading = false;
  String? lastError;

  // Polling + heartbeat
  Timer? _pollTimer;
  Timer? _heartbeatTimer;

  // Session start “buzz”
  String? _lastBuzzedSessionId;
  bool buzzPending = false;
  String? buzzMessage;

  // Fairness “salute” (12/12 complete)
  String? _lastSalutedSessionId;
  bool salutePending = false;
  String? saluteMessage;

  Future<void> load(SharedPreferences prefs) async {
    _prefs = prefs;

    final savedRoute = prefs.getString('route');
    if (savedRoute != null) {
      route = Try12Route.values.firstWhere(
        (x) => x.name == savedRoute,
        orElse: () => Try12Route.gateReadFirst,
      );
    }

    apiBaseUrl = prefs.getString('apiBaseUrl') ?? '';
    _manualApiBaseUrl = prefs.getString('manualApiBaseUrl');
    userId = prefs.getString('userId');
    googleUserId = prefs.getString('googleUserId');
    googleEmail = prefs.getString('googleEmail');
    googleDisplayName = prefs.getString('googleDisplayName');
    _lastBuzzedSessionId = prefs.getString('lastBuzzedSessionId');
    _lastSalutedSessionId = prefs.getString('lastSalutedSessionId');

    await _ensureApiBaseUrl();

    if (userId != null && apiBaseUrl.isNotEmpty) {
      await refresh(silent: true);
      if (myAppId != null) _startTimers();
    }

    notifyListeners();
  }

  void _save() {
    final p = _prefs;
    if (p == null) return;
    p.setString('route', route.name);
    p.setString('apiBaseUrl', apiBaseUrl);
    if (_manualApiBaseUrl != null && _manualApiBaseUrl!.trim().isNotEmpty) {
      p.setString('manualApiBaseUrl', _manualApiBaseUrl!.trim());
    } else {
      p.remove('manualApiBaseUrl');
    }
    if (userId != null) {
      p.setString('userId', userId!);
    } else {
      p.remove('userId');
    }

    if (googleUserId != null && googleUserId!.trim().isNotEmpty) {
      p.setString('googleUserId', googleUserId!.trim());
    } else {
      p.remove('googleUserId');
    }
    if (googleEmail != null && googleEmail!.trim().isNotEmpty) {
      p.setString('googleEmail', googleEmail!.trim());
    } else {
      p.remove('googleEmail');
    }
    if (googleDisplayName != null && googleDisplayName!.trim().isNotEmpty) {
      p.setString('googleDisplayName', googleDisplayName!.trim());
    } else {
      p.remove('googleDisplayName');
    }

    if (_lastBuzzedSessionId != null) {
      p.setString('lastBuzzedSessionId', _lastBuzzedSessionId!);
    } else {
      p.remove('lastBuzzedSessionId');
    }

    if (_lastSalutedSessionId != null) {
      p.setString('lastSalutedSessionId', _lastSalutedSessionId!);
    } else {
      p.remove('lastSalutedSessionId');
    }
  }

  Future<void> _ensureApiBaseUrl() async {
    final manual = _manualApiBaseUrl;
    if (manual != null && manual.trim().isNotEmpty) {
      final normalized = _normalizeBaseUrl(manual);
      if (apiBaseUrl != normalized || _manualApiBaseUrl != normalized) {
        apiBaseUrl = normalized;
        _manualApiBaseUrl = normalized;
        _save();
      }
      apiReady = true;
      return;
    }

    const envBase = String.fromEnvironment('TRY12_API_BASE_URL');
    if (envBase.trim().isNotEmpty) {
      final normalized = _normalizeBaseUrl(envBase);
      if (apiBaseUrl != normalized) {
        apiBaseUrl = normalized;
        _save();
      }
      apiReady = true;
      return;
    }

    if (apiBaseUrl.trim().isNotEmpty) {
      apiBaseUrl = _normalizeBaseUrl(apiBaseUrl);
      apiReady = true;
      return;
    }

    final resolved = await _resolveApiBaseUrl();
    apiBaseUrl = resolved;
    apiReady = apiBaseUrl.isNotEmpty;
    _save();
  }

  Future<void> setApiBaseUrl(String raw) async {
    final normalized = _normalizeBaseUrl(raw);
    _manualApiBaseUrl = normalized.isEmpty ? null : normalized;
    apiBaseUrl = normalized;
    apiReady = normalized.isNotEmpty;
    _save();
    notifyListeners();
    await refresh(silent: true);
    notifyListeners();
  }

  bool get hasGoogleIdentity => googleUserId != null && googleUserId!.trim().isNotEmpty;

  String? get userLabel {
    final uid = userId;
    if (uid == null || uid.trim().isEmpty) return null;
    if (googleUserId != null && googleEmail != null && uid == googleUserId) return googleEmail;
    return uid;
  }

  void setGoogleIdentity({
    required String id,
    required String email,
    String? displayName,
  }) {
    googleUserId = id.trim().isEmpty ? null : id.trim();
    googleEmail = email.trim().isEmpty ? null : email.trim();
    googleDisplayName = displayName?.trim().isEmpty == true ? null : displayName?.trim();
    _save();
    notifyListeners();
  }

  void clearGoogleIdentity() {
    googleUserId = null;
    googleEmail = null;
    googleDisplayName = null;
    _save();
    notifyListeners();
  }

  Future<void> useConfigApiBaseUrl() async {
    _manualApiBaseUrl = null;
    apiBaseUrl = '';
    apiReady = false;
    _save();
    await _ensureApiBaseUrl();
    notifyListeners();
    await refresh(silent: true);
    notifyListeners();
  }

  static String _normalizeBaseUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.replaceAll(RegExp(r'/*$'), '');
  }

  Future<String> _resolveApiBaseUrl() async {
    const envBase = String.fromEnvironment('TRY12_API_BASE_URL');
    if (envBase.trim().isNotEmpty) return _normalizeBaseUrl(envBase);

    const configUrl = String.fromEnvironment(
      'TRY12_CONFIG_URL',
      defaultValue: 'https://test-12test.netlify.app/config.json',
    );

    try {
      final r = await http
          .get(Uri.parse(configUrl), headers: const {'Cache-Control': 'no-store'})
          .timeout(const Duration(seconds: 6));
      if (r.statusCode < 200 || r.statusCode >= 300) return '';
      final j = jsonDecode(r.body);
      if (j is! Map) return '';
      final base = (j['api_base_url'] ?? '').toString().trim();
      return _normalizeBaseUrl(base);
    } catch (_) {
      return '';
    }
  }

  int? get queuePosition {
    final v = _payload?['my_queue_position'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return null;
  }

  Map<String, dynamic>? get _myApp {
    final v = _payload?['my_app'];
    return v is Map<String, dynamic> ? v : null;
  }

  String? get myAppId {
    final v = _payload?['my_app_id'];
    return v is String && v.isNotEmpty ? v : null;
  }

  Map<String, dynamic>? get session {
    final v = _payload?['session'];
    return v is Map<String, dynamic> ? v : null;
  }

  Map<String, dynamic> get appsById {
    final v = _payload?['apps_by_id'];
    return v is Map ? v.cast<String, dynamic>() : const <String, dynamic>{};
  }

  String? get sessionStatus {
    final v = session?['status'];
    return v is String && v.isNotEmpty ? v : null;
  }

  bool get inSession => session != null && (session?['status'] == 'active');

  String? get sessionId {
    final v = session?['session_id'];
    return v is String && v.isNotEmpty ? v : null;
  }

  bool get inFormingRoom => sessionStatus == 'forming';

  int? get roomFilled {
    final v = session?['filled'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return null;
  }

  int? get roomNeeded {
    final v = session?['needed'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return null;
  }

  int get targetTotal {
    if (inFormingRoom) return 12;
    final ids = session?['app_ids'];
    if (ids is List) return ids.isNotEmpty ? ids.length - 1 : 12;
    final assignedIds = assignedTargetIds;
    if (assignedIds.isNotEmpty) return assignedIds.length;
    return 12;
  }

  int? get roomTargetFilled {
    if (!inFormingRoom) return null;
    final filled = roomFilled;
    if (filled != null) return filled > 0 ? filled - 1 : 0;
    final ids = session?['app_ids'];
    if (ids is List) return ids.isNotEmpty ? ids.length - 1 : 0;
    return null;
  }

  int? get roomTargetNeeded {
    final filled = roomTargetFilled;
    if (filled == null) return null;
    final needed = targetTotal - filled;
    return needed < 0 ? 0 : needed;
  }

  int? get sessionEndMs {
    final v = session?['end_time'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return null;
  }

  int? get nowMsFromServer {
    final v = _payload?['now_ms'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return null;
  }

  Duration? get sessionRemaining {
    final endMs = sessionEndMs;
    final nowMs = nowMsFromServer;
    if (endMs == null || nowMs == null) return null;
    final diff = endMs - nowMs;
    return diff <= 0 ? Duration.zero : Duration(milliseconds: diff);
  }

  int get testsRequired {
    final v = _myApp?['tests_required'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  int get testsDone {
    final v = _myApp?['tests_done'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  bool get testsComplete {
    if (!inSession) return false;
    final required = testsRequired;
    if (required <= 0) return false;
    return testsDone >= required;
  }

  Set<String> get completedTargetIds {
    final out = <String>{};
    final raw = _myApp?['completed_tests'];
    if (raw is! List) return out;
    for (final e in raw) {
      if (e is Map) {
        final id = e['target_app_id'];
        if (id is String && id.isNotEmpty) out.add(id);
      }
    }
    return out;
  }

  List<String> get assignedTargetIds {
    final raw = _myApp?['assigned_tests'];
    if (raw is List) return raw.whereType<String>().toList();
    return const [];
  }

  Future<void> passGateAndSubmit({
    required String appName,
    required String storeLink,
    required String sudoName,
    required String phoneNum,
    required String email,
    String? bundleId,
    String? userKey,
  }) async {
    lastError = null;
    buzzPending = false;
    buzzMessage = null;

    final uid = (userKey?.trim().isNotEmpty == true) ? userKey!.trim() : phoneNum.trim();
    if (uid.isEmpty) return;

    await _ensureApiBaseUrl();
    if (apiBaseUrl.isEmpty) {
      lastError = 'Backend not configured (missing api_base_url).';
      scanLine = '> ERROR backend not configured';
      scanRedMoment = true;
      notifyListeners();
      return;
    }

    userId = uid;
    _save();

    scanning = true;
    scanRedMoment = false;
    scanLine = '> SUBMITTING…';
    notifyListeners();

    try {
      final body = <String, dynamic>{
        'user_id': uid,
        'app_name': appName.trim(),
        'store_link': storeLink.trim(),
      };
      final bundle = bundleId?.trim() ?? '';
      if (bundle.isNotEmpty) body['bundle_id'] = bundle;

      final payload = await _postJson('/api/submit', body);
      _applyPayload(payload);
      route = Try12Route.terminalBoard;
      _save();
      _startTimers();
    } catch (e) {
      lastError = e.toString();
      scanLine = '> ERROR submit failed';
      scanRedMoment = true;
    } finally {
      scanning = false;
      notifyListeners();
    }
  }

  void _startTimers() {
    _pollTimer?.cancel();
    _heartbeatTimer?.cancel();

    if (userId == null || apiBaseUrl.isEmpty) return;

    _pollTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      refresh(silent: true);
    });

    _heartbeatTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      pulse(silent: true);
    });
  }

  void _stopTimers() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<void> onAppResumed() async {
    await _ensureApiBaseUrl();
    await pulse(silent: true);
    await refresh(silent: true);
  }

  Future<void> refresh({bool silent = false}) async {
    final uid = userId;
    if (uid == null || apiBaseUrl.isEmpty) return;

    if (!silent) {
      loading = true;
      notifyListeners();
    }
    try {
      final payload = await _getJson('/api/user/${Uri.encodeComponent(uid)}');
      _applyPayload(payload);
      if (silent) notifyListeners();
    } catch (e) {
      lastError = e.toString();
      if (silent) notifyListeners();
    } finally {
      if (!silent) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> pulse({bool silent = false}) async {
    final uid = userId;
    if (uid == null || apiBaseUrl.isEmpty) return;
    try {
      final payload = await _postJson('/api/heartbeat', {'user_id': uid});
      _applyPayload(payload);
      notifyListeners();
    } catch (e) {
      lastError = e.toString();
      notifyListeners();
    }
  }

  Future<void> completeTest(String targetAppId) async {
    final uid = userId;
    if (uid == null || apiBaseUrl.isEmpty) return;
    loading = true;
    lastError = null;
    notifyListeners();

    try {
      final payload = await _postJson('/api/test', {
        'user_id': uid,
        'target_app_id': targetAppId,
      });
      _applyPayload(payload);
    } catch (e) {
      lastError = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void openAppDetail(String appId) {
    selectedAppId = appId;
    route = Try12Route.appDetail;
    _save();
    notifyListeners();
  }

  void openControlRoom() {
    route = Try12Route.controlRoom;
    _save();
    notifyListeners();
  }

  void openCerebrum() {
    route = Try12Route.cerebrum;
    _save();
    notifyListeners();
  }

  void backToTerminal() {
    route = Try12Route.terminalBoard;
    _save();
    notifyListeners();
  }

  MockApp get selectedApp {
    final id = selectedAppId;
    if (id != null) {
      final found = getApp(id);
      if (found != null) return found;
    }
    if (myAppCard != null) return myAppCard!;
    return assigned.first;
  }

  MockApp? getApp(String appId) {
    if (myAppCard != null && myAppCard!.id == appId) return myAppCard;
    for (final a in assigned) {
      if (a.id == appId) return a;
    }
    return null;
  }

  bool get selectedIsMine {
    final mine = myAppId;
    final sel = selectedAppId;
    return mine != null && sel != null && mine == sel;
  }

  bool isTargetDone(String appId) => completedTargetIds.contains(appId);

  void resetLocal() {
    _stopTimers();
    userId = null;
    googleUserId = null;
    googleEmail = null;
    googleDisplayName = null;
    _payload = null;
    assigned.clear();
    myAppCard = null;
    selectedAppId = null;
    lastError = null;
    scanning = false;
    buzzPending = false;
    buzzMessage = null;
    route = Try12Route.gateReadFirst;
    _save();
    notifyListeners();
  }

  void _applyPayload(Map<String, dynamic> payload) {
    final wasComplete = _isCompleteFromPayload(_payload);
    _payload = payload;
    _rebuildAssigned();
    _maybeBuzz();
    _maybeSalute(wasComplete, _isCompleteFromPayload(_payload));
  }

  @visibleForTesting
  void applyPayloadForTest(Map<String, dynamic> payload) {
    _applyPayload(payload);
    notifyListeners();
  }

  void _maybeBuzz() {
    if (!inSession) return;

    final sid = sessionId;
    if (sid == null) return;
    if (_lastBuzzedSessionId == sid) return;

    _lastBuzzedSessionId = sid;
    _save();

    buzzPending = true;
    buzzMessage = 'SESSION STARTED • 14 DAYS ACTIVE';
  }

  void clearBuzz() {
    buzzPending = false;
    buzzMessage = null;
    notifyListeners();
  }

  void clearSalute() {
    salutePending = false;
    saluteMessage = null;
    notifyListeners();
  }

  static bool _isCompleteFromPayload(Map<String, dynamic>? payload) {
    if (payload == null) return false;
    final sess = payload['session'];
    if (sess is! Map) return false;
    if (sess['status'] != 'active') return false;
    final my = payload['my_app'];
    if (my is! Map) return false;
    final reqRaw = my['tests_required'];
    final doneRaw = my['tests_done'];
    final req = reqRaw is num ? reqRaw.toInt() : 0;
    final done = doneRaw is num ? doneRaw.toInt() : 0;
    return req > 0 && done >= req;
  }

  void _maybeSalute(bool wasComplete, bool isComplete) {
    if (!inSession) return;
    if (!isComplete) return;
    if (wasComplete) return;

    final sid = sessionId;
    if (sid == null) return;
    if (_lastSalutedSessionId == sid) return;

    _lastSalutedSessionId = sid;
    _save();

    salutePending = true;
    saluteMessage = 'WE SALUTE YOU • FAIR TESTER';
  }

  void _rebuildAssigned() {
    assigned.clear();
    myAppCard = null;

    final myId = myAppId;
    if (myId == null) return;

    final appsByIdAny = _payload?['apps_by_id'];
    final appsById = appsByIdAny is Map ? appsByIdAny.cast<String, dynamic>() : <String, dynamic>{};

    final myMetaAny = appsById[myId];
    final myMeta = myMetaAny is Map ? myMetaAny.cast<String, dynamic>() : const <String, dynamic>{};
    final myName = (myMeta['app_name'] ?? _myApp?['app_name'] ?? myId).toString();
    final myLink = (myMeta['store_link'] ?? _myApp?['store_link'] ?? '').toString();

    final me = MockApp(
      id: myId,
      name: myName.toUpperCase(),
      storeLink: myLink,
      tagline: 'YOUR APP',
      accent: Try12Colors.highlight,
      icon: Icons.star,
    );
    me.installed = testsComplete;
    me.opened = testsComplete;
    myAppCard = me;

    List<String> targetIds = assignedTargetIds;
    if (targetIds.isEmpty) {
      final sessionIdsAny = _payload?['session_app_ids'];
      if (sessionIdsAny is List) {
        targetIds = sessionIdsAny.whereType<String>().where((id) => id != myId).toList();
      }
    }

    final done = completedTargetIds;

    for (final id in targetIds) {
      final metaAny = appsById[id];
      final meta = metaAny is Map ? metaAny.cast<String, dynamic>() : const <String, dynamic>{};
      final name = (meta['app_name'] ?? id).toString();
      final link = (meta['store_link'] ?? '').toString();

      final app = MockApp(
        id: id,
        name: name.toUpperCase(),
        storeLink: link,
        tagline: 'SESSION APP',
        accent: _accentForId(id),
        icon: _iconForId(id),
      );
      final isDone = done.contains(id);
      app.installed = isDone;
      app.opened = isDone;
      assigned.add(app);
    }
  }

  static const _palette = <Color>[
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

  static const _icons = <IconData>[
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

  static int _stableHash(String s) {
    var h = 0;
    for (final c in s.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return h;
  }

  Future<Map<String, dynamic>> _getJson(String path) async {
    final base = apiBaseUrl;
    final url = Uri.parse('$base$path');
    final r = await http.get(url, headers: const {'Cache-Control': 'no-store'}).timeout(const Duration(seconds: 8));
    return _decodeJsonResponse(r);
  }

  Future<Map<String, dynamic>> _postJson(String path, Map<String, dynamic> body) async {
    final base = apiBaseUrl;
    final url = Uri.parse('$base$path');
    final r = await http
        .post(
          url,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));
    return _decodeJsonResponse(r);
  }
}

Map<String, dynamic> _decodeJsonResponse(http.Response r) {
  final body = r.body;
  Map<String, dynamic>? decoded;

  if (body.isNotEmpty) {
    try {
      final any = jsonDecode(body);
      if (any is Map<String, dynamic>) {
        decoded = any;
      } else if (any is Map) {
        decoded = any.cast<String, dynamic>();
      } else {
        final preview = body.length > 160 ? '${body.substring(0, 160)}…' : body;
        throw Exception('Unexpected response shape (preview: $preview)');
      }
    } on FormatException catch (e) {
      final text = body.trim();
      final preview = text.length > 160 ? '${text.substring(0, 160)}…' : text;
      throw Exception('Non-JSON response (${e.message}). Preview: $preview');
    }
  }

  if (r.statusCode < 200 || r.statusCode >= 300) {
    if (decoded != null && decoded['note'] != null) {
      throw Exception(decoded['note']);
    }
    throw Exception('HTTP ${r.statusCode}');
  }

  if (decoded == null) {
    throw Exception('Empty response');
  }

  if (decoded['ok'] != true) {
    throw Exception(decoded['note'] ?? 'Request failed');
  }
  return decoded;
}
