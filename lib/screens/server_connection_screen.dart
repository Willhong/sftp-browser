import 'dart:async';

import 'package:flutter/material.dart';

import '../models/server_profile.dart';
import '../services/sftp_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';
import '../widgets/app_stat_chip.dart';
import '../widgets/section_card.dart';
import '../widgets/state_panel.dart';
import 'file_browser_screen.dart';

typedef ConnectedBrowserBuilder =
    Widget Function(
      BuildContext context,
      ServerProfile profile,
      SftpSession session,
      FileBrowserInitialState initialState,
      Future<void> Function(ServerProfile profile)? onProfileChanged,
    );

enum _ConnectionStage { connecting, loadingDirectory, connectedReady, failed }

class ServerConnectionScreen extends StatefulWidget {
  const ServerConnectionScreen({
    super.key,
    required this.profile,
    this.repository,
    this.browserBuilder,
    this.onProfileChanged,
    this.autoNavigate = true,
    this.successHoldDuration = Duration.zero,
  });

  final ServerProfile profile;
  final SftpRepository? repository;
  final ConnectedBrowserBuilder? browserBuilder;
  final Future<void> Function(ServerProfile profile)? onProfileChanged;
  final bool autoNavigate;
  final Duration successHoldDuration;

  @override
  State<ServerConnectionScreen> createState() => _ServerConnectionScreenState();
}

class _ServerConnectionScreenState extends State<ServerConnectionScreen> {
  late final SftpRepository _repository = widget.repository ?? SftpRepository();
  late ServerProfile _profile = widget.profile;

  SftpSession? _session;
  FileBrowserInitialState? _initialState;
  _ConnectionStage _stage = _ConnectionStage.connecting;
  String? _failureTitle;
  String? _failureMessage;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void dispose() {
    if (_stage != _ConnectionStage.connectedReady) {
      _session?.close();
    }
    super.dispose();
  }

  Future<void> _connect() async {
    await _session?.close();
    _session = null;
    _initialState = null;

    if (mounted) {
      setState(() {
        _stage = _ConnectionStage.connecting;
        _failureTitle = null;
        _failureMessage = null;
      });
    }

    late final SftpSession session;
    try {
      session = await _repository.connect(_profile);
    } on SftpConnectionException catch (error) {
      _showFailure(_buildConnectionFailure(error));
      return;
    } catch (error) {
      _showFailure(
        _ConnectionFailureContent(
          title: 'Unable to connect',
          message: _formatError(error),
        ),
      );
      return;
    }

    if (!mounted) {
      await session.close();
      return;
    }

    setState(() {
      _session = session;
      _stage = _ConnectionStage.loadingDirectory;
    });

    try {
      final homePath = session.homeDirectory;
      final entries = await session.listDirectory(homePath);
      if (!mounted) {
        await session.close();
        return;
      }

      final initialState = FileBrowserInitialState(
        homePath: homePath,
        currentPath: homePath,
        entries: entries,
      );

      setState(() {
        _session = session;
        _initialState = initialState;
        _stage = _ConnectionStage.connectedReady;
      });

      if (widget.autoNavigate) {
        if (widget.successHoldDuration > Duration.zero) {
          await Future<void>.delayed(widget.successHoldDuration);
        }
        if (!mounted || _session != session || _initialState != initialState) {
          return;
        }
        unawaited(_openBrowser());
      }
    } catch (error) {
      await session.close();
      _session = null;
      _initialState = null;
      _showFailure(
        _ConnectionFailureContent(
          title: 'Unable to open home folder',
          message: _formatError(error),
        ),
      );
    }
  }

  Future<void> _openBrowser() async {
    final session = _session;
    final initialState = _initialState;
    if (session == null || initialState == null) {
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder:
            (context) =>
                widget.browserBuilder?.call(
                  context,
                  _profile,
                  session,
                  initialState,
                  _handleProfileChanged,
                ) ??
                FileBrowserScreen(
                  profile: _profile,
                  session: session,
                  initialState: initialState,
                  onProfileChanged: _handleProfileChanged,
                ),
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _session = null;
      _initialState = null;
      _stage = _ConnectionStage.connecting;
    });
    await _connect();
  }

  _ConnectionFailureContent _buildConnectionFailure(
    SftpConnectionException error,
  ) {
    return switch (error.type) {
      SftpConnectionErrorType.hostUnreachable => _ConnectionFailureContent(
        title: error.title,
        message:
            'Check the host, port, and network path, then try again.\n\n${error.userMessage}',
      ),
      SftpConnectionErrorType.authentication => _ConnectionFailureContent(
        title: error.title,
        message:
            'Check the username and credentials, then try again.\n\n${error.userMessage}',
      ),
      SftpConnectionErrorType.unexpected => _ConnectionFailureContent(
        title: error.title,
        message:
            'The server returned an unexpected connection error.\n\n${error.userMessage}',
      ),
    };
  }

  void _showFailure(_ConnectionFailureContent failure) {
    if (!mounted) {
      return;
    }

    setState(() {
      _stage = _ConnectionStage.failed;
      _failureTitle = failure.title;
      _failureMessage = failure.message;
    });
  }

  String _formatError(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<void> _handleProfileChanged(ServerProfile profile) async {
    await widget.onProfileChanged?.call(profile);
    if (!mounted) {
      return;
    }
    setState(() {
      _profile = profile;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppPageScaffold(
      title: 'Connect to server',
      maxWidth: AppTheme.formMaxWidth,
      child: Column(
        children: [
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _profile.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_profile.host} • port ${_profile.port} • ${_profile.authLabel}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    AppStatChip(label: 'User', value: _profile.username),
                    AppStatChip(
                      label: 'State',
                      value: switch (_stage) {
                        _ConnectionStage.connecting => 'Connecting',
                        _ConnectionStage.loadingDirectory =>
                          'Preparing browser',
                        _ConnectionStage.connectedReady => 'Ready',
                        _ConnectionStage.failed => 'Needs attention',
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.sectionGap),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: AnimatedSwitcher(
                  duration: AppTheme.switcherDuration,
                  child: switch (_stage) {
                    _ConnectionStage.connecting => _buildLoadingPanel(
                      theme,
                      key: const ValueKey('connection-loading'),
                      title: 'Connecting to ${widget.profile.title}',
                      message:
                          'Establishing the SSH session for remote browsing.',
                    ),
                    _ConnectionStage.loadingDirectory => _buildLoadingPanel(
                      theme,
                      key: const ValueKey('connection-loading-directory'),
                      title: 'Preparing ${widget.profile.title}',
                      message:
                          'Loading the first folder so the browser can open ready to explore.',
                    ),
                    _ConnectionStage.connectedReady => _buildConnectedPanel(
                      theme,
                    ),
                    _ConnectionStage.failed => _buildFailedPanel(theme),
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingPanel(
    ThemeData theme, {
    required Key key,
    required String title,
    required String message,
  }) {
    return SectionCard(
      key: key,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 2.8),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedPanel(ThemeData theme) {
    final session = _session;
    final initialState = _initialState;

    return StatePanel(
      key: const ValueKey('connection-success'),
      icon: Icons.check_circle_outline,
      title: 'Browser ready for ${widget.profile.title}',
      message:
          session == null || initialState == null
              ? 'The server is ready.'
              : 'Connected to ${widget.profile.host}. ${initialState.entries.length} items loaded from ${initialState.currentPath}.',
      action:
          widget.successHoldDuration > Duration.zero
              ? const Padding(
                padding: EdgeInsets.only(top: 2),
                child: LinearProgressIndicator(minHeight: 3),
              )
              : FilledButton.icon(
                onPressed: _openBrowser,
                icon: const Icon(Icons.folder_open_outlined, size: 18),
                label: const Text('Open browser'),
              ),
      tint: theme.colorScheme.secondaryContainer.withValues(alpha: 0.34),
      iconBackgroundColor: theme.colorScheme.secondaryContainer.withValues(
        alpha: 0.7,
      ),
      iconForegroundColor: theme.colorScheme.onSecondaryContainer,
    );
  }

  Widget _buildFailedPanel(ThemeData theme) {
    return StatePanel(
      key: const ValueKey('connection-failure'),
      icon: Icons.cloud_off_outlined,
      title: _failureTitle ?? 'Unable to connect',
      message: _failureMessage ?? 'Connection failed.',
      action: FilledButton.tonalIcon(
        onPressed: _connect,
        icon: const Icon(Icons.refresh, size: 18),
        label: const Text('Try again'),
      ),
      tint: theme.colorScheme.errorContainer.withValues(
        alpha: AppTheme.isDark(theme) ? 0.18 : 0.28,
      ),
      iconBackgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.65,
      ),
      iconForegroundColor: theme.colorScheme.onErrorContainer,
    );
  }
}

class _ConnectionFailureContent {
  const _ConnectionFailureContent({required this.title, required this.message});

  final String title;
  final String message;
}
