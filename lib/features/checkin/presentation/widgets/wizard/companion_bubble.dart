import 'package:flutter/material.dart';

enum BubbleTail { bottomLeft, bottomRight }

class CompanionBubble extends StatelessWidget {
  const CompanionBubble({
    super.key,
    required this.child,
    this.tail = BubbleTail.bottomLeft,
  });

  final Widget child;
  final BubbleTail tail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5EDD6), // creamSurface
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: tail == BubbleTail.bottomRight ? const Radius.circular(20) : Radius.zero,
          bottomRight: tail == BubbleTail.bottomLeft ? const Radius.circular(20) : Radius.zero,
        ),
      ),
      child: child,
    );
  }
}
