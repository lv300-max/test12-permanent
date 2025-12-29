enum Try12Route {
  gate,
  queue,
  assignmentMap,
  admin,
  denied,
}

enum QueueEntryStatus { waiting, promoted, removed }

enum SessionStatus { active, complete }

class Test12AppMeta {
  final String appId;
  final String userId;
  final String appName;
  final String storeLink;

  const Test12AppMeta({
    required this.appId,
    required this.userId,
    required this.appName,
    required this.storeLink,
  });

  Map<String, dynamic> toJson() => {
        'app_id': appId,
        'user_id': userId,
        'app_name': appName,
        'store_link': storeLink,
      };

  static Test12AppMeta fromJson(Map<String, dynamic> json) {
    return Test12AppMeta(
      appId: json['app_id'] as String,
      userId: json['user_id'] as String,
      appName: json['app_name'] as String,
      storeLink: json['store_link'] as String,
    );
  }
}

class Test12QueueEntry {
  final String appId;
  final String userId;
  final int enteredAtMs;
  final QueueEntryStatus status;

  const Test12QueueEntry({
    required this.appId,
    required this.userId,
    required this.enteredAtMs,
    required this.status,
  });

  Map<String, dynamic> toJson() => {
        'app_id': appId,
        'user_id': userId,
        'entered_at': enteredAtMs,
        'status': status.name,
      };

  static Test12QueueEntry fromJson(Map<String, dynamic> json) {
    return Test12QueueEntry(
      appId: json['app_id'] as String,
      userId: json['user_id'] as String,
      enteredAtMs: json['entered_at'] as int,
      status: QueueEntryStatus.values.firstWhere(
        (x) => x.name == (json['status'] as String),
      ),
    );
  }
}

class Test12Session {
  final String sessionId;
  final int startTimeMs;
  final int endTimeMs;
  final SessionStatus status;
  final List<String> appIds;

  const Test12Session({
    required this.sessionId,
    required this.startTimeMs,
    required this.endTimeMs,
    required this.status,
    required this.appIds,
  });

  DateTime get startTime => DateTime.fromMillisecondsSinceEpoch(startTimeMs);
  DateTime get endTime => DateTime.fromMillisecondsSinceEpoch(endTimeMs);

  Map<String, dynamic> toJson() => {
        'session_id': sessionId,
        'start_time': startTimeMs,
        'end_time': endTimeMs,
        'status': status.name,
        'app_ids': appIds,
      };

  static Test12Session fromJson(Map<String, dynamic> json) {
    return Test12Session(
      sessionId: json['session_id'] as String,
      startTimeMs: json['start_time'] as int,
      endTimeMs: json['end_time'] as int,
      status: SessionStatus.values.firstWhere(
        (x) => x.name == (json['status'] as String),
      ),
      appIds: (json['app_ids'] as List<dynamic>).cast<String>(),
    );
  }
}

class AdminLogEntry {
  final int atMs;
  final String action;
  final String details;

  const AdminLogEntry({
    required this.atMs,
    required this.action,
    required this.details,
  });

  DateTime get at => DateTime.fromMillisecondsSinceEpoch(atMs);

  Map<String, dynamic> toJson() => {
        'at': atMs,
        'action': action,
        'details': details,
      };

  static AdminLogEntry fromJson(Map<String, dynamic> json) {
    return AdminLogEntry(
      atMs: json['at'] as int,
      action: json['action'] as String,
      details: json['details'] as String,
    );
  }
}
