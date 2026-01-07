import 'package:flutter/material.dart';

import 'models.dart';

List<MockApp> buildMockApps() {
  MockApp app({
    required String id,
    required String name,
    required String tagline,
    required String storeLink,
    required Color accent,
    required IconData icon,
  }) {
    return MockApp(
      id: id,
      name: name,
      tagline: tagline,
      storeLink: storeLink,
      accent: accent,
      icon: icon,
    );
  }

  return [
    app(
      id: 'A01',
      name: 'AURORA TIMER',
      tagline: 'Focus sprints • ambient cues',
      storeLink: 'https://play.google.com/store/apps/details?id=mock.try12.aurora_timer',
      accent: const Color(0xFF6CE4BA),
      icon: Icons.timelapse,
    ),
    app(
      id: 'A02',
      name: 'NOVA NOTES',
      tagline: 'Quick capture • offline vault',
      storeLink: 'https://play.google.com/store/apps/details?id=mock.try12.nova_notes',
      accent: const Color(0xFFFEDB7E),
      icon: Icons.note,
    ),
    app(
      id: 'A03',
      name: 'PULSE TRACK',
      tagline: 'Vitals • streaks • trends',
      storeLink: 'https://play.google.com/store/apps/details?id=mock.try12.pulse_track',
      accent: const Color(0xFF7C9CFF),
      icon: Icons.favorite,
    ),
    app(
      id: 'A04',
      name: 'ORBIT MAPS',
      tagline: 'Pins • routes • saved places',
      storeLink: 'https://play.google.com/store/apps/details?id=mock.try12.orbit_maps',
      accent: const Color(0xFFB48CFF),
      icon: Icons.public,
    ),
    app(
      id: 'A05',
      name: 'GLASS WEATHER',
      tagline: 'Forecast • radar • alerts',
      storeLink: 'https://play.google.com/store/apps/details?id=mock.try12.glass_weather',
      accent: const Color(0xFF54D2FF),
      icon: Icons.cloud,
    ),
    app(
      id: 'A06',
      name: 'EMBER WALLET',
      tagline: 'Budgets • categories • export',
      storeLink: 'https://play.google.com/store/apps/details?id=mock.try12.ember_wallet',
      accent: const Color(0xFFFFA24A),
      icon: Icons.account_balance_wallet,
    ),
    app(
      id: 'A07',
      name: 'ECHO MUSIC',
      tagline: 'Playlists • offline mix',
      storeLink: 'https://play.google.com/store/apps/details?id=mock.try12.echo_music',
      accent: const Color(0xFFFF6BD6),
      icon: Icons.graphic_eq,
    ),
    app(
      id: 'A08',
      name: 'SHIFT CALENDAR',
      tagline: 'Events • reminders • sync',
      storeLink: 'https://play.google.com/store/apps/details?id=mock.try12.shift_calendar',
      accent: const Color(0xFF6BFFB1),
      icon: Icons.event,
    ),
    app(
      id: 'A09',
      name: 'LANTERN SCAN',
      tagline: 'Docs • OCR • share',
      storeLink: 'https://play.google.com/store/apps/details?id=mock.try12.lantern_scan',
      accent: const Color(0xFFFFE27B),
      icon: Icons.qr_code_scanner,
    ),
    app(
      id: 'A10',
      name: 'VECTOR CAMERA',
      tagline: 'Filters • HDR • presets',
      storeLink: 'https://play.google.com/store/apps/details?id=mock.try12.vector_camera',
      accent: const Color(0xFF7BFFFD),
      icon: Icons.photo_camera,
    ),
    app(
      id: 'A11',
      name: 'SABLE READER',
      tagline: 'Bookmarks • highlights • night mode',
      storeLink: 'https://play.google.com/store/apps/details?id=mock.try12.sable_reader',
      accent: const Color(0xFF9FB2C7),
      icon: Icons.book,
    ),
    app(
      id: 'A12',
      name: 'QUARTZ MAIL',
      tagline: 'Inbox zero • rules • labels',
      storeLink: 'https://play.google.com/store/apps/details?id=mock.try12.quartz_mail',
      accent: const Color(0xFF7EFF86),
      icon: Icons.email,
    ),
  ];
}
