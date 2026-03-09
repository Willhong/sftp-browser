import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppIconBadge extends StatelessWidget {
  const AppIconBadge({
    super.key,
    required this.icon,
    this.size = 36,
    this.iconSize = 18,
    this.backgroundColor,
    this.foregroundColor,
  });

  final IconData icon;
  final double size;
  final double iconSize;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppTheme.mutedSurfaceColor(theme),
        borderRadius: BorderRadius.circular(AppTheme.iconBadgeRadius),
        border: Border.fromBorderSide(
          AppTheme.outlineSide(theme, lightAlpha: 0.4, darkAlpha: 0.2),
        ),
      ),
      child: Icon(
        icon,
        size: iconSize,
        color: foregroundColor ?? theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
