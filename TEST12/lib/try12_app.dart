import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/models.dart';
import 'core/state_machine.dart';
import 'core/theme.dart';
import 'screens/admin_view.dart';
import 'screens/assignment_map.dart';
import 'screens/denied.dart';
import 'screens/gate_read_first.dart';
import 'screens/queue_view.dart';

class Try12App extends StatefulWidget {
  const Try12App({super.key});

  @override
  State<Try12App> createState() => _Try12AppState();
}

class _Try12AppState extends State<Try12App> {
  late final Try12Machine m;

  @override
  void initState() {
    super.initState();
    m = Try12Machine();
    _boot();
  }

  Future<void> _boot() async {
    final prefs = await SharedPreferences.getInstance();
    await m.load(prefs);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: try12Theme,
      home: AnimatedBuilder(
        animation: m,
        builder: (_, __) {
          switch (m.route) {
            case Try12Route.gate:
              return GateReadFirst(m: m);
            case Try12Route.queue:
              return QueueViewScreen(m: m);
            case Try12Route.assignmentMap:
              return AssignmentMapScreen(m: m);
            case Try12Route.admin:
              return AdminViewScreen(m: m);
            case Try12Route.denied:
              return DeniedScreen(m: m);
          }
        },
      ),
    );
  }
}
