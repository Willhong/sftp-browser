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

    return Scaffold(
      appBar: AppBar(
        title: const Text('SFTP Browser'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : () => _loadProfiles(showLoading: false),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
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
              theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              children: [
                Card(
                  color: theme.colorScheme.surface.withValues(alpha: 0.88),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(
                            Icons.storage_rounded,
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
                                style: theme.textTheme.titleLarge,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_profiles.length} server${_profiles.length == 1 ? '' : 's'} ready to browse.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _buildBodyContent(theme),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBodyContent(ThemeData theme) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_off_outlined,
                    size: 40,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Try reloading the saved profiles.',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.tonalIcon(
                    onPressed: _loadProfiles,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_profiles.isEmpty) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            color: theme.colorScheme.surface.withValues(alpha: 0.9),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      Icons.router_outlined,
                      size: 36,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No saved servers yet',
                    style: theme.textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add an SSH profile to start browsing remote files.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _openServerForm,
                    icon: const Icon(Icons.add),
                    label: const Text('Add server'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadProfiles(showLoading: false),
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 96),
        itemCount: _profiles.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final profile = _profiles[index];
          return Card(
            color: theme.colorScheme.surface.withValues(alpha: 0.9),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 8,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              onTap: () => _openBrowser(profile),
              onLongPress: () => _confirmDelete(profile),
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.cloud_done_outlined,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              title: Text(
                profile.title,
                style: theme.textTheme.titleMedium,
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${profile.host}:${profile.port} • ${profile.authLabel}',
                ),
              ),
              trailing: PopupMenuButton<_ServerMenuAction>(
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
            ),
          );
        },
      ),
    );
  }
}

enum _ServerMenuAction {
  browse,
  edit,
  delete,
}
