import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../models/remote_entry.dart';
import '../models/server_profile.dart';
import '../services/sftp_repository.dart';

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
            padding: const EdgeInsets.only(bottom: 16),
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

  List<_BreadcrumbSegment> _buildBreadcrumbs(String path) {
    final homePath = _homePath;
    if (homePath != null &&
        (path == homePath ||
            (homePath != '/' && path.startsWith('$homePath/')))) {
      final segments = <_BreadcrumbSegment>[
        _BreadcrumbSegment(label: 'Home', path: homePath),
      ];

      var current = homePath;
      final relative = path == homePath
          ? ''
          : path.substring(homePath.length).replaceFirst(RegExp(r'^/'), '');
      for (final part in relative.split('/').where((part) => part.isNotEmpty)) {
        current = p.posix.join(current, part);
        segments.add(_BreadcrumbSegment(label: part, path: current));
      }
      return segments;
    }

    if (path == '/') {
      return const [_BreadcrumbSegment(label: 'Root', path: '/')];
    }

    if (path.startsWith('/')) {
      final segments = <_BreadcrumbSegment>[
        const _BreadcrumbSegment(label: 'Root', path: '/'),
      ];
      var current = '';
      for (final part in path.split('/').where((part) => part.isNotEmpty)) {
        current = current.isEmpty ? '/$part' : '$current/$part';
        segments.add(_BreadcrumbSegment(label: part, path: current));
      }
      return segments;
    }

    final segments = <_BreadcrumbSegment>[
      const _BreadcrumbSegment(label: '.', path: '.'),
    ];
    var current = '.';
    for (final part in path.split('/').where((part) => part.isNotEmpty && part != '.')) {
      current = current == '.' ? './$part' : '$current/$part';
      segments.add(_BreadcrumbSegment(label: part, path: current));
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

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.profile.title),
        actions: [
          IconButton(
            onPressed: _canNavigateUp && !_isLoading ? _navigateUp : null,
            icon: const Icon(Icons.arrow_upward),
            tooltip: 'Up one level',
          ),
          IconButton(
            onPressed: currentPath != null && !_isLoading
                ? () => _loadDirectory(currentPath, showLoading: true)
                : _connect,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isPerformingAction || _session == null ? null : _uploadFile,
        icon: const Icon(Icons.upload_file_outlined),
        label: const Text('Upload'),
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.surfaceContainerLowest,
              theme.colorScheme.tertiaryContainer.withValues(alpha: 0.3),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              children: [
                Card(
                  color: theme.colorScheme.surface.withValues(alpha: 0.9),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                Icons.folder_zip_outlined,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.profile.host,
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${widget.profile.username} • port ${widget.profile.port}',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final segment in _buildBreadcrumbs(currentPath ?? _homePath ?? '.'))
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ActionChip(
                                    avatar: segment.label == 'Home'
                                        ? const Icon(Icons.home_outlined, size: 18)
                                        : segment.label == 'Root'
                                            ? const Icon(Icons.storage_outlined, size: 18)
                                            : null,
                                    label: Text(segment.label),
                                    onPressed: _isLoading
                                        ? null
                                        : () => _loadDirectory(segment.path, showLoading: true),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_isPerformingAction) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(),
                ],
                const SizedBox(height: 16),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _buildBody(theme),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading && _entries.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null && _entries.isEmpty) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Card(
            color: theme.colorScheme.errorContainer.withValues(alpha: 0.52),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.portable_wifi_off_outlined,
                    size: 40,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Unable to load files',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.tonalIcon(
                    onPressed: _connect,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reconnect'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        final currentPath = _currentPath;
        if (currentPath != null) {
          await _loadDirectory(currentPath, showLoading: false);
        }
      },
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 96),
        itemCount: _entries.isEmpty ? 1 : _entries.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (_entries.isEmpty) {
            return Card(
              color: theme.colorScheme.surface.withValues(alpha: 0.9),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      Icons.folder_off_outlined,
                      size: 40,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'This folder is empty',
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            );
          }

          final entry = _entries[index];
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
              onTap: _isLoading ? null : () => _handleEntryTap(entry),
              leading: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: entry.isDirectory
                      ? theme.colorScheme.secondaryContainer
                      : theme.colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  entry.isDirectory
                      ? Icons.folder_open_outlined
                      : Icons.description_outlined,
                  color: entry.isDirectory
                      ? theme.colorScheme.onSecondaryContainer
                      : theme.colorScheme.onTertiaryContainer,
                ),
              ),
              title: Text(
                entry.name,
                style: theme.textTheme.titleMedium,
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  entry.isDirectory ? 'Folder' : _formatBytes(entry.size ?? 0),
                ),
              ),
              trailing: PopupMenuButton<_EntryAction>(
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
                itemBuilder: (context) {
                  return <PopupMenuEntry<_EntryAction>>[
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
                  ];
                },
              ),
            ),
          );
        },
      ),
    );
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

class _BreadcrumbSegment {
  const _BreadcrumbSegment({
    required this.label,
    required this.path,
  });

  final String label;
  final String path;
}
