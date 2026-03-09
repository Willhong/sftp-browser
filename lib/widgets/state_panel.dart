import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_icon_badge.dart';
import 'section_card.dart';

class StatePanel extends StatelessWidget {
  const StatePanel({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.tint,
    this.iconBackgroundColor,
    this.iconForegroundColor,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  final Color? tint;
  final Color? iconBackgroundColor;
  final Color? iconForegroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SectionCard(
      color: tint,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppIconBadge(
                icon: icon,
                size: 36,
                iconSize: 18,
                backgroundColor: iconBackgroundColor ??
                    AppTheme.mutedSurfaceColor(theme, lightAlpha: 0.6, darkAlpha: 0.4),
                foregroundColor: iconForegroundColor ?? theme.colorScheme.onSurface,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (action != null) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: action!,
            ),
          ],
        ],
      ),
    );
  }
}
