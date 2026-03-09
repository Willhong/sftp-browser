import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../models/remote_entry.dart';
import '../models/server_profile.dart';
import '../services/sftp_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';
import '../widgets/app_stat_chip.dart';
import '../widgets/breadcrumb_bar.dart';
import '../widgets/file_entry_tile.dart';
import '../widgets/section_card.dart';
import '../widgets/state_panel.dart';

class FileBrowserScreen extends StatefulWidget {
  const FileBrowserScreen({
    super.key,
    required this.profile,
  });

  final ServerProfile profile;

  @override
  State<FileBrowserScreen> createState() => _FileBrowserScreenState();
}

class _FileBrowserScreenState extends State<FileBrowserScreen> {
  final SftpRepository _repository = SftpRepository();

  SftpSession? _session;
  List<RemoteEntry> _entries = const [];
  String? _homePath;
  String? _currentPath;
  bool _isLoading = true;
  bool _isPerformingAction = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void dispose() {
    _session?.close();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final session = await _repository.connect(widget.profile);
      final homePath = session.homeDirectory;
      if (!mounted) {
        await session.close();
        return;
      }

      await _session?.close();
      _session = session;
      _homePath = homePath;
      await _loadDirectory(homePath, showLoading: true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = _formatError(error);
      });
    }
  }

  Future<void> _loadDirectory(String path, {bool showLoading = false}) async {
    final session = _session;
    if (session == null) {
      return;
    }

    if (showLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final entries = await session.listDirectory(path);
      if (!mounted) {
        return;
      }

      setState(() {
        _entries = entries;
        _currentPath = path;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = _formatError(error);
      });
    }
  }

  Future<void> _uploadFile() async {
    final session = _session;
    final currentPath = _currentPath;
    if (session == null || currentPath == null) {
      return;
    }

    final result = await FilePicker.platform.pickFiles();
    final localPath = result?.files.single.path;
    if (localPath == null || localPath.isEmpty) {
      return;
    }

    final bytes = await File(localPath).readAsBytes();
    final remotePath = SftpSession.normalizeRemotePath(currentPath, p.basename(localPath));

    await _runAction(
      () => session.uploadFile(data: bytes, remotePath: remotePath),
      successMessage: 'Uploaded ${p.basename(localPath)}.',
      refreshAfter: true,
    );
  }

  Future<void> _downloadEntry(RemoteEntry entry) async {
    final session = _session;
    if (session == null) {
      return;
    }

    final destinationDirectory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose a download folder',
    );
    if (destinationDirectory == null || destinationDirectory.isEmpty) {
      return;
    }

    await _runAction(
      () async {
        final bytes = await session.downloadFile(entry);
        final destPath = p.join(destinationDirectory, entry.name);
        await File(destPath).writeAsBytes(bytes);
        return null;
      },
      successMessage: 'Downloaded ${entry.name}.',
    );
  }

  Future<void> _renameEntry(RemoteEntry entry) async {
    final newName = await _showRenameDialog(entry);
    if (newName == null || newName == entry.name) {
      return;
    }

    final session = _session;
    if (session == null) {
      return;
    }

    final parent = p.posix.dirname(entry.fullPath);
    final nextPath = SftpSession.normalizeRemotePath(parent, newName);

    await _runAction(
      () => session.rename(entry.fullPath, nextPath),
      successMessage: 'Renamed to $newName.',
      refreshAfter: true,
    );
  }

  Future<void> _deleteEntry(RemoteEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(entry.isDirectory ? 'Delete folder?' : 'Delete file?'),
          content: Text(
            entry.isDirectory
                ? 'Delete ${entry.name} and everything inside it?'
                : 'Delete ${entry.name} from the remote server?',
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

    if (confirmed != true) {
      return;
    }

    final session = _session;
    if (session == null) {
      return;
    }

    await _runAction(
      () => session.delete(entry),
      successMessage: '${entry.name} deleted.',
      refreshAfter: true,
    );
  }

  Future<void> _handleEntryTap(RemoteEntry entry) async {
    if (entry.isDirectory) {
      await _loadDirectory(entry.fullPath, showLoading: true);
      return;
    }

    await _showEntryActionSheet(entry);
  }

  Future<void> _runAction(
    Future<Object?> Function() action, {
    required String successMessage,
    bool refreshAfter = false,
  }) async {
    if (_isPerformingAction) {
      return;
    }

    setState(() {
      _isPerformingAction = true;
    });

    try {
      await action();
      if (!mounted) {
        return;
      }

      if (refreshAfter) {
        final currentPath = _currentPath;
        if (currentPath != null) {
          await _loadDirectory(currentPath, showLoading: false);
        }
      }

      if (!mounted) {
        return;
      }

      _showSnackBar(successMessage);
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showSnackBar(_formatError(error));
    } finally {
      if (mounted) {
        setState(() {
          _isPerformingAction = false;
        });
      }
    }
  }

  Future<void> _showEntryActionSheet(RemoteEntry entry) async {
    final action = await showModalBottomSheet<_EntryAction>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(entry.name),
                  subtitle: Text(entry.fullPath),
                ),
                if (!entry.isDirectory)
                  ListTile(
                    leading: const Icon(Icons.download_outlined),
                    title: const Text('Download'),
                    onTap: () => Navigator.of(context).pop(_EntryAction.download),
                  ),
                ListTile(
                  leading: const Icon(Icons.drive_file_rename_outline),
                  title: const Text('Rename'),
                  onTap: () => Navigator.of(context).pop(_EntryAction.rename),
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Delete'),
                  onTap: () => Navigator.of(context).pop(_EntryAction.delete),
                ),
              ],
            ),
          ),
        );
      },
    );

    switch (action) {
      case _EntryAction.download:
        await _downloadEntry(entry);
        break;
      case _EntryAction.rename:
        await _renameEntry(entry);
        break;
      case _EntryAction.delete:
        await _deleteEntry(entry);
        break;
      case null:
        break;
    }
  }

  Future<String?> _showRenameDialog(RemoteEntry entry) async {
    final controller = TextEditingController(text: entry.name);
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rename item'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Name',
              ),
              validator: (value) {
                final candidate = value?.trim() ?? '';
                if (candidate.isEmpty) {
                  return 'Enter a name.';
                }
                if (candidate.contains('/')) {
                  return 'Name cannot contain /.';
                }
                return null;
              },
              onFieldSubmitted: (_) {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(context).pop(controller.text.trim());
                }
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(context).pop(controller.text.trim());
                }
              },
              child: const Text('Rename'),
            ),
          ],
        );
      },
    );

    controller.dispose();
    return result;
  }

  List<AppBreadcrumbSegment> _buildBreadcrumbs(String path) {
    final homePath = _homePath;
    if (homePath != null &&
        (path == homePath || (homePath != '/' && path.startsWith('$homePath/')))) {
      final segments = <AppBreadcrumbSegment>[
        AppBreadcrumbSegment(label: 'Home', path: homePath, icon: Icons.home_outlined),
      ];

      var current = homePath;
      final relative =
          path == homePath ? '' : path.substring(homePath.length).replaceFirst(RegExp(r'^/'), '');
      for (final part in relative.split('/').where((part) => part.isNotEmpty)) {
        current = p.posix.join(current, part);
        segments.add(AppBreadcrumbSegment(label: part, path: current));
      }
      return segments;
    }

    if (path == '/') {
      return const [
        AppBreadcrumbSegment(label: 'Root', path: '/', icon: Icons.storage_outlined),
      ];
    }

    if (path.startsWith('/')) {
      final segments = <AppBreadcrumbSegment>[
        const AppBreadcrumbSegment(label: 'Root', path: '/', icon: Icons.storage_outlined),
      ];
      var current = '';
      for (final part in path.split('/').where((part) => part.isNotEmpty)) {
        current = current.isEmpty ? '/$part' : '$current/$part';
        segments.add(AppBreadcrumbSegment(label: part, path: current));
      }
      return segments;
    }

    final segments = <AppBreadcrumbSegment>[
      const AppBreadcrumbSegment(label: '.', path: '.'),
    ];
    var current = '.';
    for (final part in path.split('/').where((part) => part.isNotEmpty && part != '.')) {
      current = current == '.' ? './$part' : '$current/$part';
      segments.add(AppBreadcrumbSegment(label: part, path: current));
    }
    return segments;
  }

  bool get _canNavigateUp {
    final currentPath = _currentPath;
    if (currentPath == null || currentPath == '/' || currentPath == '.') {
      return false;
    }
    return p.posix.dirname(currentPath) != currentPath;
  }

  Future<void> _navigateUp() async {
    final currentPath = _currentPath;
    if (currentPath == null || !_canNavigateUp) {
      return;
    }

    await _loadDirectory(p.posix.dirname(currentPath), showLoading: true);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatError(Object error) {
    final raw = error.toString().replaceFirst('Exception: ', '');
    if (raw.startsWith('ProcessException: ')) {
      return raw.replaceFirst('ProcessException: ', '');
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentPath = _currentPath;

    return AppPageScaffold(
      title: widget.profile.title,
      maxWidth: AppTheme.browserMaxWidth,
      actions: [
        IconButton(
          onPressed: _canNavigateUp && !_isLoading ? _navigateUp : null,
          icon: const Icon(Icons.arrow_upward, size: 18),
          tooltip: 'Up one level',
        ),
        IconButton(
          onPressed: currentPath != null && !_isLoading
              ? () => _loadDirectory(currentPath, showLoading: true)
              : _connect,
          icon: const Icon(Icons.refresh, size: 18),
          tooltip: 'Refresh',
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isPerformingAction || _session == null ? null : _uploadFile,
        icon: const Icon(Icons.upload_file_outlined, size: 18),
        label: const Text('Upload'),
      ),
      child: Column(
        children: [
          _buildHeader(theme, currentPath),
          const SizedBox(height: AppTheme.sectionGap),
          Expanded(
            child: AnimatedSwitcher(
              duration: AppTheme.switcherDuration,
              child: _buildBody(theme),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, String? currentPath) {
    final path = currentPath ?? _homePath ?? '.';
    final stateLabel = _isPerformingAction
        ? 'Working'
        : (_session == null ? 'Connecting' : 'Connected');

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.profile.host,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.profile.username} • port ${widget.profile.port} • ${widget.profile.authLabel}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              AppStatChip(label: 'Path', value: path),
              AppStatChip(label: 'Items', value: '${_entries.length}'),
              AppStatChip(label: 'State', value: stateLabel),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.chromeColor(theme),
              borderRadius: BorderRadius.circular(8),
              border: Border.fromBorderSide(
                AppTheme.outlineSide(theme, lightAlpha: 0.6, darkAlpha: 0.26),
              ),
            ),
            child: BreadcrumbBar(
              segments: _buildBreadcrumbs(path),
              enabled: !_isLoading,
              onTap: (segment) => _loadDirectory(segment.path, showLoading: true),
            ),
          ),
          if (_isPerformingAction) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(minHeight: 2),
          ],
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading && _entries.isEmpty) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.6),
        ),
      );
    }

    if (_errorMessage != null && _entries.isEmpty) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: StatePanel(
            icon: Icons.portable_wifi_off_outlined,
            title: 'Unable to load files',
            message: _errorMessage!,
            action: FilledButton.tonalIcon(
              onPressed: _connect,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Reconnect'),
            ),
            tint: theme.colorScheme.errorContainer.withValues(
              alpha: AppTheme.isDark(theme) ? 0.18 : 0.28,
            ),
            iconBackgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.62),
            iconForegroundColor: theme.colorScheme.onErrorContainer,
          ),
        ),
      );
    }

    if (_entries.isEmpty) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: const StatePanel(
            icon: Icons.folder_off_outlined,
            title: 'This folder is empty',
            message: 'Upload files here or browse to another directory.',
          ),
        ),
      );
    }

    return SizedBox.expand(
      child: SectionCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            _buildPaneHeader(theme, 'Explorer', '${_entries.length} items'),
            Divider(height: 1, color: AppTheme.separatorColor(theme)),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  final currentPath = _currentPath;
                  if (currentPath != null) {
                    await _loadDirectory(currentPath, showLoading: false);
                  }
                },
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: ClampingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: _entries.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    indent: 12,
                    endIndent: 12,
                    color: AppTheme.separatorColor(theme),
                  ),
                  itemBuilder: (context, index) {
                    final entry = _entries[index];
                    return FileEntryTile<_EntryAction>(
                      entry: entry,
                      subtitle: _buildEntrySubtitle(entry),
                      enabled: !_isLoading,
                      onTap: () => _handleEntryTap(entry),
                      onSelected: (action) async {
                        switch (action) {
                          case _EntryAction.download:
                            await _downloadEntry(entry);
                            break;
                          case _EntryAction.rename:
                            await _renameEntry(entry);
                            break;
                          case _EntryAction.delete:
                            await _deleteEntry(entry);
                            break;
                        }
                      },
                      itemBuilder: (context) => <PopupMenuEntry<_EntryAction>>[
                        if (!entry.isDirectory)
                          const PopupMenuItem<_EntryAction>(
                            value: _EntryAction.download,
                            child: Text('Download'),
                          ),
                        const PopupMenuItem<_EntryAction>(
                          value: _EntryAction.rename,
                          child: Text('Rename'),
                        ),
                        const PopupMenuItem<_EntryAction>(
                          value: _EntryAction.delete,
                          child: Text('Delete'),
                        ),
                      ],
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

  String _buildEntrySubtitle(RemoteEntry entry) {
    final parts = <String>[entry.isDirectory ? 'Folder' : _formatBytes(entry.size ?? 0)];
    final modifiedAt = entry.modifiedAt;
    if (modifiedAt != null) {
      parts.add(_formatDateTime(modifiedAt));
    }
    return parts.join(' • ');
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    return '${local.year}-${_twoDigits(local.month)}-${_twoDigits(local.day)} '
        '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
  }

  String _twoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) {
      return '0 B';
    }

    const units = <String>['B', 'KB', 'MB', 'GB', 'TB'];
    var size = bytes.toDouble();
    var unitIndex = 0;
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex += 1;
    }

    final precision = size >= 100 || unitIndex == 0 ? 0 : 1;
    return '${size.toStringAsFixed(precision)} ${units[unitIndex]}';
  }
}

enum _EntryAction {
  download,
  rename,
  delete,
}
