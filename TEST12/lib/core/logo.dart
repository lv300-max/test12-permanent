import 'package:flutter/material.dart';

import 'theme.dart';

class Test12Logo extends StatelessWidget {
  final double fontSize;
  final Color color;
  final String? suffix;
  final bool showAsset;
  final String assetPath;

  const Test12Logo({
    super.key,
    this.fontSize = 20,
    this.color = Try12Colors.text,
    this.suffix,
    this.showAsset = true,
    this.assetPath = 'assets/images/test12-official.png',
  });

  Widget _buildSuffix() {
    return suffix != null
        ? Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Text(
              suffix!,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: fontSize * 0.5,
                color: Try12Colors.dim,
                letterSpacing: 0.5,
              ),
            ),
          )
        : const SizedBox.shrink();
  }

  Widget _textLogo() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          'TEST-12',
          style: TextStyle(
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
            fontSize: fontSize,
            color: color,
          ),
        ),
        _buildSuffix(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!showAsset) return _textLogo();
    final imageHeight = fontSize * 2.5;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(
          assetPath,
          height: imageHeight,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _textLogo(),
        ),
        if (suffix != null) ...[
          const SizedBox(width: 8),
          _buildSuffix(),
        ],
      ],
    );
  }
}
