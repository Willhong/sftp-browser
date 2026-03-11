import 'package:flutter/material.dart';

class AppBreadcrumbSegment {
  const AppBreadcrumbSegment({
    required this.label,
    required this.path,
    this.icon,
  });

  final String label;
  final String path;
  final IconData? icon;
}

class BreadcrumbBar extends StatelessWidget {
  const BreadcrumbBar({
    super.key,
    required this.segments,
    required this.onTap,
    this.enabled = true,
  });

  final List<AppBreadcrumbSegment> segments;
  final ValueChanged<AppBreadcrumbSegment> onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < segments.length; index++) ...[
            if (index != 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 14,
                  color: theme.colorScheme.outline,
                ),
              ),
            TextButton(
              onPressed: enabled ? () => onTap(segments[index]) : null,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 28),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.only(
                  left: index == 0 ? 0 : 4,
                  right: 4,
                  top: 2,
                  bottom: 2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                foregroundColor:
                    index == segments.length - 1
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurfaceVariant,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (segments[index].icon != null) ...[
                    Icon(segments[index].icon, size: 13),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    segments[index].label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight:
                          index == segments.length - 1
                              ? FontWeight.w600
                              : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
