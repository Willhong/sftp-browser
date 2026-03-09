import 'package:flutter/material.dart';

import '../models/server_profile.dart';
import '../theme/app_theme.dart';
import 'app_icon_badge.dart';

enum ServerListItemAction {
  browse,
  edit,
  delete,
}

class ServerListItem extends StatelessWidget {
  const ServerListItem({
    super.key,
    required this.profile,
    required this.onOpen,
    required this.onSelected,
    this.onLongPress,
  });

  final ServerProfile profile;
  final VoidCallback onOpen;
  final ValueChanged<ServerListItemAction> onSelected;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onOpen,
      onLongPress: onLongPress,
      hoverColor: AppTheme.rowHoverColor(theme),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Row(
            children: [
              AppIconBadge(
                icon: Icons.dns_outlined,
                size: 30,
                iconSize: 15,
                backgroundColor: AppTheme.mutedSurfaceColor(
                  theme,
                  lightAlpha: 0.38,
                  darkAlpha: 0.24,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.host,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${profile.username} • Port ${profile.port} • ${profile.authLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<ServerListItemAction>(
                tooltip: 'More actions',
                onSelected: onSelected,
                icon: const Icon(Icons.more_horiz, size: 18),
                itemBuilder: (context) => const [
                  PopupMenuItem<ServerListItemAction>(
                    value: ServerListItemAction.browse,
                    child: Text('Browse'),
                  ),
                  PopupMenuItem<ServerListItemAction>(
                    value: ServerListItemAction.edit,
                    child: Text('Edit'),
                  ),
                  PopupMenuItem<ServerListItemAction>(
                    value: ServerListItemAction.delete,
                    child: Text('Delete'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
