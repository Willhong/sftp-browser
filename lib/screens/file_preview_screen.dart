import 'package:flutter/material.dart';

import '../models/remote_entry.dart';
import '../services/sftp_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';
import '../widgets/file_preview_panel.dart';

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
  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'Preview',
      maxWidth: AppTheme.browserMaxWidth,
      child: FilePreviewPanel(entry: widget.entry, session: widget.session),
    );
  }
}
