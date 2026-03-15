import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

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
import 'file_editor_screen.dart';
import 'file_preview_screen.dart';
import 'terminal_screen.dart';

class FileBrowserInitialState {
  const FileBrowserInitialState({
    required this.homePath,
    required this.currentPath,
    required this.entries,
  });

  final String homePath;
  final String currentPath;
  final List<RemoteEntry> entries;
}

typedef UploadSourcePicker = Future<LocalUploadSource?> Function();
typedef DownloadDirectoryPicker = Future<String?> Function();

class LocalUploadSource {
  const LocalUploadSource({
    required this.name,
    required this.size,
    required this.openRead,
  });

  factory LocalUploadSource.fromFile(String path) {
    final file = File(path);
    return LocalUploadSource(
      name: p.basename(path),
      size: file.lengthSync(),
      openRead: () => file.openRead().map(Uint8List.fromList),
    );
  }

  final String name;
  final int size;
  final Stream<Uint8List> Function() openRead;
}

class FileBrowserScreen extends StatefulWidget {
  const FileBrowserScreen({
    super.key,
    required this.profile,
    required this.session,
    required this.initialState,
    this.pickUploadSource,
    this.pickDownloadDirectory,
    this.closeSessionOnDispose = true,
  });

  final ServerProfile profile;
  final SftpSession session;
  final FileBrowserInitialState initialState;
  final UploadSourcePicker? pickUploadSource;
  final DownloadDirectoryPicker? pickDownloadDirectory;
  final bool closeSessionOnDispose;

  @override
  State<FileBrowserScreen> createState() => _FileBrowserScreenState();
}

class _FileBrowserScreenState extends State<FileBrowserScreen> {
  late List<RemoteEntry> _entries;
  late String _currentPath;
  RemoteEntrySort _sort = const RemoteEntrySort();
  bool _isLoading = false;
  bool _isPerformingAction = false;
  String? _errorMessage;
  SftpTransferProgress? _transferProgress;
  int _loadRequestId = 0;

  String get _homePath => widget.initialState.homePath;

  @override
  void initState() {
    super.initState();
    _entries = _sort.sortEntries(widget.initialState.entries);
    _currentPath = widget.initialState.currentPath;
  }

  @override
  void dispose() {
    if (widget.closeSessionOnDispose) {
      unawaited(widget.session.close());
    }
    super.dispose();
  }

  Future<void> _loadDirectory(String path, {bool showLoading = false}) async {
    final requestId = ++_loadRequestId;
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final entries = await widget.session.listDirectory(path);
      if (!mounted || requestId != _loadRequestId) {
        return;
      }

      setState(() {
        _entries = _sort.sortEntries(entries);
        _currentPath = path;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted || requestId != _loadRequestId) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = _formatError(error);
      });
    }
  }

  Future<void> _uploadFile() async {
    final currentPath = _currentPath;

    final source = await _pickUploadSource();
    if (source == null) {
      return;
    }

    final remotePath = SftpSession.normalizeRemotePath(
      currentPath,
      source.name,
    );
    await _runTransfer(
      widget.session.uploadFile(
        data: source.openRead(),
        totalBytes: source.size,
        remotePath: remotePath,
        label: source.name,
      ),
      successMessage: 'Uploaded ${source.name}.',
      refreshAfter: true,
    );
  }

  Future<LocalUploadSource?> _pickUploadSource() async {
    if (widget.pickUploadSource != null) {
      return widget.pickUploadSource!();
    }

    final result = await FilePicker.platform.pickFiles();
    final localPath = result?.files.single.path;
    if (localPath == null || localPath.isEmpty) {
      return null;
    }
    return LocalUploadSource.fromFile(localPath);
  }

  Future<void> _downloadEntry(RemoteEntry entry) async {
    final destinationDirectory = await _pickDownloadDirectory();
    if (destinationDirectory == null || destinationDirectory.isEmpty) {
      return;
    }

    final sink = File(p.join(destinationDirectory, entry.name)).openWrite();
    try {
      await _runTransfer(
        widget.session.downloadFile(entry, onChunk: (chunk) => sink.add(chunk)),
        successMessage: 'Downloaded ${entry.name}.',
      );
    } finally {
      await sink.close();
    }
  }

  Future<String?> _pickDownloadDirectory() async {
    if (widget.pickDownloadDirectory != null) {
      return widget.pickDownloadDirectory!();
    }
    return FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose a download folder',
    );
  }

  Future<void> _previewEntry(RemoteEntry entry) async {
    if (entry.isDirectory) {
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder:
            (_) => FilePreviewScreen(entry: entry, session: widget.session),
      ),
    );
  }

  Future<void> _editEntry(RemoteEntry entry) async {
    if (entry.isDirectory) {
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => FileEditorScreen(entry: entry, session: widget.session),
      ),
    );
  }

  Future<void> _openTerminal() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder:
            (_) => TerminalScreen(
              profile: widget.profile,
              session: widget.session,
            ),
      ),
    );
  }

  Future<void> _renameEntry(RemoteEntry entry) async {
    final newName = await _showNameDialog(
      title: 'Rename item',
      label: 'Name',
      submitLabel: 'Rename',
      initialValue: entry.name,
    );
    if (newName == null || newName == entry.name) {
      return;
    }

    final parent = p.posix.dirname(entry.fullPath);
    final nextPath = SftpSession.normalizeRemotePath(parent, newName);
    await _runAction(
      () => widget.session.rename(entry.fullPath, nextPath),
      successMessage: 'Renamed to $newName.',
      refreshAfter: true,
    );
  }

  Future<void> _createFolder() async {
    final currentPath = _currentPath;

    final name = await _showNameDialog(
      title: 'Create folder',
      label: 'Folder name',
      submitLabel: 'Create',
    );
    if (name == null) {
      return;
    }

    await _runAction(
      () => widget.session.createDirectory(currentPath, name),
      successMessage: 'Created $name.',
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

    await _runAction(
      () => widget.session.delete(entry),
      successMessage: '${entry.name} deleted.',
      refreshAfter: true,
    );
  }

  Future<void> _handleEntryTap(RemoteEntry entry) async {
    if (entry.isDirectory) {
      await _loadDirectory(entry.fullPath, showLoading: true);
      return;
    }
    await _previewEntry(entry);
  }

  Future<void> _runAction(
    Future<void> Function() action, {
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
      if (refreshAfter) {
        await _loadDirectory(_currentPath, showLoading: false);
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

  Future<void> _runTransfer(
    Stream<SftpTransferProgress> updates, {
    required String successMessage,
    bool refreshAfter = false,
  }) async {
    if (_isPerformingAction) {
      return;
    }

    setState(() {
      _isPerformingAction = true;
      _transferProgress = null;
    });

    try {
      await for (final update in updates) {
        if (!mounted) {
          continue;
        }
        setState(() {
          _transferProgress = update;
        });
      }
      if (refreshAfter) {
        await _loadDirectory(_currentPath, showLoading: false);
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
          _transferProgress = null;
        });
      }
    }
  }

  Future<String?> _showNameDialog({
    required String title,
    required String label,
    required String submitLabel,
    String initialValue = '',
  }) async {
    final controller = TextEditingController(text: initialValue);
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(labelText: label),
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
              child: Text(submitLabel),
            ),
          ],
        );
      },
    );

    controller.dispose();
    return result;
  }

  List<AppBreadcrumbSegment> _buildBreadcrumbs(String path) {
    if (path == _homePath ||
        (_homePath != '/' && path.startsWith('$_homePath/'))) {
      final segments = <AppBreadcrumbSegment>[
        AppBreadcrumbSegment(
          label: 'Home',
          path: _homePath,
          icon: Icons.home_outlined,
        ),
      ];
      var current = _homePath;
      final relative =
          path == _homePath
              ? ''
              : path
                  .substring(_homePath.length)
                  .replaceFirst(RegExp(r'^/'), '');
      for (final part in relative.split('/').where((part) => part.isNotEmpty)) {
        current = p.posix.join(current, part);
        segments.add(AppBreadcrumbSegment(label: part, path: current));
      }
      return segments;
    }

    if (path == '/') {
      return const [
        AppBreadcrumbSegment(
          label: 'Root',
          path: '/',
          icon: Icons.storage_outlined,
        ),
      ];
    }

    final segments = <AppBreadcrumbSegment>[
      const AppBreadcrumbSegment(
        label: 'Root',
        path: '/',
        icon: Icons.storage_outlined,
      ),
    ];
    var current = '';
    for (final part in path.split('/').where((part) => part.isNotEmpty)) {
      current = current.isEmpty ? '/$part' : '$current/$part';
      segments.add(AppBreadcrumbSegment(label: part, path: current));
    }
    return segments;
  }

  bool get _canNavigateUp {
    final currentPath = _currentPath;
    if (currentPath == '/' || currentPath == '.') {
      return false;
    }
    return p.posix.dirname(currentPath) != currentPath;
  }

  Future<void> _navigateUp() async {
    final currentPath = _currentPath;
    if (!_canNavigateUp) {
      return;
    }
    await _loadDirectory(p.posix.dirname(currentPath), showLoading: true);
  }

  void _selectSortField(RemoteEntrySortField field) {
    if (_sort.field == field) {
      return;
    }

    setState(() {
      _sort = _sort.copyWith(field: field, ascending: field.defaultAscending);
      _entries = _sort.sortEntries(_entries);
    });
  }

  void _toggleSortDirection() {
    setState(() {
      _sort = _sort.copyWith(ascending: !_sort.ascending);
      _entries = _sort.sortEntries(_entries);
    });
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
          onPressed:
              !_isLoading
                  ? () => _loadDirectory(currentPath, showLoading: true)
                  : null,
          icon: const Icon(Icons.refresh, size: 18),
          tooltip: 'Refresh',
        ),
        PopupMenuButton<RemoteEntrySortField>(
          tooltip: 'Sort by',
          onSelected: _selectSortField,
          itemBuilder:
              (context) => <PopupMenuEntry<RemoteEntrySortField>>[
                for (final field in RemoteEntrySortField.values)
                  CheckedPopupMenuItem<RemoteEntrySortField>(
                    value: field,
                    checked: _sort.field == field,
                    child: Text(field.label),
                  ),
              ],
          icon: const Icon(Icons.sort_outlined, size: 18),
        ),
        IconButton(
          onPressed: _entries.length < 2 ? null : _toggleSortDirection,
          icon: Icon(_sort.ascending ? Icons.south : Icons.north, size: 18),
          tooltip:
              _sort.ascending
                  ? 'Show descending order'
                  : 'Show ascending order',
        ),
        IconButton(
          onPressed: _isPerformingAction ? null : _createFolder,
          icon: const Icon(Icons.create_new_folder_outlined, size: 18),
          tooltip: 'Create folder',
        ),
        IconButton(
          onPressed: _openTerminal,
          icon: const Icon(Icons.terminal, size: 18),
          tooltip: 'Open terminal',
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isPerformingAction ? null : _uploadFile,
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

  Widget _buildHeader(ThemeData theme, String currentPath) {
    final path = currentPath;
    final transferProgress = _transferProgress;
    final stateLabel =
        transferProgress != null
            ? 'Transferring'
            : (_isPerformingAction ? 'Working' : 'Connected');

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.profile.host,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
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
              AppStatChip(
                label: 'Sort',
                value: '${_sort.field.label} ${_sort.ascending ? '↑' : '↓'}',
              ),
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
              onTap:
                  (segment) => _loadDirectory(segment.path, showLoading: true),
            ),
          ),
          if (transferProgress != null) ...[
            const SizedBox(height: 10),
            Text(
              transferProgress.type == SftpTransferType.upload
                  ? 'Uploading ${transferProgress.name}'
                  : 'Downloading ${transferProgress.name}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              minHeight: 4,
              value: transferProgress.fraction,
            ),
            const SizedBox(height: 6),
            Text(
              '${_formatBytes(transferProgress.transferredBytes)} of ${_formatBytes(transferProgress.totalBytes)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ] else if (_isPerformingAction) ...[
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
              onPressed: () => _loadDirectory(_currentPath, showLoading: true),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
            tint: theme.colorScheme.errorContainer.withValues(
              alpha: AppTheme.isDark(theme) ? 0.18 : 0.28,
            ),
            iconBackgroundColor: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.62),
            iconForegroundColor: theme.colorScheme.onErrorContainer,
          ),
        ),
      );
    }

    if (_entries.isEmpty) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: StatePanel(
            icon: Icons.folder_off_outlined,
            title: 'This folder is empty',
            message: 'Upload files here or create a folder to get started.',
            action: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _isPerformingAction ? null : _uploadFile,
                  icon: const Icon(Icons.upload_file_outlined, size: 18),
                  label: const Text('Upload'),
                ),
                OutlinedButton.icon(
                  onPressed: _isPerformingAction ? null : _createFolder,
                  icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                  label: const Text('Create folder'),
                ),
              ],
            ),
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
                onRefresh:
                    () => _loadDirectory(_currentPath, showLoading: false),
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: ClampingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: _entries.length,
                  separatorBuilder:
                      (_, _) => Divider(
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
                      enabled: !_isLoading && !_isPerformingAction,
                      onTap: () => _handleEntryTap(entry),
                      onSelected: (action) async {
                        switch (action) {
                          case _EntryAction.preview:
                            await _previewEntry(entry);
                            break;
                          case _EntryAction.edit:
                            await _editEntry(entry);
                            break;
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
                      itemBuilder:
                          (context) => <PopupMenuEntry<_EntryAction>>[
                            if (!entry.isDirectory)
                              const PopupMenuItem<_EntryAction>(
                                value: _EntryAction.preview,
                                child: Text('Preview'),
                              ),
                            if (!entry.isDirectory)
                              const PopupMenuItem<_EntryAction>(
                                value: _EntryAction.edit,
                                child: Text('Edit'),
                              ),
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
    final parts = <String>[
      entry.isDirectory ? 'Folder' : _formatBytes(entry.size ?? 0),
    ];
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

enum _EntryAction { preview, edit, download, rename, delete }
