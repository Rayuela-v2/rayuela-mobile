import 'package:flutter/material.dart';

class TaskTypeCard extends StatelessWidget {
  const TaskTypeCard({
    super.key,
    required this.taskType,
    required this.isSelected,
    required this.onTap,
  });

  final String taskType;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isSelected
              ? const BorderSide(color: Color(0xFF1E3A2F), width: 3)
              : const BorderSide(color: Colors.white, width: 3),
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _getIconForTaskType(taskType),
                size: 32,
                color: const Color(0xFF37474F),
              ),
              const SizedBox(height: 12),
              Text(
                taskType,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: const Color(0xFF37474F),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconForTaskType(String type) {
    final t = type.toLowerCase();
    if (t.contains('limpieza') || t.contains('clean')) {
      return Icons.cleaning_services_outlined;
    }
    if (t.contains('reparación') || t.contains('repair')) {
      return Icons.build_outlined;
    }
    if (t.contains('inspección') || t.contains('inspect')) {
      return Icons.search_outlined;
    }
    if (t.contains('entrega') || t.contains('delivery')) {
      return Icons.local_shipping_outlined;
    }
    if (t.contains('jardinería') || t.contains('garden')) {
      return Icons.grass_outlined;
    }
    return Icons.assignment_outlined;
  }
}
