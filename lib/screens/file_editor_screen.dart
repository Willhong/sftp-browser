import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/remote_entry.dart';
import '../services/sftp_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';
import '../widgets/app_stat_chip.dart';
import '../widgets/section_card.dart';
import '../widgets/state_panel.dart';

class FileEditorScreen extends StatefulWidget {
  const FileEditorScreen({
    super.key,
    required this.entry,
    required this.session,
  });

  final RemoteEntry entry;
  final SftpSession session;

  @override
  State<FileEditorScreen> createState() => _FileEditorScreenState();
}

class _FileEditorScreenState extends State<FileEditorScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;
  String? _errorMessage;
  late TextEditingController _controller;
  String _originalContent = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(_onTextChanged);
    _loadFile();
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final changed = _controller.text != _originalContent;
    if (changed != _hasUnsavedChanges) {
      setState(() => _hasUnsavedChanges = changed);
    }
  }

  Future<void> _loadFile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final preview = await widget.session.loadPreview(widget.entry);
      if (!mounted) return;

      if (preview.type == RemotePreviewType.text) {
        final text = preview.text ?? '';
        _originalContent = text;
        _controller.text = text;
        // Move cursor to beginning
        _controller.selection = const TextSelection.collapsed(offset: 0);
        setState(() {
          _isLoading = false;
          _hasUnsavedChanges = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage =
              preview.message ?? 'This file type cannot be edited as text.';
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _saveFile() async {
    if (_isSaving || !_hasUnsavedChanges) return;

    setState(() => _isSaving = true);

    try {
      final bytes = Uint8List.fromList(utf8.encode(_controller.text));
      await widget.session.writeFile(widget.entry.fullPath, bytes);
      if (!mounted) return;

      _originalContent = _controller.text;
      setState(() {
        _isSaving = false;
        _hasUnsavedChanges = false;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('File saved.')),
        );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Save failed: ${error.toString().replaceFirst('Exception: ', '')}',
            ),
          ),
        );
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved changes'),
        content: const Text('You have unsaved changes. Discard them?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          final shouldPop = await _onWillPop();
          if (shouldPop && context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: AppPageScaffold(
        title: 'Editor',
        maxWidth: AppTheme.browserMaxWidth,
        actions: [
          if (_hasUnsavedChanges)
            IconButton(
              onPressed: _isSaving ? null : _saveFile,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined, size: 18),
              tooltip: 'Save file',
            ),
          IconButton(
            onPressed: _isLoading ? null : _loadFile,
            icon: const Icon(Icons.refresh, size: 18),
            tooltip: 'Reload file',
          ),
        ],
        child: Column(
          children: [
            _buildHeader(theme),
            const SizedBox(height: AppTheme.sectionGap),
            Expanded(
              child: AnimatedSwitcher(
                duration: AppTheme.switcherDuration,
                child: _buildBody(theme),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.entry.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_hasUnsavedChanges)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Modified',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onTertiaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            widget.entry.fullPath,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              AppStatChip(
                label: 'Size',
                value: widget.entry.size == null
                    ? 'Unknown'
                    : _formatBytes(widget.entry.size!),
              ),
              AppStatChip(
                label: 'Lines',
                value: _isLoading
                    ? '—'
                    : '${_controller.text.split('\n').length}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(
        key: ValueKey('editor-loading'),
        child: SizedBox(
          width: 30,
          height: 30,
          child: CircularProgressIndicator(strokeWidth: 2.8),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        key: const ValueKey('editor-error'),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: StatePanel(
            icon: Icons.error_outline,
            title: 'Cannot edit file',
            message: _errorMessage!,
            action: FilledButton.tonalIcon(
              onPressed: _loadFile,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try again'),
            ),
          ),
        ),
      );
    }

    return SectionCard(
      key: const ValueKey('editor-content'),
      padding: EdgeInsets.zero,
      child: TextField(
        controller: _controller,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        style: theme.textTheme.bodySmall?.copyWith(
          fontFamily: 'monospace',
          height: 1.5,
          fontSize: 13,
        ),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.all(12),
          border: InputBorder.none,
          hintText: 'Empty file',
          hintStyle: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            fontFamily: 'monospace',
          ),
        ),
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        autocorrect: false,
        enableSuggestions: false,
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    var size = bytes.toDouble();
    var i = 0;
    while (size >= 1024 && i < units.length - 1) {
      size /= 1024;
      i++;
    }
    final precision = size >= 100 || i == 0 ? 0 : 1;
    return '${size.toStringAsFixed(precision)} ${units[i]}';
  }
}
