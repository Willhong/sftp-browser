import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppStatChip extends StatelessWidget {
  const AppStatChip({super.key, required this.label, this.value, this.icon});

  final String label;
  final String? value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.mutedSurfaceColor(
          theme,
          lightAlpha: 0.34,
          darkAlpha: 0.22,
        ),
        borderRadius: BorderRadius.circular(AppTheme.chipRadius),
        border: Border.fromBorderSide(
          AppTheme.outlineSide(theme, lightAlpha: 0.48, darkAlpha: 0.24),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (value != null) ...[
            const SizedBox(width: 6),
            Text(
              value!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
