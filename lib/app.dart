import 'package:flutter/material.dart';

import 'screens/workspace_screen.dart';
import 'services/server_store.dart';
import 'services/sftp_repository.dart';
import 'theme/app_theme.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.serverStore, this.repository});

  final ServerStore? serverStore;
  final SftpRepository? repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SFTP Browser',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: AppTheme.buildLightTheme(),
      darkTheme: AppTheme.buildDarkTheme(),
      home: WorkspaceScreen(
        serverStore: serverStore ?? ServerStore(),
        repository: repository ?? SftpRepository(),
      ),
    );
  }
}
