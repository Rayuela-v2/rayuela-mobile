import 'package:flutter/material.dart';
import 'companion_avatar.dart';
import 'companion_bubble.dart';

class WizardCompanionGuide extends StatelessWidget {
  const WizardCompanionGuide({
    super.key,
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CompanionAvatar(size: 56, ringColor: Colors.transparent),
          const SizedBox(width: 12),
          Expanded(
            child: CompanionBubble(
              child: Text(
                text,
                style: const TextStyle(
                  color: Color(0xFF3A2810),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
