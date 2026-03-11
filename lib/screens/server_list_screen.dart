import 'package:flutter/material.dart';

import '../models/server_profile.dart';
import '../services/server_store.dart';
import '../services/sftp_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';
import '../widgets/app_stat_chip.dart';
import '../widgets/section_card.dart';
import '../widgets/server_list_item.dart';
import '../widgets/state_panel.dart';
import 'server_connection_screen.dart';
import 'server_form_screen.dart';

typedef ConnectionScreenBuilder =
    Widget Function(
      BuildContext context,
      ServerProfile profile,
      SftpRepository repository,
    );

class ServerListScreen extends StatefulWidget {
  const ServerListScreen({
    super.key,
    this.serverStore,
    this.repository,
    this.connectionScreenBuilder,
  });

  final ServerStore? serverStore;
  final SftpRepository? repository;
  final ConnectionScreenBuilder? connectionScreenBuilder;

  @override
  State<ServerListScreen> createState() => _ServerListScreenState();
}

class _ServerListScreenState extends State<ServerListScreen> {
  late final ServerStore _serverStore = widget.serverStore ?? ServerStore();
  late final SftpRepository _repository = widget.repository ?? SftpRepository();

  List<ServerProfile> _profiles = const [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final profiles = await _serverStore.loadProfiles();
      if (!mounted) {
        return;
      }

      setState(() {
        _profiles = profiles;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load saved servers.';
      });
      _showSnackBar(_formatError(error));
    }
  }

  Future<void> _saveProfiles(List<ServerProfile> profiles) async {
    await _serverStore.saveProfiles(profiles);
    if (!mounted) {
      return;
    }

    setState(() {
      _profiles = profiles;
    });
  }

  Future<void> _openServerForm([ServerProfile? initialProfile]) async {
    final result = await Navigator.of(context).push<ServerProfile>(
      MaterialPageRoute<ServerProfile>(
        builder: (_) => ServerFormScreen(initialProfile: initialProfile),
      ),
    );
    if (result == null || !mounted) {
      return;
    }

    final updatedProfiles = [..._profiles];
    final index = updatedProfiles.indexWhere(
      (profile) => profile.id == result.id,
    );
    if (index >= 0) {
      updatedProfiles[index] = result;
    } else {
      updatedProfiles.add(result);
    }

    await _saveProfiles(updatedProfiles);
    if (!mounted) {
      return;
    }

    _showSnackBar(index >= 0 ? 'Server updated.' : 'Server saved.');
  }

  Future<void> _confirmDelete(ServerProfile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete server?'),
          content: Text('Remove ${profile.title} from saved connections?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final updatedProfiles = _profiles
        .where((item) => item.id != profile.id)
        .toList(growable: false);
    await _saveProfiles(updatedProfiles);
    if (!mounted) {
      return;
    }

    _showSnackBar('Server deleted.');
  }

  Future<void> _openBrowser(ServerProfile profile) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder:
            (context) =>
                widget.connectionScreenBuilder?.call(
                  context,
                  profile,
                  _repository,
                ) ??
                ServerConnectionScreen(
                  profile: profile,
                  repository: _repository,
                ),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatError(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppPageScaffold(
      title: 'SFTP Browser',
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: IconButton(
            onPressed:
                _isLoading ? null : () => _loadProfiles(showLoading: false),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            tooltip: 'Refresh',
          ),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openServerForm,
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Add server'),
      ),
      child: Column(
        children: [
          _buildOverview(theme),
          const SizedBox(height: AppTheme.sectionGap),
          Expanded(
            child: AnimatedSwitcher(
              duration: AppTheme.switcherDuration,
              child: _buildBodyContent(theme),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverview(ThemeData theme) {
    final readyCount = _profiles.length;
    final statusLabel = _profiles.isEmpty ? 'No saved servers' : 'Ready';

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Connections',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Saved SSH targets for remote file browsing.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              AppStatChip(label: 'Servers', value: '$readyCount'),
              AppStatChip(label: 'Status', value: statusLabel),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBodyContent(ThemeData theme) {
    if (_isLoading) {
      return Center(
        key: const ValueKey('loading'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.6),
            ),
            const SizedBox(height: 12),
            Text(
              'Loading saved servers',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        key: const ValueKey('error'),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: StatePanel(
            icon: Icons.cloud_off_outlined,
            title: _errorMessage!,
            message: 'Try reloading the saved profiles.',
            action: FilledButton.tonalIcon(
              onPressed: _loadProfiles,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try again'),
            ),
            tint: theme.colorScheme.errorContainer.withValues(
              alpha: AppTheme.isDark(theme) ? 0.18 : 0.28,
            ),
            iconBackgroundColor: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.65),
            iconForegroundColor: theme.colorScheme.onErrorContainer,
          ),
        ),
      );
    }

    if (_profiles.isEmpty) {
      return Center(
        key: const ValueKey('empty'),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: StatePanel(
            icon: Icons.add_link_rounded,
            title: 'No saved servers yet',
            message: 'Add an SSH profile to start browsing remote files.',
            action: FilledButton.icon(
              onPressed: _openServerForm,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add server'),
            ),
          ),
        ),
      );
    }

    return SizedBox.expand(
      key: const ValueKey('list'),
      child: SectionCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            _buildPaneHeader(
              theme,
              'Saved servers',
              '${_profiles.length} total',
            ),
            Divider(height: 1, color: AppTheme.separatorColor(theme)),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _loadProfiles(showLoading: false),
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: ClampingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: _profiles.length,
                  separatorBuilder:
                      (_, _) => Divider(
                        height: 1,
                        indent: 12,
                        endIndent: 12,
                        color: AppTheme.separatorColor(theme),
                      ),
                  itemBuilder: (context, index) {
                    final profile = _profiles[index];
                    return ServerListItem(
                      profile: profile,
                      onOpen: () => _openBrowser(profile),
                      onLongPress: () => _confirmDelete(profile),
                      onSelected: (action) async {
                        switch (action) {
                          case ServerListItemAction.browse:
                            await _openBrowser(profile);
                            break;
                          case ServerListItemAction.edit:
                            await _openServerForm(profile);
                            break;
                          case ServerListItemAction.delete:
                            await _confirmDelete(profile);
                            break;
                        }
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaneHeader(ThemeData theme, String title, String detail) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
          Text(
            detail,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
