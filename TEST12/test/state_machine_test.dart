import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:try12/core/state_machine.dart';

void main() {
  test('Try12Machine normalizes apiBaseUrl from prefs', () async {
    SharedPreferences.setMockInitialValues({
      'apiBaseUrl': 'https://example.com///',
    });
    final prefs = await SharedPreferences.getInstance();

    final m = Try12Machine();
    await m.load(prefs);

    expect(m.apiBaseUrl, 'https://example.com');
    expect(m.apiReady, isTrue);
  });

  test('Try12Machine builds a 12-target assignment map from payload', () async {
    SharedPreferences.setMockInitialValues({
      'apiBaseUrl': 'https://example.com',
    });
    final prefs = await SharedPreferences.getInstance();

    final m = Try12Machine();
    await m.load(prefs);

    final sessionIds = List<String>.generate(13, (i) => 'A${(i + 1).toString().padLeft(4, '0')}');
    final assigned = sessionIds.where((id) => id != 'A0001').toList();

    m.applyPayloadForTest({
      'ok': true,
      'now_ms': 123,
      'user_id': '555-0100',
      'my_app_id': 'A0001',
      'my_queue_position': null,
      'session': {
        'session_id': 'S1-0001',
        'start_time': 0,
        'end_time': 999999,
        'status': 'active',
        'app_ids': sessionIds,
      },
      'session_app_ids': sessionIds,
      'apps_by_id': {
        for (final id in sessionIds)
          id: {
            'app_id': id,
            'user_id': 'u$id',
            'app_name': 'App $id',
            'store_link': 'https://example.com/$id',
          }
      },
      'my_app': {
        'app_id': 'A0001',
        'user_id': 'uA0001',
        'app_name': 'App A0001',
        'store_link': 'https://example.com/A0001',
        'tests_required': 12,
        'tests_done': 2,
        'assigned_tests': assigned,
        'completed_tests': [
          {'target_app_id': 'A0002', 'at': 100},
          {'target_app_id': 'A0003', 'at': 101},
        ],
        'eligible': false,
      },
    });

    expect(m.inSession, isTrue);
    expect(m.assigned.length, 12);
    expect(m.myAppCard?.id, 'A0001');
    expect(m.assigned.any((a) => a.id == 'A0001'), isFalse);
    expect(m.isTargetDone('A0002'), isTrue);
    expect(m.isTargetDone('A0004'), isFalse);
  });
}
