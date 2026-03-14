import 'package:flutter/material.dart';

import 'screens/server_list_screen.dart';
import 'services/server_store.dart';
import 'services/sftp_repository.dart';
import 'services/theme_mode_store.dart';
import 'theme/app_theme.dart';

class MyApp extends StatefulWidget {
  const MyApp({
    super.key,
    this.serverStore,
    this.repository,
    this.themeModeStore,
  });

  final ServerStore? serverStore;
  final SftpRepository? repository;
  final ThemeModeStore? themeModeStore;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final ThemeModeStore _themeModeStore =
      widget.themeModeStore ?? ThemeModeStore();

  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final storedMode = await _themeModeStore.loadThemeMode();
    if (!mounted || storedMode == null) {
      return;
    }

    setState(() {
      _themeMode = storedMode;
    });
  }

  Future<void> _toggleThemeMode() async {
    final currentBrightness = switch (_themeMode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system =>
        WidgetsBinding.instance.platformDispatcher.platformBrightness,
    };
    final nextMode =
        currentBrightness == Brightness.dark ? ThemeMode.light : ThemeMode.dark;

    setState(() {
      _themeMode = nextMode;
    });

    await _themeModeStore.saveThemeMode(nextMode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SFTP Browser',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: AppTheme.buildLightTheme(),
      darkTheme: AppTheme.buildDarkTheme(),
      home: ServerListScreen(
        serverStore: widget.serverStore ?? ServerStore(),
        repository: widget.repository ?? SftpRepository(),
        onToggleThemeMode: _toggleThemeMode,
      ),
    );
  }
}
