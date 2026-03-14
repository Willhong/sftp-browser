import 'dart:async';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sftp_browser/app.dart';
import 'package:sftp_browser/models/remote_entry.dart';
import 'package:sftp_browser/models/server_profile.dart';
import 'package:sftp_browser/screens/file_browser_screen.dart';
import 'package:sftp_browser/screens/file_preview_screen.dart';
import 'package:sftp_browser/screens/server_connection_screen.dart';
import 'package:sftp_browser/services/sftp_repository.dart';
import 'package:sftp_browser/theme/app_theme.dart';

void main() {
  test(
    '[REQ-profile-favorites][RISK-backward-compatibility] decodes and encodes favorite paths without duplicates',
    () {
      final profiles = ServerProfile.decodeList('''
        [
          {
            "id": "server-1",
            "host": "example.com",
            "port": 22,
            "username": "demo",
            "authType": "password",
            "password": "secret",
            "favoritePaths": ["/home/demo", " /var/www ", "/home/demo", ""]
          },
          {
            "id": "server-2",
            "host": "legacy.example.com",
            "port": 22,
            "username": "legacy",
            "authType": "password",
            "password": "secret"
          }
        ]
        ''');

      expect(profiles[0].favoritePaths, <String>['/home/demo', '/var/www']);
      expect(profiles[1].favoritePaths, isEmpty);

      final encoded = ServerProfile.encodeList(profiles);
      expect(encoded, contains('"favoritePaths":["/home/demo","/var/www"]'));
      expect(encoded, contains('"favoritePaths":[]'));
    },
  );

  testWidgets('[REQ-home][RISK-smoke] shows the saved server landing screen', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('SFTP Browser'), findsOneWidget);
    expect(find.text('Add server'), findsWidgets);
  });

  group('ServerConnectionScreen', () {
    testWidgets(
      '[REQ-connection-loading][RISK-pending-connect] shows connecting before the session resolves',
      (tester) async {
        final repository = _FakeRepository(
          connectHandler: (_) => Completer<SftpSession>().future,
        );

        await tester.pumpWidget(
          _TestHost(
            child: ServerConnectionScreen(
              profile: _profile,
              repository: repository,
              successHoldDuration: const Duration(minutes: 1),
            ),
          ),
        );

        expect(
          find.byKey(const ValueKey('connection-loading')),
          findsOneWidget,
        );
        expect(find.text('Connecting to demo@example.com'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      },
    );

    testWidgets(
      '[REQ-connection-handoff][RISK-positive] preloads the first directory and opens the browser with ready entries',
      (tester) async {
        final session = _FakeSession(
          entriesByPath: <String, List<RemoteEntry>>{
            '/home/demo': <RemoteEntry>[_textEntry, _folderEntry],
          },
        );
        final repository = _FakeRepository(
          connectHandler: (_) async => session,
        );

        await tester.pumpWidget(
          _TestHost(
            child: ServerConnectionScreen(
              profile: _profile,
              repository: repository,
              browserBuilder:
                  (_, __, ___, initialState, ____) =>
                      _BrowserProbe(initialState),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Probe path: /home/demo'), findsOneWidget);
        expect(find.text('Probe items: 2'), findsOneWidget);
        expect(find.text('notes.txt'), findsOneWidget);
        expect(find.text('docs'), findsOneWidget);
      },
    );

    testWidgets(
      '[REQ-connection-handoff][RISK-negative-preload] stays on the connection screen when the first directory load fails',
      (tester) async {
        var browserOpened = false;
        final repository = _FakeRepository(
          connectHandler:
              (_) async => _FakeSession(
                listDirectoryHandler:
                    (_) async =>
                        throw Exception('Permission denied for /home/demo'),
              ),
        );

        await tester.pumpWidget(
          _TestHost(
            child: ServerConnectionScreen(
              profile: _profile,
              repository: repository,
              autoNavigate: true,
              browserBuilder: (_, __, ___, ____, _____) {
                browserOpened = true;
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(browserOpened, isFalse);
        expect(
          find.byKey(const ValueKey('connection-failure')),
          findsOneWidget,
        );
        expect(find.text('Unable to open home folder'), findsOneWidget);
        expect(find.text('Permission denied for /home/demo'), findsOneWidget);
      },
    );

    testWidgets(
      '[REQ-connection-handoff][RISK-partial-retry] retries a failed preload and reaches the ready state',
      (tester) async {
        var attempt = 0;
        final repository = _FakeRepository(
          connectHandler: (_) async {
            attempt += 1;
            if (attempt == 1) {
              return _FakeSession(
                listDirectoryHandler:
                    (_) async => throw Exception('Temporary preload failure'),
              );
            }
            return _FakeSession(
              entriesByPath: <String, List<RemoteEntry>>{
                '/home/demo': <RemoteEntry>[_textEntry],
              },
            );
          },
        );

        await tester.pumpWidget(
          _TestHost(
            child: ServerConnectionScreen(
              profile: _profile,
              repository: repository,
              autoNavigate: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Unable to open home folder'), findsOneWidget);
        expect(find.text('Temporary preload failure'), findsOneWidget);

        await tester.tap(find.text('Try again'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('connection-success')),
          findsOneWidget,
        );
        expect(find.text('Browser ready for demo@example.com'), findsOneWidget);
        expect(
          find.textContaining('1 items loaded from /home/demo'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '[REQ-connection-errors][RISK-host-unreachable] shows host guidance for unreachable hosts',
      (tester) async {
        final repository = _FakeRepository(
          connectHandler:
              (_) async =>
                  throw const SftpHostUnreachableException(
                    'Unable to reach example.com:22. Network is unreachable',
                  ),
        );

        await tester.pumpWidget(
          _TestHost(
            child: ServerConnectionScreen(
              profile: _profile,
              repository: repository,
              autoNavigate: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Server unreachable'), findsOneWidget);
        expect(
          find.textContaining('Check the host, port, and network path'),
          findsOneWidget,
        );
        expect(find.textContaining('Network is unreachable'), findsOneWidget);
      },
    );

    testWidgets(
      '[REQ-connection-errors][RISK-authentication] shows credential guidance for auth failures',
      (tester) async {
        final repository = _FakeRepository(
          connectHandler:
              (_) async =>
                  throw const SftpAuthenticationException(
                    'Authentication failed. Check the username and credentials.',
                  ),
        );

        await tester.pumpWidget(
          _TestHost(
            child: ServerConnectionScreen(
              profile: _profile,
              repository: repository,
              autoNavigate: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Authentication failed'), findsOneWidget);
        expect(
          find.textContaining('Check the username and credentials'),
          findsWidgets,
        );
      },
    );

    testWidgets(
      '[REQ-connection-errors][RISK-unexpected] shows fallback guidance for typed unexpected failures',
      (tester) async {
        final repository = _FakeRepository(
          connectHandler:
              (_) async =>
                  throw const SftpUnexpectedConnectionException(
                    'SSH negotiation failed unexpectedly.',
                  ),
        );

        await tester.pumpWidget(
          _TestHost(
            child: ServerConnectionScreen(
              profile: _profile,
              repository: repository,
              autoNavigate: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Unable to connect'), findsOneWidget);
        expect(
          find.textContaining('unexpected connection error'),
          findsOneWidget,
        );
        expect(
          find.textContaining('SSH negotiation failed unexpectedly.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '[REQ-connection-errors][RISK-generic-fallback] safely shows general exceptions with fallback messaging',
      (tester) async {
        final repository = _FakeRepository(
          connectHandler: (_) async => throw Exception('Socket exploded'),
        );

        await tester.pumpWidget(
          _TestHost(
            child: ServerConnectionScreen(
              profile: _profile,
              repository: repository,
              autoNavigate: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Unable to connect'), findsOneWidget);
        expect(find.text('Socket exploded'), findsOneWidget);
      },
    );

    testWidgets(
      '[REQ-connection-errors][RISK-retry-recovery] recovers from a typed connection failure after retry',
      (tester) async {
        var attempt = 0;
        final repository = _FakeRepository(
          connectHandler: (_) async {
            attempt += 1;
            if (attempt == 1) {
              throw const SftpAuthenticationException('Bad password');
            }
            return _FakeSession(
              entriesByPath: <String, List<RemoteEntry>>{
                '/home/demo': <RemoteEntry>[_textEntry],
              },
            );
          },
        );

        await tester.pumpWidget(
          _TestHost(
            child: ServerConnectionScreen(
              profile: _profile,
              repository: repository,
              autoNavigate: false,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Authentication failed'), findsOneWidget);

        await tester.tap(find.text('Try again'));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('connection-success')),
          findsOneWidget,
        );
        expect(find.text('Browser ready for demo@example.com'), findsOneWidget);
      },
    );
  });

  group('FileBrowserScreen', () {
    testWidgets(
      '[REQ-browser-initial-state][RISK-positive] renders the handed-off path and entries immediately',
      (tester) async {
        final session = _FakeSession();

        await tester.pumpWidget(
          _TestHost(
            child: FileBrowserScreen(
              profile: _profile,
              session: session,
              initialState: _initialBrowserState(
                entries: <RemoteEntry>[_textEntry],
              ),
              closeSessionOnDispose: false,
            ),
          ),
        );

        expect(find.text('/home/demo'), findsWidgets);
        expect(find.text('notes.txt'), findsOneWidget);
        expect(find.text('1'), findsWidgets);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      },
    );

    testWidgets(
      '[REQ-browser-initial-state][RISK-empty-state] shows the empty state for an empty initial directory',
      (tester) async {
        final session = _FakeSession();

        await tester.pumpWidget(
          _TestHost(
            child: FileBrowserScreen(
              profile: _profile,
              session: session,
              initialState: _initialBrowserState(
                entries: const <RemoteEntry>[],
              ),
              closeSessionOnDispose: false,
            ),
          ),
        );

        expect(find.text('This folder is empty'), findsOneWidget);
        expect(find.text('Upload'), findsWidgets);
        expect(find.text('Create folder'), findsWidgets);
      },
    );

    testWidgets(
      '[REQ-browser-initial-state][RISK-out-of-order-refresh] keeps the newest refresh result when responses finish out of order',
      (tester) async {
        final firstRefresh = Completer<List<RemoteEntry>>();
        final secondRefresh = Completer<List<RemoteEntry>>();
        var callCount = 0;
        final session = _FakeSession(
          listDirectoryHandler: (_) {
            callCount += 1;
            return switch (callCount) {
              1 => firstRefresh.future,
              2 => secondRefresh.future,
              _ => Future<List<RemoteEntry>>.value(<RemoteEntry>[_freshEntry]),
            };
          },
        );

        await tester.pumpWidget(
          _TestHost(
            child: FileBrowserScreen(
              profile: _profile,
              session: session,
              initialState: _initialBrowserState(
                entries: <RemoteEntry>[_staleEntry],
              ),
              closeSessionOnDispose: false,
            ),
          ),
        );

        expect(find.text('stale.txt'), findsOneWidget);

        await tester.drag(find.byType(ListView), const Offset(0, 300));
        await tester.pump();

        await tester.tap(find.byTooltip('Refresh'));
        await tester.pump();

        secondRefresh.complete(<RemoteEntry>[_freshEntry]);
        await tester.pump();
        firstRefresh.complete(<RemoteEntry>[_staleEntry]);
        await tester.pumpAndSettle();

        expect(find.text('fresh.txt'), findsOneWidget);
        expect(find.text('stale.txt'), findsNothing);
      },
    );

    testWidgets(
      '[REQ-transfer-state][RISK-upload-positive] shows transfer progress during an upload and clears it on success',
      (tester) async {
        final session = _FakeSession(
          entriesByPath: <String, List<RemoteEntry>>{
            '/home/demo': <RemoteEntry>[_textEntry],
          },
          uploadHandler: ({
            required data,
            required totalBytes,
            required remotePath,
            required label,
          }) async* {
            await for (final _ in data) {}
            yield const SftpTransferProgress(
              type: SftpTransferType.upload,
              name: 'upload.txt',
              transferredBytes: 2,
              totalBytes: 4,
            );
            await Future<void>.delayed(const Duration(milliseconds: 20));
            yield const SftpTransferProgress(
              type: SftpTransferType.upload,
              name: 'upload.txt',
              transferredBytes: 4,
              totalBytes: 4,
            );
          },
        );

        await tester.pumpWidget(
          _TestHost(
            child: FileBrowserScreen(
              profile: _profile,
              session: session,
              initialState: _initialBrowserState(
                entries: <RemoteEntry>[_textEntry],
              ),
              closeSessionOnDispose: false,
              pickUploadSource: () async {
                return LocalUploadSource(
                  name: 'upload.txt',
                  size: 4,
                  openRead:
                      () => Stream<Uint8List>.fromIterable(<Uint8List>[
                        Uint8List.fromList(const <int>[1, 2]),
                        Uint8List.fromList(const <int>[3, 4]),
                      ]),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Upload').first);
        await tester.pump();

        expect(find.text('Uploading upload.txt'), findsOneWidget);
        expect(find.textContaining('2 B of 4 B'), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 25));
        await tester.pumpAndSettle();

        expect(find.text('Uploading upload.txt'), findsNothing);
        expect(find.text('Uploaded upload.txt.'), findsOneWidget);
      },
    );

    testWidgets(
      '[REQ-transfer-state][RISK-download-positive] downloads a file and surfaces completion feedback',
      (tester) async {
        final session = _FakeSession(
          downloadHandler: (entry, onChunk) async* {
            onChunk?.call(Uint8List.fromList(const <int>[1, 2]));
            yield const SftpTransferProgress(
              type: SftpTransferType.download,
              name: 'notes.txt',
              transferredBytes: 2,
              totalBytes: 4,
            );
            await Future<void>.delayed(const Duration(milliseconds: 20));
            onChunk?.call(Uint8List.fromList(const <int>[3, 4]));
            yield const SftpTransferProgress(
              type: SftpTransferType.download,
              name: 'notes.txt',
              transferredBytes: 4,
              totalBytes: 4,
            );
          },
        );

        await tester.pumpWidget(
          _TestHost(
            child: FileBrowserScreen(
              profile: _profile,
              session: session,
              initialState: _initialBrowserState(
                entries: <RemoteEntry>[_textEntry],
              ),
              closeSessionOnDispose: false,
              pickDownloadDirectory: () async => '/tmp',
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.more_horiz).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Download'));
        await tester.pump();

        expect(find.text('Downloading notes.txt'), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 25));
        await tester.pumpAndSettle();

        expect(find.text('Downloaded notes.txt.'), findsOneWidget);
      },
    );

    testWidgets(
      '[REQ-transfer-state][RISK-transfer-error] clears progress and shows an error when a transfer fails after progress begins',
      (tester) async {
        final session = _FakeSession(
          uploadHandler: ({
            required data,
            required totalBytes,
            required remotePath,
            required label,
          }) async* {
            await for (final _ in data) {}
            yield const SftpTransferProgress(
              type: SftpTransferType.upload,
              name: 'upload.txt',
              transferredBytes: 2,
              totalBytes: 4,
            );
            await Future<void>.delayed(const Duration(milliseconds: 20));
            throw Exception('Upload failed while writing chunk 2');
          },
        );

        await tester.pumpWidget(
          _TestHost(
            child: FileBrowserScreen(
              profile: _profile,
              session: session,
              initialState: _initialBrowserState(
                entries: <RemoteEntry>[_textEntry],
              ),
              closeSessionOnDispose: false,
              pickUploadSource: () async {
                return LocalUploadSource(
                  name: 'upload.txt',
                  size: 4,
                  openRead:
                      () => Stream<Uint8List>.fromIterable(<Uint8List>[
                        Uint8List.fromList(const <int>[1, 2]),
                        Uint8List.fromList(const <int>[3, 4]),
                      ]),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Upload').first);
        await tester.pump();
        expect(find.text('Uploading upload.txt'), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 25));
        await tester.pumpAndSettle();

        expect(find.text('Uploading upload.txt'), findsNothing);
        expect(
          find.text('Upload failed while writing chunk 2'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '[REQ-browser-favorites][RISK-positive] saves the current path as a favorite and reopens it from the header',
      (tester) async {
        final visitedPaths = <String>[];
        ServerProfile? savedProfile;
        final session = _FakeSession(
          listDirectoryHandler: (path) async {
            visitedPaths.add(path);
            return switch (path) {
              '/home/demo/docs' => <RemoteEntry>[_freshEntry],
              _ => <RemoteEntry>[_folderEntry],
            };
          },
        );

        await tester.pumpWidget(
          _TestHost(
            child: FileBrowserScreen(
              profile: _profile,
              session: session,
              initialState: _initialBrowserState(
                entries: <RemoteEntry>[_folderEntry],
              ),
              closeSessionOnDispose: false,
              onProfileChanged: (profile) async {
                savedProfile = profile;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('docs'));
        await tester.pumpAndSettle();
        expect(find.text('/home/demo/docs'), findsWidgets);

        await tester.tap(find.byTooltip('Save current path to favorites'));
        await tester.pumpAndSettle();

        expect(savedProfile?.favoritePaths, <String>['/home/demo/docs']);
        expect(find.text('docs'), findsWidgets);

        await tester.tap(find.byType(InputChip));
        await tester.pumpAndSettle();

        expect(
          visitedPaths.where((path) => path == '/home/demo/docs').length,
          2,
        );
        expect(find.text('fresh.txt'), findsOneWidget);
      },
    );

    testWidgets(
      '[REQ-browser-favorites][RISK-delete] removes a saved favorite path from the header',
      (tester) async {
        ServerProfile? savedProfile;

        await tester.pumpWidget(
          _TestHost(
            child: FileBrowserScreen(
              profile: _profile.copyWith(
                favoritePaths: const <String>['/home/demo/docs'],
              ),
              session: _FakeSession(),
              initialState: _initialBrowserState(
                entries: <RemoteEntry>[_folderEntry],
              ),
              closeSessionOnDispose: false,
              onProfileChanged: (profile) async {
                savedProfile = profile;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(InputChip), findsOneWidget);

        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();

        expect(savedProfile?.favoritePaths, isEmpty);
        expect(find.byType(InputChip), findsNothing);
      },
    );
  });

  group('FilePreviewScreen', () {
    testWidgets(
      '[REQ-preview-state][RISK-text-preview] renders a text preview',
      (tester) async {
        final session = _FakeSession(
          previewHandler:
              (_) async =>
                  const RemoteFilePreview.text(text: 'hello remote world'),
        );

        await tester.pumpWidget(
          _TestHost(
            child: FilePreviewScreen(entry: _textEntry, session: session),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('preview-text')), findsOneWidget);
        expect(find.text('hello remote world'), findsOneWidget);
      },
    );

    testWidgets(
      '[REQ-preview-state][RISK-image-preview] renders an image preview',
      (tester) async {
        final session = _FakeSession(
          previewHandler: (_) async => RemoteFilePreview.image(_pngBytes),
        );

        await tester.pumpWidget(
          _TestHost(
            child: FilePreviewScreen(entry: _imageEntry, session: session),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('preview-image')), findsOneWidget);
        expect(find.byType(Image), findsOneWidget);
      },
    );

    testWidgets(
      '[REQ-preview-state][RISK-unsupported-preview] renders the unsupported fallback for non-previewable files',
      (tester) async {
        final session = _FakeSession(
          previewHandler:
              (_) async => const RemoteFilePreview.unsupported(
                'Only text files and common image formats can be previewed right now.',
              ),
        );

        await tester.pumpWidget(
          _TestHost(
            child: FilePreviewScreen(entry: _binaryEntry, session: session),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('preview-unsupported')),
          findsOneWidget,
        );
        expect(find.text('Preview not supported'), findsOneWidget);
        expect(
          find.text(
            'Only text files and common image formats can be previewed right now.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '[REQ-preview-state][RISK-preview-error-retry] shows preview errors and recovers after retry',
      (tester) async {
        var attempt = 0;
        final session = _FakeSession(
          previewHandler: (_) async {
            attempt += 1;
            if (attempt == 1) {
              throw Exception('Preview service timed out');
            }
            return const RemoteFilePreview.text(text: 'retry succeeded');
          },
        );

        await tester.pumpWidget(
          _TestHost(
            child: FilePreviewScreen(entry: _textEntry, session: session),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('preview-error')), findsOneWidget);
        expect(find.text('Preview unavailable'), findsOneWidget);
        expect(find.text('Preview service timed out'), findsOneWidget);

        await tester.tap(find.text('Try again'));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('preview-text')), findsOneWidget);
        expect(find.text('retry succeeded'), findsOneWidget);
      },
    );
  });
}

class _BrowserProbe extends StatelessWidget {
  const _BrowserProbe(this.initialState);

  final FileBrowserInitialState initialState;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text('Probe path: ${initialState.currentPath}'),
          Text('Probe items: ${initialState.entries.length}'),
          for (final entry in initialState.entries) Text(entry.name),
        ],
      ),
    );
  }
}

class _TestHost extends StatelessWidget {
  const _TestHost({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.buildLightTheme(),
      home: child,
    );
  }
}

class _FakeRepository extends SftpRepository {
  _FakeRepository({required this.connectHandler});

  final Future<SftpSession> Function(ServerProfile profile) connectHandler;

  @override
  Future<SftpSession> connect(ServerProfile profile) => connectHandler(profile);
}

class _FakeSession implements SftpSession {
  _FakeSession({
    this.entriesByPath = const <String, List<RemoteEntry>>{},
    this.listDirectoryHandler,
    this.previewHandler,
    this.uploadHandler,
    this.downloadHandler,
  });

  final Map<String, List<RemoteEntry>> entriesByPath;
  final Future<List<RemoteEntry>> Function(String path)? listDirectoryHandler;
  final Future<RemoteFilePreview> Function(RemoteEntry entry)? previewHandler;
  final Stream<SftpTransferProgress> Function({
    required Stream<Uint8List> data,
    required int totalBytes,
    required String remotePath,
    required String label,
  })?
  uploadHandler;
  final Stream<SftpTransferProgress> Function(
    RemoteEntry entry,
    void Function(Uint8List chunk)? onChunk,
  )?
  downloadHandler;

  @override
  final ServerProfile profile = _profile;

  @override
  String get homeDirectory => '/home/demo';

  @override
  Future<void> close() async {}

  @override
  Future<void> createDirectory(String directoryPath, String name) async {}

  @override
  Future<void> delete(RemoteEntry entry) async {}

  @override
  Stream<SftpTransferProgress> downloadFile(
    RemoteEntry entry, {
    void Function(Uint8List chunk)? onChunk,
  }) {
    final handler = downloadHandler;
    if (handler == null) {
      return const Stream<SftpTransferProgress>.empty();
    }
    return handler(entry, onChunk);
  }

  @override
  Future<List<RemoteEntry>> listDirectory(String path) async {
    final handler = listDirectoryHandler;
    if (handler != null) {
      return handler(path);
    }
    return entriesByPath[path] ?? const <RemoteEntry>[];
  }

  @override
  Future<RemoteFilePreview> loadPreview(RemoteEntry entry) async {
    final handler = previewHandler;
    if (handler == null) {
      return const RemoteFilePreview.unsupported('missing preview');
    }
    return handler(entry);
  }

  @override
  Future<SSHSession> openShell({int width = 80, int height = 24}) async {
    throw UnimplementedError('Shell support is not needed in widget tests.');
  }

  @override
  Future<void> rename(String oldPath, String newPath) async {}

  @override
  Future<String> sshRun(String command) async => '';

  @override
  Stream<SftpTransferProgress> uploadFile({
    required Stream<Uint8List> data,
    required int totalBytes,
    required String remotePath,
    required String label,
  }) {
    final handler = uploadHandler;
    if (handler == null) {
      return const Stream<SftpTransferProgress>.empty();
    }
    return handler(
      data: data,
      totalBytes: totalBytes,
      remotePath: remotePath,
      label: label,
    );
  }

  @override
  Future<void> writeFile(String remotePath, Uint8List bytes) async {}
}

FileBrowserInitialState _initialBrowserState({
  String homePath = '/home/demo',
  String currentPath = '/home/demo',
  required List<RemoteEntry> entries,
}) {
  return FileBrowserInitialState(
    homePath: homePath,
    currentPath: currentPath,
    entries: entries,
  );
}

const ServerProfile _profile = ServerProfile(
  id: 'server-1',
  host: 'example.com',
  port: 22,
  username: 'demo',
  authType: AuthType.password,
  password: 'secret',
);

const RemoteEntry _folderEntry = RemoteEntry(
  name: 'docs',
  fullPath: '/home/demo/docs',
  isDirectory: true,
  size: null,
);

const RemoteEntry _textEntry = RemoteEntry(
  name: 'notes.txt',
  fullPath: '/home/demo/notes.txt',
  isDirectory: false,
  size: 64,
);

const RemoteEntry _staleEntry = RemoteEntry(
  name: 'stale.txt',
  fullPath: '/home/demo/stale.txt',
  isDirectory: false,
  size: 1,
);

const RemoteEntry _freshEntry = RemoteEntry(
  name: 'fresh.txt',
  fullPath: '/home/demo/fresh.txt',
  isDirectory: false,
  size: 2,
);

const RemoteEntry _imageEntry = RemoteEntry(
  name: 'splash.png',
  fullPath: '/home/demo/splash.png',
  isDirectory: false,
  size: 68,
);

const RemoteEntry _binaryEntry = RemoteEntry(
  name: 'archive.zip',
  fullPath: '/home/demo/archive.zip',
  isDirectory: false,
  size: 512,
);

final Uint8List _pngBytes = Uint8List.fromList(const <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0xF8,
  0xCF,
  0xC0,
  0x00,
  0x00,
  0x03,
  0x01,
  0x01,
  0x00,
  0x18,
  0xDD,
  0x8D,
  0x18,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);
