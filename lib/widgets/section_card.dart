import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.padding = AppTheme.sectionPadding,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? AppTheme.panelColor(theme),
        borderRadius: BorderRadius.circular(AppTheme.sectionRadius),
        border: Border.fromBorderSide(AppTheme.outlineSide(theme)),
        boxShadow: AppTheme.panelShadow(theme),
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}
