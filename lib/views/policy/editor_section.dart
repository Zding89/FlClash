import 'package:flutter/material.dart';

class PolicyEditorSection extends StatelessWidget {
  const PolicyEditorSection({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.step,
  });
  final String title;
  final Widget child;
  final IconData? icon;
  final int? step;

  @override
  Widget build(BuildContext context) => Card.filled(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (step != null)
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  child: Text('$step'),
                )
              else if (icon != null)
                Icon(icon),
              if (step != null || icon != null) const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Theme(
            data: Theme.of(context).copyWith(
              inputDecorationTheme: Theme.of(context).inputDecorationTheme
                  .copyWith(
                    isDense: true,
                    filled: true,
                    fillColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerLowest,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
            ),
            child: child,
          ),
        ],
      ),
    ),
  );
}
