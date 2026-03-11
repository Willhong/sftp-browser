import 'package:flutter/material.dart';

import '../models/remote_entry.dart';
import '../services/sftp_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';
import '../widgets/app_stat_chip.dart';
import '../widgets/section_card.dart';
import '../widgets/state_panel.dart';

class FilePreviewScreen extends StatefulWidget {
  const FilePreviewScreen({
    super.key,
    required this.entry,
    required this.session,
  });

  final RemoteEntry entry;
  final SftpSession session;

  @override
  State<FilePreviewScreen> createState() => _FilePreviewScreenState();
}

class _FilePreviewScreenState extends State<FilePreviewScreen> {
  bool _isLoading = true;
  RemoteFilePreview? _preview;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final preview = await widget.session.loadPreview(widget.entry);
      if (!mounted) {
        return;
      }
      setState(() {
        _preview = preview;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppPageScaffold(
      title: 'Preview',
      maxWidth: AppTheme.browserMaxWidth,
      actions: [
        IconButton(
          onPressed: _isLoading ? null : _loadPreview,
          icon: const Icon(Icons.refresh, size: 18),
          tooltip: 'Refresh preview',
        ),
      ],
      child: Column(
        children: [
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.entry.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
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
                      label: 'Type',
                      value: widget.entry.isDirectory ? 'Folder' : 'File',
                    ),
                    AppStatChip(
                      label: 'Size',
                      value:
                          widget.entry.size == null
                              ? 'Unknown'
                              : '${widget.entry.size} B',
                    ),
                  ],
                ),
              ],
            ),
          ),
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

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(
        key: ValueKey('preview-loading'),
        child: SizedBox(
          width: 30,
          height: 30,
          child: CircularProgressIndicator(strokeWidth: 2.8),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        key: const ValueKey('preview-error'),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: StatePanel(
            icon: Icons.error_outline,
            title: 'Preview unavailable',
            message: _errorMessage!,
            action: FilledButton.tonalIcon(
              onPressed: _loadPreview,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try again'),
            ),
          ),
        ),
      );
    }

    final preview = _preview;
    if (preview == null) {
      return const SizedBox.shrink();
    }

    switch (preview.type) {
      case RemotePreviewType.text:
        return SectionCard(
          key: const ValueKey('preview-text'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (preview.truncated) ...[
                Text(
                  'Showing the first part of a larger file.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Expanded(
                child: SingleChildScrollView(
                  child: SelectableText(
                    preview.text ?? '',
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                  ),
                ),
              ),
            ],
          ),
        );
      case RemotePreviewType.image:
        return Center(
          key: const ValueKey('preview-image'),
          child: SectionCard(
            padding: const EdgeInsets.all(12),
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4,
              child: Image.memory(preview.bytes!),
            ),
          ),
        );
      case RemotePreviewType.unsupported:
        return Center(
          key: const ValueKey('preview-unsupported'),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: StatePanel(
              icon: Icons.visibility_off_outlined,
              title: 'Preview not supported',
              message:
                  preview.message ??
                  'This file type does not have an inline preview.',
            ),
          ),
        );
    }
  }
}
