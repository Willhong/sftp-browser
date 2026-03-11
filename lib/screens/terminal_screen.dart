import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

import '../models/server_profile.dart';
import '../services/sftp_repository.dart';
import '../theme/app_theme.dart';

class TerminalScreen extends StatefulWidget {
  const TerminalScreen({
    super.key,
    required this.profile,
    required this.session,
  });

  final ServerProfile profile;
  final SftpSession session;

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  late final Terminal _terminal;
  SSHSession? _shellSession;
  bool _isConnecting = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(maxLines: 10000);
    _startShell();
  }

  Future<void> _startShell() async {
    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });

    try {
      _terminal.write('Connecting to ${widget.profile.host}...\r\n');

      final session = await widget.session.openShell(
        width: _terminal.viewWidth,
        height: _terminal.viewHeight,
      );

      _shellSession = session;

      _terminal.buffer.clear();
      _terminal.buffer.setCursor(0, 0);

      _terminal.onOutput = (data) {
        session.write(utf8.encode(data));
      };

      _terminal.onResize = (width, height, pixelWidth, pixelHeight) {
        session.resizeTerminal(width, height, pixelWidth, pixelHeight);
      };

      session.stdout
          .cast<List<int>>()
          .transform(const Utf8Decoder(allowMalformed: true))
          .listen(
            _terminal.write,
            onDone: _onSessionDone,
            onError: _onSessionError,
          );

      session.stderr
          .cast<List<int>>()
          .transform(const Utf8Decoder(allowMalformed: true))
          .listen(_terminal.write);

      if (mounted) {
        setState(() => _isConnecting = false);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isConnecting = false;
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _onSessionDone() {
    if (!mounted) return;
    _terminal.write('\r\n\x1b[33m[Session closed]\x1b[0m\r\n');
  }

  void _onSessionError(Object error) {
    if (!mounted) return;
    _terminal.write('\r\n\x1b[31m[Error: $error]\x1b[0m\r\n');
  }

  @override
  void dispose() {
    _shellSession?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = AppTheme.isDark(theme);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: isDark
            ? const Color(0xFF1E1E1E)
            : const Color(0xFF2D2D2D),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.profile.title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            Text(
              '${widget.profile.username}@${widget.profile.host}',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white54,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _isConnecting ? null : _startShell,
            icon: const Icon(Icons.refresh, size: 18, color: Colors.white70),
            tooltip: 'Reconnect',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isConnecting) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white54),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.terminal, size: 48, color: Colors.white38),
              const SizedBox(height: 16),
              Text(
                'Failed to open terminal',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _startShell,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return TerminalView(
      _terminal,
      theme: const TerminalTheme(
        cursor: Color(0xFFAEAFAD),
        selection: Color(0xFF5A5A5A),
        foreground: Color(0xFFCCCCCC),
        background: Color(0xFF1E1E1E),
        black: Color(0xFF000000),
        red: Color(0xFFCD3131),
        green: Color(0xFF0DBC79),
        yellow: Color(0xFFE5E510),
        blue: Color(0xFF2472C8),
        magenta: Color(0xFFBC3FBC),
        cyan: Color(0xFF11A8CD),
        white: Color(0xFFE5E5E5),
        brightBlack: Color(0xFF666666),
        brightRed: Color(0xFFF14C4C),
        brightGreen: Color(0xFF23D18B),
        brightYellow: Color(0xFFF5F543),
        brightBlue: Color(0xFF3B8EEA),
        brightMagenta: Color(0xFFD670D6),
        brightCyan: Color(0xFF29B8DB),
        brightWhite: Color(0xFFFFFFFF),
        searchHitBackground: Color(0xFFFFFF00),
        searchHitBackgroundCurrent: Color(0xFFFF8000),
        searchHitForeground: Color(0xFF000000),
      ),
      padding: const EdgeInsets.all(8),
      autofocus: true,
      textStyle: const TerminalStyle(
        fontFamily: 'JetBrainsMonoNerd',
        fontSize: 13.0,
        fontFamilyFallback: [
          'NotoSansSymbols2',
          'Noto Color Emoji',
          'sans-serif',
        ],
      ),
    );
  }
}
