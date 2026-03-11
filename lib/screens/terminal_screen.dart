import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

import '../models/server_profile.dart';
import '../services/sftp_repository.dart';
import '../theme/app_theme.dart';

// ─── Key toolbar data ────────────────────────────────────────────────────────

enum _KeyType { send, toggle }

class _KeyDef {
  const _KeyDef(this.label, this.value, {this.type = _KeyType.send});
  final String label;
  final String value; // raw bytes to send, or modifier name for toggles
  final _KeyType type;
}

const _kToolbarRows = [
  // Row 1: navigation + modifiers
  [
    _KeyDef('ESC', '\x1b'),
    _KeyDef('TAB', '\t'),
    _KeyDef('CTRL', 'ctrl', type: _KeyType.toggle),
    _KeyDef('ALT', 'alt', type: _KeyType.toggle),
    _KeyDef('↑', '\x1b[A'),
    _KeyDef('↓', '\x1b[B'),
    _KeyDef('←', '\x1b[D'),
    _KeyDef('→', '\x1b[C'),
  ],
  // Row 2: Ctrl combos (pre-computed ASCII control codes)
  [
    _KeyDef('^C', '\x03'),  // Ctrl+C  SIGINT
    _KeyDef('^D', '\x04'),  // Ctrl+D  EOF
    _KeyDef('^Z', '\x1a'),  // Ctrl+Z  SIGTSTP
    _KeyDef('^L', '\x0c'),  // Ctrl+L  clear
    _KeyDef('^A', '\x01'),  // Ctrl+A  line start
    _KeyDef('^E', '\x05'),  // Ctrl+E  line end
    _KeyDef('^K', '\x0b'),  // Ctrl+K  kill to end
    _KeyDef('^U', '\x15'),  // Ctrl+U  kill to start
  ],
  // Row 3: F keys
  [
    _KeyDef('F1', '\x1bOP'),
    _KeyDef('F2', '\x1bOQ'),
    _KeyDef('F3', '\x1bOR'),
    _KeyDef('F4', '\x1bOS'),
    _KeyDef('F5', '\x1b[15~'),
    _KeyDef('F6', '\x1b[17~'),
    _KeyDef('F7', '\x1b[18~'),
    _KeyDef('F8', '\x1b[19~'),
  ],
];

// ─── Screen ──────────────────────────────────────────────────────────────────

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
  final TerminalController _terminalController = TerminalController();
  SSHSession? _shellSession;
  bool _isConnecting = true;
  String? _errorMessage;

  // modifier toggle state
  bool _ctrlActive = false;
  bool _altActive = false;

  // font size for pinch-to-zoom
  double _fontSize = 13.0;
  double _fontSizeBeforeScale = 13.0;
  static const double _minFontSize = 8.0;
  static const double _maxFontSize = 24.0;

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
        session.write(utf8.encode(_applyModifiers(data)));
      };

      _terminal.onResize = (width, height, pixelWidth, pixelHeight) {
        // Send accurate column/row counts to PTY so bash clears lines correctly
        session.resizeTerminal(width, height, pixelWidth, pixelHeight);
      };

      // Force initial resize after shell is ready so PTY matches actual view
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _terminal.viewWidth > 0) {
          session.resizeTerminal(
            _terminal.viewWidth,
            _terminal.viewHeight,
            0,
            0,
          );
        }
      });

      session.stdout
          .cast<List<int>>()
          .transform(const Utf8Decoder(allowMalformed: true))
          .listen(_terminal.write, onDone: _onSessionDone, onError: _onSessionError);

      session.stderr
          .cast<List<int>>()
          .transform(const Utf8Decoder(allowMalformed: true))
          .listen(_terminal.write);

      if (mounted) setState(() => _isConnecting = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isConnecting = false;
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String _applyModifiers(String data) {
    if (!_ctrlActive && !_altActive) return data;

    final buffer = StringBuffer();
    for (final char in data.runes.map(String.fromCharCode)) {
      final code = char.codeUnitAt(0);
      if (_ctrlActive && code >= 64 && code <= 95) {
        // A-Z, [ \ ] ^ _ → Ctrl+A~Z etc (ASCII 1~31)
        buffer.writeCharCode(code - 64);
      } else if (_ctrlActive && code >= 97 && code <= 122) {
        // a-z → same as A-Z ctrl
        buffer.writeCharCode(code - 96);
      } else if (_altActive) {
        // Meta prefix
        buffer.write('\x1b$char');
      } else {
        buffer.write(char);
      }
    }

    // Auto-reset modifiers
    if (_ctrlActive || _altActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() { _ctrlActive = false; _altActive = false; });
      });
    }

    return buffer.toString();
  }

  void _onSessionDone() {
    if (!mounted) return;
    _terminal.write('\r\n\x1b[33m[Session closed]\x1b[0m\r\n');
  }

  void _onSessionError(Object error) {
    if (!mounted) return;
    _terminal.write('\r\n\x1b[31m[Error: $error]\x1b[0m\r\n');
  }

  // Map toolbar escape sequences to xterm TerminalKey so internal state stays in sync
  static const _seqToTerminalKey = {
    '\x1b[A': TerminalKey.arrowUp,
    '\x1b[B': TerminalKey.arrowDown,
    '\x1b[D': TerminalKey.arrowLeft,
    '\x1b[C': TerminalKey.arrowRight,
    '\x1b':   TerminalKey.escape,
    '\t':     TerminalKey.tab,
    '\x1bOP': TerminalKey.f1,
    '\x1bOQ': TerminalKey.f2,
    '\x1bOR': TerminalKey.f3,
    '\x1bOS': TerminalKey.f4,
    '\x1b[15~': TerminalKey.f5,
    '\x1b[17~': TerminalKey.f6,
    '\x1b[18~': TerminalKey.f7,
    '\x1b[19~': TerminalKey.f8,
  };

  void _sendKey(_KeyDef key) {
    if (key.type == _KeyType.toggle) {
      setState(() {
        if (key.value == 'ctrl') _ctrlActive = !_ctrlActive;
        if (key.value == 'alt') _altActive = !_altActive;
      });
      return;
    }

    final seq = key.value;
    final terminalKey = _seqToTerminalKey[seq];

    if (terminalKey != null) {
      // Route through terminal.keyInput so internal cursor state stays in sync
      _terminal.keyInput(terminalKey, alt: _altActive);
    } else {
      // Control codes (^C, ^D etc) — send directly
      var out = seq;
      if (_altActive) out = '\x1b$out';
      _shellSession?.write(utf8.encode(out));
    }

    // Auto-reset modifiers after use
    if (_ctrlActive || _altActive) {
      setState(() {
        _ctrlActive = false;
        _altActive = false;
      });
    }
  }

  @override
  void dispose() {
    _shellSession?.close();
    _terminalController.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = AppTheme.isDark(theme);

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : const Color(0xFF2D2D2D),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.profile.title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
            ),
            Text(
              '${widget.profile.username}@${widget.profile.host}',
              style: const TextStyle(fontSize: 11, color: Colors.white54),
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
      return const Center(child: CircularProgressIndicator(color: Colors.white54));
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
              const Text(
                'Failed to open terminal',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
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

    return SafeArea(
      bottom: false,
      child: Column(
      children: [
        Expanded(
          child: GestureDetector(
            onScaleStart: (details) {
              _fontSizeBeforeScale = _fontSize;
            },
            onScaleUpdate: (details) {
              if (details.pointerCount < 2) return;
              final newSize = (_fontSizeBeforeScale * details.scale)
                  .clamp(_minFontSize, _maxFontSize);
              if ((newSize - _fontSize).abs() > 0.2) {
                setState(() => _fontSize = newSize);
              }
            },
            child: TerminalView(
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
            controller: _terminalController,
            padding: const EdgeInsets.all(8),
            autofocus: true,
            simulateScroll: false,
            textStyle: TerminalStyle(
              fontFamily: 'JetBrainsMonoNerd',
              fontSize: _fontSize,
              fontFamilyFallback: const [
                'NotoSansSymbols2',
                'Noto Color Emoji',
                'sans-serif',
              ],
            ),
          ),
          ),
        ),
        _buildKeyToolbar(),
      ],
      ),
    );
  }

  // ── Key toolbar ────────────────────────────────────────────────────────────

  Widget _buildKeyToolbar() {
    return Container(
      color: const Color(0xFF2D2D2D),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(height: 1, color: Color(0xFF444444)),
          for (final row in _kToolbarRows) _buildToolbarRow(row),
        ],
      ),
    );
  }

  Widget _buildToolbarRow(List<_KeyDef> keys) {
    return SizedBox(
      height: 38,
      child: Row(
        children: keys.map((key) => Expanded(child: _buildKeyButton(key))).toList(),
      ),
    );
  }

  Widget _buildKeyButton(_KeyDef key) {
    final isToggle = key.type == _KeyType.toggle;
    final isActive = isToggle &&
        ((key.value == 'ctrl' && _ctrlActive) || (key.value == 'alt' && _altActive));

    final bgColor = isActive
        ? const Color(0xFF4A9EFF)
        : const Color(0xFF3C3C3C);
    final fgColor = isActive ? Colors.white : const Color(0xFFCCCCCC);

    // Row 2 labels show as "^C", "^D" etc for clarity
    final displayLabel = key.label;

    return GestureDetector(
      onTap: () => _sendKey(key),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 3),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(5),
        ),
        alignment: Alignment.center,
        child: Text(
          displayLabel,
          style: TextStyle(
            color: fgColor,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}
