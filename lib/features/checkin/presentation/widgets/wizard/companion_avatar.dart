import 'package:flutter/material.dart';

class CompanionAvatar extends StatelessWidget {
  const CompanionAvatar({
    super.key,
    this.size = 48,
    this.ringColor = const Color(0xFF4DBA87),
  });

  final double size;
  final Color ringColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFC97B2E), // amber/fox-ish background
        shape: BoxShape.circle,
        border: Border.all(color: ringColor, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        '🦊',
        style: TextStyle(fontSize: size * 0.6),
      ),
    );
  }
}
