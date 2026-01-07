import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/models.dart';
import 'core/state_machine.dart';
import 'core/theme.dart';
import 'screens/gate_read_first.dart';
import 'screens/app_detail.dart';
import 'screens/terminal_board.dart';
import 'screens/control_room.dart';
import 'screens/cerebrum.dart';

class Try12App extends StatefulWidget {
  const Try12App({super.key});

  @override
  State<Try12App> createState() => _Try12AppState();
}

class _Try12AppState extends State<Try12App> with WidgetsBindingObserver {
  late final Try12Machine m;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    m = Try12Machine();
    _boot();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      m.onAppResumed();
    }
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
            case Try12Route.gateReadFirst:
              return GateReadFirst(m: m);
            case Try12Route.terminalBoard:
              return TerminalBoardScreen(m: m);
            case Try12Route.appDetail:
              return AppDetailScreen(m: m);
            case Try12Route.controlRoom:
              return ControlRoomScreen(m: m);
            case Try12Route.cerebrum:
              return CerebrumScreen(m: m);
          }
        },
      ),
    );
  }
}
