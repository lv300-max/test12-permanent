import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class Try12Machine extends ChangeNotifier {
  static const _prefsKeyUserId = 't12_user_id';
  static const _prefsKeyMyAppId = 't12_my_app_id';
  static const _prefsKeyDenied = 't12_denied';
  static const _prefsKeyAppsJson = 't12_apps_json';
  static const _prefsKeyQueueJson = 't12_queue_json';
  static const _prefsKeySessionJson = 't12_session_json';
  static const _prefsKeyAdminLogJson = 't12_admin_log_json';
  static const _prefsKeyNextAppSeq = 't12_next_app_seq';
  static const _prefsKeyDownloadedJson = 't12_downloaded_json';
  static const _prefsKeyApiOverride = 't12_api_base_url_override';

  static const Duration sessionLength = Duration(days: 14);

  static const String _apiBaseUrl = String.fromEnvironment(
    'TRY12_API_BASE_URL',
    defaultValue: '',
  );
  static const String _configUrl = String.fromEnvironment(
    'TRY12_CONFIG_URL',
    defaultValue: 'https://test-12test.netlify.app/config.json',
  );
  static const String _adminToken = String.fromEnvironment(
    'TRY12_ADMIN_TOKEN',
    defaultValue: '',
  );
  static const bool _demoAlways = bool.fromEnvironment(
    'TRY12_DEMO_ALWAYS',
    defaultValue: true,
  );
  static const bool _autoSubmitRemote = bool.fromEnvironment(
    'TRY12_AUTO_SUBMIT_REMOTE',
    defaultValue: true,
  );

  Try12Route route = Try12Route.queue;
  bool denied = false;

  String? userId;
  String? myAppId;
  int? _remoteMyQueuePosition;

  final Set<String> downloadedAppIds = {};

  final Map<String, Test12AppMeta> appsById = {};
  final List<Test12QueueEntry> queue = [];
  Test12Session? session;
  final List<AdminLogEntry> adminLog = [];

  SharedPreferences? _prefs;
  Timer? _ticker;
  bool _refreshing = false;
  String _apiBaseUrlOverride = '';

  String get apiBaseUrl {
    final o = _apiBaseUrlOverride.trim();
    if (o.isNotEmpty) return o;
    return _apiBaseUrl.trim();
  }

  bool get remoteEnabled => apiBaseUrl.isNotEmpty;
  bool get adminEnabled => _adminToken.trim().isNotEmpty;

  Future<void> load(SharedPreferences prefs) async {
    _prefs = prefs;

    denied = prefs.getBool(_prefsKeyDenied) ?? false;
    userId = prefs.getString(_prefsKeyUserId);
    myAppId = prefs.getString(_prefsKeyMyAppId);
    _apiBaseUrlOverride = prefs.getString(_prefsKeyApiOverride) ?? '';
    downloadedAppIds
      ..clear()
      ..addAll(_loadDownloaded(prefs));

    await _maybeFetchRemoteConfig();

    if (remoteEnabled) {
      await _ensureRemoteReady();
      _startTicker();
      return;
    }

    if (_demoAlways) {
      seedDemoSession();
      _startTicker();
      return;
    }

    appsById
      ..clear()
      ..addAll(_loadApps(prefs));
    queue
      ..clear()
      ..addAll(_loadQueue(prefs));
    session = _loadSession(prefs);
    adminLog
      ..clear()
      ..addAll(_loadAdminLog(prefs));

    _reconcileState(DateTime.now());
    _startTicker();
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  bool get hasSubmission => myAppId != null && appsById.containsKey(myAppId);

  Test12AppMeta? get myApp => myAppId == null ? null : appsById[myAppId!];

  bool get hasActiveSession => session?.status == SessionStatus.active;

  List<String> get sessionAppIds =>
      hasActiveSession ? List.unmodifiable(session!.appIds) : const [];

  List<String> get assignmentMapAppIds => sessionAppIds;

  int? get myQueuePosition {
    if (remoteEnabled) return _remoteMyQueuePosition;
    final mine = myAppId;
    if (mine == null) return null;
    final waiting = queue.where((q) => q.status == QueueEntryStatus.waiting).toList();
    for (int i = 0; i < waiting.length; i++) {
      if (waiting[i].appId == mine) return i + 1;
    }
    return null;
  }

  Future<void> submitAndVerify({
    required String userIdInput,
    required String appNameInput,
    required String storeLinkInput,
  }) async {
    if (denied) return;

    final normalizedUserId = userIdInput.trim();
    final normalizedAppName = appNameInput.trim();
    final normalizedStoreLink = _normalizeLink(storeLinkInput);

    if (normalizedUserId.isEmpty ||
        normalizedAppName.isEmpty ||
        !_isLinkValid(normalizedStoreLink)) {
      await _deny();
      return;
    }

    if (remoteEnabled) {
      userId = normalizedUserId;
      await _saveIdentityOnly();
      await _submitRemote(
        userId: normalizedUserId,
        appName: normalizedAppName,
        storeLink: normalizedStoreLink,
      );
      return;
    }

    userId = normalizedUserId;
    if (hasSubmission) {
      route = Try12Route.queue;
      _save();
      notifyListeners();
      return;
    }

    final newAppId = _nextAppId();
    myAppId = newAppId;

    appsById[newAppId] = Test12AppMeta(
      appId: newAppId,
      userId: normalizedUserId,
      appName: normalizedAppName,
      storeLink: normalizedStoreLink,
    );
    queue.add(
      Test12QueueEntry(
        appId: newAppId,
        userId: normalizedUserId,
        enteredAtMs: DateTime.now().millisecondsSinceEpoch,
        status: QueueEntryStatus.waiting,
      ),
    );

    _reconcileState(DateTime.now());
    route = Try12Route.queue;
    _save();
    notifyListeners();
  }

  Future<void> refresh() async {
    if (!remoteEnabled) {
      _reconcileState(DateTime.now());
      notifyListeners();
      return;
    }

    await _ensureRemoteReady();
  }

  void goToQueue() {
    if (denied) {
      route = Try12Route.denied;
    } else if (hasSubmission) {
      route = Try12Route.queue;
    } else {
      route = Try12Route.gate;
    }
    notifyListeners();
  }

  bool isDownloaded(String appId) => downloadedAppIds.contains(appId);

  Future<void> setDownloaded(String appId, bool downloaded) async {
    if (downloaded) {
      downloadedAppIds.add(appId);
    } else {
      downloadedAppIds.remove(appId);
    }
    await _saveIdentityOnly();
    notifyListeners();
  }

  void seedDemoSession() {
    if (remoteEnabled) return;
    denied = false;

    final now = DateTime.now();
    final startMs = now.millisecondsSinceEpoch;
    final endMs = now.add(sessionLength).millisecondsSinceEpoch;

    appsById.clear();
    queue.clear();
    adminLog.clear();
    session = null;

    final existingUser = (userId ?? '').trim();
    userId = existingUser.isEmpty ? 'demo' : existingUser;

    myAppId = 'ME';
    appsById[myAppId!] = Test12AppMeta(
      appId: myAppId!,
      userId: userId!,
      appName: 'YOU',
      storeLink: 'try12://mock/ME',
    );
    queue.add(
      Test12QueueEntry(
        appId: myAppId!,
        userId: userId!,
        enteredAtMs: startMs,
        status: QueueEntryStatus.waiting,
      ),
    );

    final demoIds = <String>[];
    for (int i = 1; i <= 12; i++) {
      final id = 'P${i.toString().padLeft(2, '0')}';
      demoIds.add(id);
      appsById[id] = Test12AppMeta(
        appId: id,
        userId: 'demo_user_$i',
        appName: 'APP $i',
        storeLink: 'try12://mock/$id',
      );
      queue.add(
        Test12QueueEntry(
          appId: id,
          userId: 'demo_user_$i',
          enteredAtMs: startMs + i,
          status: QueueEntryStatus.promoted,
        ),
      );
    }

    session = Test12Session(
      sessionId: 'DEMO$startMs',
      startTimeMs: startMs,
      endTimeMs: endMs,
      status: SessionStatus.active,
      appIds: demoIds,
    );

    route = Try12Route.queue;
    _save();
    notifyListeners();
  }

  void goToAssignmentMap() {
    route = Try12Route.assignmentMap;
    notifyListeners();
  }

  void goToAdmin() {
    route = Try12Route.admin;
    notifyListeners();
  }

  Future<void> adminRemoveApp(String appId) async {
    if (remoteEnabled) {
      if (!adminEnabled) return;
      await _removeRemoteApp(appId);
      await refreshAdminState();
      return;
    }

    if (!appsById.containsKey(appId)) return;
    if (session?.status == SessionStatus.active && session!.appIds.contains(appId)) {
      return;
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final idx = queue.indexWhere((q) => q.appId == appId);
    if (idx != -1) {
      queue[idx] = Test12QueueEntry(
        appId: queue[idx].appId,
        userId: queue[idx].userId,
        enteredAtMs: queue[idx].enteredAtMs,
        status: QueueEntryStatus.removed,
      );
    }
    appsById.remove(appId);

    if (myAppId == appId) {
      myAppId = null;
    }

    adminLog.add(
      AdminLogEntry(
        atMs: nowMs,
        action: 'remove_app',
        details: 'app_id=$appId',
      ),
    );

    _reconcileState(DateTime.now());
    _save();
    notifyListeners();
  }

  Future<void> refreshAdminState() async {
    if (!remoteEnabled || !adminEnabled) return;
    final uri = Uri.parse('$apiBaseUrl/api/admin/state');
    final resp = await http.get(uri, headers: {'X-Admin-Token': _adminToken});
    if (resp.statusCode != 200) return;
    final decoded = jsonDecode(resp.body);
    if (decoded is! Map) return;
    final m = decoded.cast<String, dynamic>();

    final appsRaw = m['apps_by_id'];
    if (appsRaw is Map) {
      appsById
        ..clear()
        ..addAll(
          appsRaw.cast<String, dynamic>().map(
                (k, v) => MapEntry(
                  k,
                  Test12AppMeta.fromJson((v as Map).cast<String, dynamic>()),
                ),
              ),
        );
    }

    final queueRaw = m['queue'];
    if (queueRaw is List) {
      queue
        ..clear()
        ..addAll(
          queueRaw
              .whereType<Map>()
              .map((x) => Test12QueueEntry.fromJson(x.cast<String, dynamic>())),
        );
    }

    final sessRaw = m['session'];
    if (sessRaw is Map) {
      session = Test12Session.fromJson(sessRaw.cast<String, dynamic>());
    } else {
      session = null;
    }

    final logRaw = m['admin_log'];
    if (logRaw is List) {
      adminLog
        ..clear()
        ..addAll(
          logRaw
              .whereType<Map>()
              .map((x) => AdminLogEntry.fromJson(x.cast<String, dynamic>())),
        );
    }

    myAppId = myAppId; // unchanged; admin view does not redefine identity.
    route = Try12Route.admin;
    notifyListeners();
  }

  Future<void> _deny() async {
    denied = true;
    route = Try12Route.denied;
    if (!remoteEnabled) _save();
    await _saveIdentityOnly();
    notifyListeners();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 10), (_) {
      if (remoteEnabled) {
        if (_refreshing) return;
        _refreshing = true;
        refresh().whenComplete(() {
          _refreshing = false;
        });
        return;
      }
      _reconcileState(DateTime.now());
    });
  }

  Future<void> _ensureRemoteReady() async {
    if (!remoteEnabled) return;
    if (denied) {
      route = Try12Route.denied;
      notifyListeners();
      return;
    }

    final u = (userId ?? '').trim();
    if (u.isEmpty) {
      userId = _generateUserId();
      await _saveIdentityOnly();
    }

    if (_autoSubmitRemote) {
      await _submitRemote(
        userId: userId!,
        appName: 'DEMO APP',
        storeLink: 'try12://mock/ME',
      );
      return;
    }

    await _fetchRemoteUserState(userId!);
  }

  Future<void> _maybeFetchRemoteConfig() async {
    if (_apiBaseUrl.trim().isNotEmpty) return; // compile-time override wins
    final url = _configUrl.trim();
    if (url.isEmpty) return;

    try {
      final uri = Uri.parse(url);
      final resp = await http.get(uri).timeout(const Duration(seconds: 3));
      if (resp.statusCode != 200) return;
      final decoded = jsonDecode(resp.body);
      if (decoded is! Map) return;
      final m = decoded.cast<String, dynamic>();
      final raw = m['api_base_url'] ?? m['apiBaseUrl'] ?? m['apiBaseURL'];
      final base = raw is String ? raw.trim() : '';
      if (base.isEmpty) {
        _apiBaseUrlOverride = '';
        await _prefs?.remove(_prefsKeyApiOverride);
        return;
      }

      if (_apiBaseUrlOverride != base) {
        _apiBaseUrlOverride = base;
        await _prefs?.setString(_prefsKeyApiOverride, _apiBaseUrlOverride);
      }
    } catch (_) {
      return;
    }
  }

  String _generateUserId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final rand = Random().nextInt(1 << 32);
    final token = (now ^ rand).toRadixString(36).toUpperCase();
    return 'U$token';
  }

  void _reconcileState(DateTime now) {
    var changed = false;

    if (denied) {
      if (route != Try12Route.denied) {
        route = Try12Route.denied;
        changed = true;
      }
      if (changed) notifyListeners();
      return;
    }

    final cur = session;
    if (cur != null && cur.status == SessionStatus.active) {
      if (now.millisecondsSinceEpoch >= cur.endTimeMs) {
        session = Test12Session(
          sessionId: cur.sessionId,
          startTimeMs: cur.startTimeMs,
          endTimeMs: cur.endTimeMs,
          status: SessionStatus.complete,
          appIds: cur.appIds,
        );
        _completeSessionApps(cur.appIds);
        session = null;
        changed = true;
        _save();
      }
    }

    if (session == null) {
      final opened = _tryOpenSession(now);
      if (opened) {
        changed = true;
        _save();
      }
    }

    if (!hasSubmission && route != Try12Route.gate) {
      route = Try12Route.gate;
      changed = true;
    } else if (hasSubmission && route == Try12Route.gate) {
      route = Try12Route.queue;
      changed = true;
    }

    if (changed) notifyListeners();
  }

  bool _tryOpenSession(DateTime now) {
    final waiting = queue.where((q) => q.status == QueueEntryStatus.waiting).toList();
    if (waiting.length < 12) return false;

    waiting.sort((a, b) => a.enteredAtMs.compareTo(b.enteredAtMs));
    final picked = waiting.take(12).map((e) => e.appId).toList(growable: false);

    for (int i = 0; i < queue.length; i++) {
      final q = queue[i];
      if (picked.contains(q.appId) && q.status == QueueEntryStatus.waiting) {
        queue[i] = Test12QueueEntry(
          appId: q.appId,
          userId: q.userId,
          enteredAtMs: q.enteredAtMs,
          status: QueueEntryStatus.promoted,
        );
      }
    }

    final startMs = now.millisecondsSinceEpoch;
    final endMs = now.add(sessionLength).millisecondsSinceEpoch;
    final sessionId = 'S$startMs';
    session = Test12Session(
      sessionId: sessionId,
      startTimeMs: startMs,
      endTimeMs: endMs,
      status: SessionStatus.active,
      appIds: picked,
    );
    return true;
  }

  void _completeSessionApps(List<String> appIds) {
    for (final id in appIds) {
      appsById.remove(id);
      final idx = queue.indexWhere((q) => q.appId == id);
      if (idx != -1) queue.removeAt(idx);
      if (myAppId == id) myAppId = null;
    }
  }

  void _save() {
    final p = _prefs;
    if (p == null) return;

    p.setBool(_prefsKeyDenied, denied);
    if (userId != null) {
      p.setString(_prefsKeyUserId, userId!);
    } else {
      p.remove(_prefsKeyUserId);
    }
    if (myAppId != null) {
      p.setString(_prefsKeyMyAppId, myAppId!);
    } else {
      p.remove(_prefsKeyMyAppId);
    }
    p.setString(_prefsKeyDownloadedJson, jsonEncode(downloadedAppIds.toList()..sort()));

    p.setString(_prefsKeyAppsJson, jsonEncode(appsById.map((k, v) => MapEntry(k, v.toJson()))));
    p.setString(_prefsKeyQueueJson, jsonEncode(queue.map((q) => q.toJson()).toList()));
    if (session == null) {
      p.remove(_prefsKeySessionJson);
    } else {
      p.setString(_prefsKeySessionJson, jsonEncode(session!.toJson()));
    }
    p.setString(_prefsKeyAdminLogJson, jsonEncode(adminLog.map((e) => e.toJson()).toList()));
  }

  Future<void> _saveIdentityOnly() async {
    final p = _prefs;
    if (p == null) return;
    await p.setBool(_prefsKeyDenied, denied);
    if (userId != null) {
      await p.setString(_prefsKeyUserId, userId!);
    } else {
      await p.remove(_prefsKeyUserId);
    }
    if (myAppId != null) {
      await p.setString(_prefsKeyMyAppId, myAppId!);
    } else {
      await p.remove(_prefsKeyMyAppId);
    }
    await p.setString(_prefsKeyDownloadedJson, jsonEncode(downloadedAppIds.toList()..sort()));
  }

  Map<String, Test12AppMeta> _loadApps(SharedPreferences prefs) {
    final raw = prefs.getString(_prefsKeyAppsJson);
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return {};
    return decoded.map((k, v) => MapEntry(k, Test12AppMeta.fromJson((v as Map).cast<String, dynamic>())));
  }

  List<Test12QueueEntry> _loadQueue(SharedPreferences prefs) {
    final raw = prefs.getString(_prefsKeyQueueJson);
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((m) => Test12QueueEntry.fromJson(m.cast<String, dynamic>()))
        .toList();
  }

  Test12Session? _loadSession(SharedPreferences prefs) {
    final raw = prefs.getString(_prefsKeySessionJson);
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    return Test12Session.fromJson(decoded.cast<String, dynamic>());
  }

  Set<String> _loadDownloaded(SharedPreferences prefs) {
    final raw = prefs.getString(_prefsKeyDownloadedJson);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toSet();
      }
    } catch (_) {}
    return {};
  }


  List<AdminLogEntry> _loadAdminLog(SharedPreferences prefs) {
    final raw = prefs.getString(_prefsKeyAdminLogJson);
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((m) => AdminLogEntry.fromJson(m.cast<String, dynamic>()))
        .toList();
  }

  String _nextAppId() {
    final p = _prefs;
    final cur = p?.getInt(_prefsKeyNextAppSeq) ?? 1;
    p?.setInt(_prefsKeyNextAppSeq, cur + 1);
    return 'A${cur.toString().padLeft(4, '0')}';
  }

  Future<void> _submitRemote({
    required String userId,
    required String appName,
    required String storeLink,
  }) async {
    final uri = Uri.parse('$apiBaseUrl/api/submit');
    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId, 'app_name': appName, 'store_link': storeLink}),
    );

    if (resp.statusCode != 200) {
      await _deny();
      return;
    }

    final decoded = jsonDecode(resp.body);
    if (decoded is! Map) return;
    _applyRemoteUserPayload(decoded.cast<String, dynamic>());
    await _saveIdentityOnly();
    notifyListeners();
  }

  Future<void> _fetchRemoteUserState(String userId) async {
    final uri = Uri.parse('$apiBaseUrl/api/user/$userId');
    final resp = await http.get(uri);
    if (resp.statusCode != 200) return;
    final decoded = jsonDecode(resp.body);
    if (decoded is! Map) return;
    _applyRemoteUserPayload(decoded.cast<String, dynamic>());
    await _saveIdentityOnly();
    notifyListeners();
  }

  Future<void> _removeRemoteApp(String appId) async {
    final uri = Uri.parse('$apiBaseUrl/api/admin/apps/$appId');
    await http.delete(uri, headers: {'X-Admin-Token': _adminToken});
  }

  void _applyRemoteUserPayload(Map<String, dynamic> payload) {
    final deniedFlag = payload['denied'];
    if (deniedFlag == true) {
      denied = true;
      route = Try12Route.denied;
      return;
    }

    final u = payload['user_id'];
    if (u is String) userId = u;
    final appId = payload['my_app_id'];
    myAppId = appId is String ? appId : null;

    final pos = payload['my_queue_position'];
    _remoteMyQueuePosition = pos is int ? pos : null;

    final appsRaw = payload['apps_by_id'];
    if (appsRaw is Map) {
      appsById
        ..clear()
        ..addAll(
          appsRaw.cast<String, dynamic>().map(
                (k, v) => MapEntry(
                  k,
                  Test12AppMeta.fromJson((v as Map).cast<String, dynamic>()),
                ),
              ),
        );
    }

    final sessRaw = payload['session'];
    if (sessRaw is Map) {
      session = Test12Session.fromJson(sessRaw.cast<String, dynamic>());
    } else {
      session = null;
    }

    route = hasSubmission ? Try12Route.queue : Try12Route.gate;
  }

  bool _isLinkValid(String url) {
    final uri = Uri.tryParse(url);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  String _normalizeLink(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return '';
    final collapsed = trimmed.replaceAll(RegExp(r'\\s+'), '');
    if (collapsed.startsWith(RegExp(r'https?://'))) {
      return collapsed;
    }
    return 'https://$collapsed';
  }
}
