import 'package:flutter/widgets.dart';

enum Try12Route {
  gateReadFirst,
  terminalBoard,
  appDetail,
  controlRoom,
  cerebrum,
}

class MockApp {
  final String id;
  final String name;
  final String storeLink;
  final String tagline;
  final Color accent;
  final IconData icon;
  bool installed = false;
  bool opened = false;

  MockApp({
    required this.id,
    required this.name,
    required this.storeLink,
    required this.tagline,
    required this.accent,
    required this.icon,
  });
}
