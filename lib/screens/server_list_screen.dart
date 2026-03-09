import 'package:flutter/material.dart';

import '../models/server_profile.dart';
import '../services/server_store.dart';
import 'file_browser_screen.dart';
import 'server_form_screen.dart';

class ServerListScreen extends StatefulWidget {
  const ServerListScreen({super.key});

  @override
  State<ServerListScreen> createState() => _ServerListScreenState();
}

class _ServerListScreenState extends State<ServerListScreen> {
  final ServerStore _serverStore = ServerStore();

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
    final index = updatedProfiles.indexWhere((profile) => profile.id == result.id);
    if (index >= 0) {
      updatedProfiles[index] = result;
    } else {
      updatedProfiles.add(result);
    }

    await _saveProfiles(updatedProfiles);
    if (!mounted) {
      return;
    }

    _showSnackBar(
      index >= 0 ? 'Server updated.' : 'Server saved.',
    );
  }

  Future<void> _confirmDelete(ServerProfile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete server?'),
          content: Text(
            'Remove ${profile.title} from saved connections?',
          ),
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

    final updatedProfiles =
        _profiles.where((item) => item.id != profile.id).toList(growable: false);
    await _saveProfiles(updatedProfiles);
    if (!mounted) {
      return;
    }

    _showSnackBar('Server deleted.');
  }

  Future<void> _openBrowser(ServerProfile profile) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => FileBrowserScreen(profile: profile),
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
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SFTP Browser'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton.filledTonal(
              onPressed: _isLoading ? null : () => _loadProfiles(showLoading: false),
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openServerForm,
        icon: const Icon(Icons.add),
        label: const Text('Add server'),
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.surfaceContainerLowest,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  children: [
                    _buildHeader(theme, isDark),
                    const SizedBox(height: 20),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: _buildBodyContent(theme, isDark),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: isDark ? 0.76 : 0.92),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(
            alpha: isDark ? 0.28 : 0.65,
          ),
        ),
        boxShadow: isDark
            ? const []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: isDark ? 0.7 : 1,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.folder_outlined,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Saved connections',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Open a server in one tap and keep your frequent SSH targets close at hand.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildSummaryChip(
                theme,
                label: 'Servers',
                value: '${_profiles.length}',
              ),
              _buildSummaryChip(
                theme,
                label: 'State',
                value: _profiles.isEmpty ? 'Empty' : 'Ready',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryChip(
    ThemeData theme, {
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyContent(ThemeData theme, bool isDark) {
    if (_isLoading) {
      return Center(
        key: const ValueKey('loading'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading saved servers',
              style: theme.textTheme.bodyMedium?.copyWith(
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
          constraints: const BoxConstraints(maxWidth: 460),
          child: _buildStateCard(
            theme,
            isDark: isDark,
            icon: Icons.cloud_off_outlined,
            title: _errorMessage!,
            message: 'Try reloading the saved profiles.',
            action: FilledButton.tonalIcon(
              onPressed: _loadProfiles,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
            tint: theme.colorScheme.errorContainer.withValues(
              alpha: isDark ? 0.28 : 0.45,
            ),
          ),
        ),
      );
    }

    if (_profiles.isEmpty) {
      return Center(
        key: const ValueKey('empty'),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: _buildStateCard(
            theme,
            isDark: isDark,
            icon: Icons.add_link_rounded,
            title: 'No saved servers yet',
            message: 'Add an SSH profile to start browsing remote files.',
            action: FilledButton.icon(
              onPressed: _openServerForm,
              icon: const Icon(Icons.add),
              label: const Text('Add server'),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      key: const ValueKey('list'),
      onRefresh: () => _loadProfiles(showLoading: false),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.only(bottom: 112),
        itemCount: _profiles.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final profile = _profiles[index];
          return _buildServerCard(theme, isDark, profile);
        },
      ),
    );
  }

  Widget _buildStateCard(
    ThemeData theme, {
    required bool isDark,
    required IconData icon,
    required String title,
    required String message,
    required Widget action,
    Color? tint,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: tint ?? theme.colorScheme.surface.withValues(alpha: isDark ? 0.76 : 0.92),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(
            alpha: isDark ? 0.24 : 0.55,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(
              icon,
              size: 30,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          action,
        ],
      ),
    );
  }

  Widget _buildServerCard(ThemeData theme, bool isDark, ServerProfile profile) {
    return Card(
      color: theme.colorScheme.surface.withValues(alpha: isDark ? 0.74 : 0.95),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: () => _openBrowser(profile),
        onLongPress: () => _confirmDelete(profile),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 8, 18),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: isDark ? 0.7 : 1,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.dns_rounded,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      profile.host,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildMetaChip(
                          theme,
                          icon: Icons.lan_outlined,
                          label: '${profile.port}',
                        ),
                        _buildMetaChip(
                          theme,
                          icon: Icons.key_outlined,
                          label: profile.authLabel,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<_ServerMenuAction>(
                tooltip: 'More actions',
                onSelected: (action) async {
                  switch (action) {
                    case _ServerMenuAction.browse:
                      await _openBrowser(profile);
                      break;
                    case _ServerMenuAction.edit:
                      await _openServerForm(profile);
                      break;
                    case _ServerMenuAction.delete:
                      await _confirmDelete(profile);
                      break;
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem<_ServerMenuAction>(
                    value: _ServerMenuAction.browse,
                    child: ListTile(
                      leading: Icon(Icons.folder_open),
                      title: Text('Browse'),
                    ),
                  ),
                  PopupMenuItem<_ServerMenuAction>(
                    value: _ServerMenuAction.edit,
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Edit'),
                    ),
                  ),
                  PopupMenuItem<_ServerMenuAction>(
                    value: _ServerMenuAction.delete,
                    child: ListTile(
                      leading: Icon(Icons.delete_outline),
                      title: Text('Delete'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaChip(
    ThemeData theme, {
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

enum _ServerMenuAction {
  browse,
  edit,
  delete,
}
