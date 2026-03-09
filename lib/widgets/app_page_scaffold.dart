import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppPageScaffold extends StatelessWidget {
  const AppPageScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.maxWidth = AppTheme.pageMaxWidth,
    this.padding = AppTheme.pagePadding,
    this.gradientAccent,
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  final Color? gradientAccent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppTheme.chromeColor(theme),
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        actions: actions == null ? null : [...actions!, const SizedBox(width: 4)],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            color: AppTheme.separatorColor(theme),
          ),
        ),
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      body: ColoredBox(
        color: theme.scaffoldBackgroundColor,
        child: SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Padding(
                padding: padding,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
