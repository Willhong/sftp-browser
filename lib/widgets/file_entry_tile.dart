import 'package:flutter/material.dart';

import '../models/remote_entry.dart';
import '../theme/app_theme.dart';
import 'app_icon_badge.dart';

class FileEntryTile<T> extends StatelessWidget {
  const FileEntryTile({
    super.key,
    required this.entry,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
    required this.onSelected,
    required this.itemBuilder,
  });

  final RemoteEntry entry;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;
  final ValueChanged<T> onSelected;
  final PopupMenuItemBuilder<T> itemBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Opacity(
      opacity: enabled ? 1 : 0.7,
      child: InkWell(
        key: ValueKey<String>('entry-${entry.fullPath}'),
        onTap: enabled ? onTap : null,
        hoverColor: AppTheme.rowHoverColor(theme),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 54),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 7, 4, 7),
            child: Row(
              children: [
                AppIconBadge(
                  icon:
                      entry.isDirectory
                          ? Icons.folder_outlined
                          : Icons.description_outlined,
                  size: 28,
                  iconSize: 15,
                  backgroundColor:
                      entry.isDirectory
                          ? theme.colorScheme.secondaryContainer.withValues(
                            alpha: 0.42,
                          )
                          : AppTheme.mutedSurfaceColor(
                            theme,
                            lightAlpha: 0.38,
                            darkAlpha: 0.24,
                          ),
                  foregroundColor:
                      entry.isDirectory
                          ? theme.colorScheme.onSecondaryContainer
                          : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<T>(
                  enabled: enabled,
                  onSelected: onSelected,
                  itemBuilder: itemBuilder,
                  icon: const Icon(Icons.more_horiz, size: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
