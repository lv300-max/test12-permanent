import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/state_machine.dart';
import '../core/theme.dart';

class DeniedScreen extends StatelessWidget {
  final Try12Machine m;
  const DeniedScreen({super.key, required this.m});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Try12Colors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'DENIED',
                style: TextStyle(
                  fontFamily: 'RobotoMono',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: Try12Colors.red,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Access denied.\n'
                'Reason: verification failed / identity mismatch / abuse detected.\n'
                'Denied users do not enter the queue.',
                style: TextStyle(
                  fontFamily: 'RobotoMono',
                  fontSize: 11,
                  height: 1.4,
                  color: Try12Colors.dim,
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () => SystemNavigator.pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Try12Colors.red,
                  foregroundColor: Try12Colors.bg,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('EXIT', style: TextStyle(fontFamily: 'RobotoMono')),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => SystemNavigator.pop(),
                child: const Text('CLOSE', style: TextStyle(fontFamily: 'RobotoMono')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

