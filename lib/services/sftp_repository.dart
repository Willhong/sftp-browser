import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

import '../models/remote_entry.dart';
import '../models/server_profile.dart';

class SftpRepository {
  Future<SftpSession> connect(ServerProfile profile) async {
    final session = await SftpSession._connect(profile);
    return session;
  }
}

class SftpSession {
  SftpSession._(this.profile, this._ssh, this._sftp, this._homeDirectory);

  final ServerProfile profile;
  final SSHClient _ssh;
  final SftpClient _sftp;
  final String _homeDirectory;

  String get homeDirectory => _homeDirectory;

  static Future<SftpSession> _connect(ServerProfile profile) async {
    final socket = await SSHSocket.connect(profile.host, profile.port);

    final ssh = SSHClient(
      socket,
      username: profile.username,
      onVerifyHostKey: (type, fingerprint) => true,
      identities: profile.authType == AuthType.privateKey && (profile.privateKey?.isNotEmpty ?? false)
          ? SSHKeyPair.fromPem(profile.privateKey!).map((key) => key).toList()
          : null,
      onPasswordRequest: profile.authType == AuthType.password
          ? () => profile.password ?? ''
          : null,
    );

    await ssh.authenticated;

    final sftp = await ssh.sftp();

    // Resolve home directory
    String homeDir = '/';
    try {
      final result = await ssh.run('echo \$HOME');
      final home = String.fromCharCodes(result).trim();
      if (home.isNotEmpty) homeDir = home;
    } catch (_) {
      try {
        final result = await ssh.run('pwd');
        final pwd = String.fromCharCodes(result).trim();
        if (pwd.isNotEmpty) homeDir = pwd;
      } catch (_) {}
    }

    return SftpSession._(profile, ssh, sftp, homeDir);
  }

  Future<List<RemoteEntry>> listDirectory(String path) async {
    final items = <SftpName>[];
    await for (final batch in _sftp.readdir(path)) {
      items.addAll(batch);
    }
    final entries = <RemoteEntry>[];

    for (final item in items) {
      if (item.filename == '.' || item.filename == '..') continue;

      final isDir = item.attr.type == SftpFileType.directory;
      final fullPath = path.endsWith('/')
          ? '$path${item.filename}'
          : '$path/${item.filename}';

      entries.add(RemoteEntry(
        name: item.filename,
        fullPath: fullPath,
        isDirectory: isDir,
        size: isDir ? null : item.attr.size?.toInt(),
      ));
    }

    entries.sort((a, b) {
      if (a.isDirectory != b.isDirectory) {
        return a.isDirectory ? -1 : 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return entries;
  }

  Future<void> rename(String oldPath, String newPath) async {
    await _sftp.rename(oldPath, newPath);
  }

  Future<void> delete(RemoteEntry entry) async {
    if (entry.isDirectory) {
      // Recursively remove directory contents via SSH command
      await sshRun('rm -rf -- ${_shellQuote(entry.fullPath)}');
    } else {
      await _sftp.remove(entry.fullPath);
    }
  }

  Future<Uint8List> downloadFile(RemoteEntry entry) async {
    final file = await _sftp.open(entry.fullPath);
    final chunks = <int>[];
    await for (final chunk in file.read()) {
      chunks.addAll(chunk);
    }
    await file.close();
    return Uint8List.fromList(chunks);
  }

  Future<void> uploadFile({
    required Uint8List data,
    required String remotePath,
  }) async {
    final file = await _sftp.open(
      remotePath,
      mode: SftpFileOpenMode.create | SftpFileOpenMode.write | SftpFileOpenMode.truncate,
    );
    await file.write(Stream.value(data));
    await file.close();
  }

  Future<String> sshRun(String command) async {
    final result = await _ssh.run(command);
    return String.fromCharCodes(result).trim();
  }

  Future<void> close() async {
    _sftp.close();
    _ssh.close();
  }

  static String _shellQuote(String value) {
    return "'${value.replaceAll("'", "'\"'\"'")}'";
  }

  static String normalizeRemotePath(String directory, String childName) {
    if (directory == '/') return '/$childName';
    return '$directory/$childName';
  }
}
