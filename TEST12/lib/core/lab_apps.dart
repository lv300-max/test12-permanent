import 'package:flutter/material.dart';

import 'models.dart';

List<MockApp> buildLabApps() {
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
      id: 'P01',
      name: 'ION VAULT',
      tagline: 'Keys • offline • sealed',
      storeLink: 'https://play.google.com/store/apps/details?id=mock.try12.ion_vault',
      accent: const Color(0xFF7C9CFF),
      icon: Icons.lock,
    ),
    app(
      id: 'P02',
      name: 'NEBULA DOCS',
      tagline: 'Scan • index • export',
      storeLink: 'https://play.google.com/store/apps/details?id=mock.try12.nebula_docs',
      accent: const Color(0xFFFFE27B),
      icon: Icons.description,
    ),
    app(
      id: 'P03',
      name: 'ARC MESSENGER',
      tagline: 'Relay • queue • confirm',
      storeLink: 'https://play.google.com/store/apps/details?id=mock.try12.arc_messenger',
      accent: const Color(0xFF6CE4BA),
      icon: Icons.send,
    ),
    app(
      id: 'P04',
      name: 'SPECTRUM UI',
      tagline: 'Themes • clarity • contrast',
      storeLink: 'https://play.google.com/store/apps/details?id=mock.try12.spectrum_ui',
      accent: const Color(0xFFFF6BD6),
      icon: Icons.palette,
    ),
    app(
      id: 'P05',
      name: 'ORIGIN DASH',
      tagline: 'Metrics • cohorts • pulse',
      storeLink: 'https://play.google.com/store/apps/details?id=mock.try12.origin_dash',
      accent: const Color(0xFF54D2FF),
      icon: Icons.stacked_line_chart,
    ),
    app(
      id: 'P06',
      name: 'DRIFT PLAYER',
      tagline: 'Offline • cached • fast',
      storeLink: 'https://play.google.com/store/apps/details?id=mock.try12.drift_player',
      accent: const Color(0xFFB48CFF),
      icon: Icons.play_circle,
    ),
  ];
}

