import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/state_machine.dart';
import '../core/theme.dart';

class AdminViewScreen extends StatelessWidget {
  final Try12Machine m;
  const AdminViewScreen({super.key, required this.m});

  @override
  Widget build(BuildContext context) {
    final session = m.session;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ADMIN (READ ONLY)', style: TextStyle(fontFamily: 'RobotoMono')),
        backgroundColor: Try12Colors.bg,
        leading: IconButton(
          onPressed: m.goToQueue,
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          IconButton(
            onPressed: () => m.refreshAdminState(),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Section(
              title: 'SESSION',
              child: session == null
                  ? const Text('—', style: TextStyle(fontFamily: 'RobotoMono', color: Try12Colors.dim))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${session.sessionId} • ${session.status.name.toUpperCase()}',
                          style: const TextStyle(fontFamily: 'RobotoMono', color: Try12Colors.text),
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
                        const SizedBox(height: 10),
                        _AppIdList(appIds: session.appIds, appsById: m.appsById),
                      ],
                    ),
            ),
            const SizedBox(height: 12),
            _Section(
              title: 'QUEUE',
              child: m.queue.isEmpty
                  ? const Text('—', style: TextStyle(fontFamily: 'RobotoMono', color: Try12Colors.dim))
                  : Column(
                      children: [
                        for (final q in m.queue) _QueueRow(m: m, entry: q),
                      ],
                    ),
            ),
            const SizedBox(height: 12),
            _Section(
              title: 'ADMIN LOG',
              child: m.adminLog.isEmpty
                  ? const Text('—', style: TextStyle(fontFamily: 'RobotoMono', color: Try12Colors.dim))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final e in m.adminLog.reversed.take(50))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              '${e.at.toIso8601String()} • ${e.action} • ${e.details}',
                              style: const TextStyle(
                                fontFamily: 'RobotoMono',
                                fontSize: 10,
                                color: Try12Colors.dim,
                                height: 1.3,
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QueueRow extends StatelessWidget {
  final Try12Machine m;
  final Test12QueueEntry entry;

  const _QueueRow({required this.m, required this.entry});

  @override
  Widget build(BuildContext context) {
    final meta = m.appsById[entry.appId];
    final title = meta?.appName ?? entry.appId;
    final subtitle = 'user_id=${entry.userId} • entered_at=${DateTime.fromMillisecondsSinceEpoch(entry.enteredAtMs).toIso8601String()}';

    final canRemove = entry.status == QueueEntryStatus.waiting;
    final removeEnabled = canRemove && (!m.remoteEnabled || m.adminEnabled);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Try12Colors.board,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Try12Colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '$title • ${entry.status.name.toUpperCase()}',
                  style: const TextStyle(fontFamily: 'RobotoMono', fontSize: 11, color: Try12Colors.text),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(fontFamily: 'RobotoMono', fontSize: 10, color: Try12Colors.dim),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: removeEnabled
                ? () async {
                    await m.adminRemoveApp(entry.appId);
                  }
                : null,
            child: const Text('REMOVE', style: TextStyle(fontFamily: 'RobotoMono')),
          ),
        ],
      ),
    );
  }
}

class _AppIdList extends StatelessWidget {
  final List<String> appIds;
  final Map<String, Test12AppMeta> appsById;

  const _AppIdList({required this.appIds, required this.appsById});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'APP IDS',
          style: TextStyle(fontFamily: 'RobotoMono', fontSize: 10, color: Try12Colors.highlight),
        ),
        const SizedBox(height: 6),
        for (final id in appIds)
          Text(
            '${appsById[id]?.appName ?? id} • $id',
            style: const TextStyle(fontFamily: 'RobotoMono', fontSize: 10, color: Try12Colors.dim),
          ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
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
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'RobotoMono',
              fontSize: 10,
              letterSpacing: 0.8,
              color: Try12Colors.highlight,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
