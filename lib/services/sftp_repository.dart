import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:path/path.dart' as p;

import '../models/remote_entry.dart';
import '../models/server_profile.dart';

class SftpRepository {
  Future<SftpSession> connect(ServerProfile profile) async {
    try {
      return await SftpSession._connect(profile);
    } on SftpConnectionException {
      rethrow;
    } on SocketException catch (error) {
      throw SftpHostUnreachableException(
        'Unable to reach ${profile.host}:${profile.port}. ${error.message}',
      );
    } on SSHAuthError catch (error) {
      throw SftpAuthenticationException(error.toString());
    } catch (error) {
      throw SftpUnexpectedConnectionException(
        error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }
}

enum SftpTransferType { upload, download }

class SftpTransferProgress {
  const SftpTransferProgress({
    required this.type,
    required this.name,
    required this.transferredBytes,
    required this.totalBytes,
  });

  final SftpTransferType type;
  final String name;
  final int transferredBytes;
  final int totalBytes;

  double? get fraction {
    if (totalBytes <= 0) {
      return null;
    }
    return (transferredBytes / totalBytes).clamp(0, 1).toDouble();
  }
}

enum RemotePreviewType { text, image, unsupported }

typedef FilePreviewType = RemotePreviewType;

class RemoteFilePreview {
  const RemoteFilePreview._({
    required this.type,
    this.text,
    this.bytes,
    this.truncated = false,
    this.message,
  });

  const RemoteFilePreview.text({required String text, bool truncated = false})
    : this._(type: RemotePreviewType.text, text: text, truncated: truncated);

  const RemoteFilePreview.image(Uint8List bytes)
    : this._(type: RemotePreviewType.image, bytes: bytes);

  const RemoteFilePreview.unsupported([String? message])
    : this._(type: RemotePreviewType.unsupported, message: message);

  final RemotePreviewType type;
  final String? text;
  final Uint8List? bytes;
  final bool truncated;
  final String? message;
}

typedef FilePreviewData = RemoteFilePreview;
typedef SftpSessionHandle = SftpSession;

enum SftpConnectionErrorType { hostUnreachable, authentication, unexpected }

abstract class SftpConnectionException implements Exception {
  const SftpConnectionException(this.type, this.title, this.message);

  final SftpConnectionErrorType type;
  final String title;
  final String message;

  String get userMessage => message;

  @override
  String toString() => message;
}

class SftpHostUnreachableException extends SftpConnectionException {
  const SftpHostUnreachableException(String message)
    : super(
        SftpConnectionErrorType.hostUnreachable,
        'Server unreachable',
        message,
      );
}

class SftpAuthenticationException extends SftpConnectionException {
  const SftpAuthenticationException(String message)
    : super(
        SftpConnectionErrorType.authentication,
        'Authentication failed',
        message,
      );
}

class SftpUnexpectedConnectionException extends SftpConnectionException {
  const SftpUnexpectedConnectionException(String message)
    : super(SftpConnectionErrorType.unexpected, 'Unable to connect', message);
}

class SftpSession {
  SftpSession._(this.profile, this._ssh, this._sftp, this._homeDirectory);

  static const int _textPreviewLimitBytes = 256 * 1024;
  static const int _imagePreviewLimitBytes = 8 * 1024 * 1024;

  final ServerProfile profile;
  final SSHClient _ssh;
  final SftpClient _sftp;
  final String _homeDirectory;

  String get homeDirectory => _homeDirectory;

  static Future<SftpSession> _connect(ServerProfile profile) async {
    try {
      final socket = await SSHSocket.connect(profile.host, profile.port);

      final ssh = SSHClient(
        socket,
        username: profile.username,
        onVerifyHostKey: (type, fingerprint) => true,
        identities:
            profile.authType == AuthType.privateKey &&
                    (profile.privateKey?.isNotEmpty ?? false)
                ? SSHKeyPair.fromPem(
                  profile.privateKey!,
                ).map((key) => key).toList()
                : null,
        onPasswordRequest:
            profile.authType == AuthType.password
                ? () => profile.password ?? ''
                : null,
      );

      await ssh.authenticated;
      final sftp = await ssh.sftp();
      final homeDirectory = await _resolveHomeDirectory(ssh, sftp);
      return SftpSession._(profile, ssh, sftp, homeDirectory);
    } on SocketException catch (error) {
      throw SftpHostUnreachableException(
        'Unable to reach ${profile.host}:${profile.port}. ${error.message}',
      );
    } on SSHAuthError catch (error) {
      throw SftpAuthenticationException(error.toString());
    } catch (error) {
      throw SftpUnexpectedConnectionException(
        error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  static Future<String> _resolveHomeDirectory(
    SSHClient ssh,
    SftpClient sftp,
  ) async {
    try {
      final result = await ssh.run('echo \$HOME');
      final home = String.fromCharCodes(result).trim();
      if (home.isNotEmpty) {
        return home;
      }
    } catch (_) {}

    try {
      return await sftp.absolute('.');
    } catch (_) {}

    try {
      final result = await ssh.run('pwd');
      final pwd = String.fromCharCodes(result).trim();
      if (pwd.isNotEmpty) {
        return pwd;
      }
    } catch (_) {}

    return '/';
  }

  Future<List<RemoteEntry>> listDirectory(String path) async {
    final items = <SftpName>[];
    await for (final batch in _sftp.readdir(path)) {
      items.addAll(batch);
    }

    final entries = items
        .where((item) => item.filename != '.' && item.filename != '..')
        .map((item) {
          final isDirectory = item.attr.isDirectory;
          final fullPath =
              path.endsWith('/')
                  ? '$path${item.filename}'
                  : '$path/${item.filename}';

          return RemoteEntry(
            name: item.filename,
            fullPath: fullPath,
            isDirectory: isDirectory,
            size: isDirectory ? null : item.attr.size?.toInt(),
            modifiedAt:
                item.attr.modifyTime == null
                    ? null
                    : DateTime.fromMillisecondsSinceEpoch(
                      item.attr.modifyTime!.toInt() * 1000,
                    ),
            permissions: item.attr.mode?.value,
          );
        })
        .toList(growable: false);

    return const RemoteEntrySort().sortEntries(entries);
  }

  Future<void> rename(String oldPath, String newPath) async {
    await _sftp.rename(oldPath, newPath);
  }

  Future<void> createDirectory(String directoryPath, String name) async {
    await _sftp.mkdir(normalizeRemotePath(directoryPath, name));
  }

  Future<void> delete(RemoteEntry entry) async {
    if (entry.isDirectory) {
      await sshRun('rm -rf -- ${_shellQuote(entry.fullPath)}');
    } else {
      await _sftp.remove(entry.fullPath);
    }
  }

  Stream<SftpTransferProgress> downloadFile(
    RemoteEntry entry, {
    void Function(Uint8List chunk)? onChunk,
  }) async* {
    final file = await _sftp.open(entry.fullPath);
    final totalBytes = entry.size ?? (await file.stat()).size?.toInt() ?? 0;
    var transferred = 0;

    try {
      await for (final chunk in file.read()) {
        transferred += chunk.length;
        onChunk?.call(chunk);
        yield SftpTransferProgress(
          type: SftpTransferType.download,
          name: entry.name,
          transferredBytes: transferred,
          totalBytes: totalBytes,
        );
      }

      if (transferred == 0) {
        yield SftpTransferProgress(
          type: SftpTransferType.download,
          name: entry.name,
          transferredBytes: 0,
          totalBytes: totalBytes,
        );
      }
    } finally {
      await file.close();
    }
  }

  Stream<SftpTransferProgress> uploadFile({
    required Stream<Uint8List> data,
    required int totalBytes,
    required String remotePath,
    required String label,
  }) async* {
    final file = await _sftp.open(
      remotePath,
      mode:
          SftpFileOpenMode.create |
          SftpFileOpenMode.write |
          SftpFileOpenMode.truncate,
    );

    var offset = 0;
    try {
      await for (final chunk in data) {
        await file.writeBytes(chunk, offset: offset);
        offset += chunk.length;
        yield SftpTransferProgress(
          type: SftpTransferType.upload,
          name: label,
          transferredBytes: offset,
          totalBytes: totalBytes,
        );
      }

      if (offset == 0) {
        yield SftpTransferProgress(
          type: SftpTransferType.upload,
          name: label,
          transferredBytes: 0,
          totalBytes: totalBytes,
        );
      }
    } finally {
      await file.close();
    }
  }

  Future<RemoteFilePreview> loadPreview(RemoteEntry entry) async {
    if (entry.isDirectory) {
      return const RemoteFilePreview.unsupported(
        'Folders cannot be previewed.',
      );
    }

    final extension = p.extension(entry.name).toLowerCase();
    if (_textExtensions.contains(extension)) {
      final bytes = await _readFileBytes(
        entry.fullPath,
        maxBytes: _textPreviewLimitBytes,
      );
      final totalBytes = entry.size ?? bytes.length;
      try {
        return RemoteFilePreview.text(
          text: utf8.decode(bytes),
          truncated: totalBytes > _textPreviewLimitBytes,
        );
      } on FormatException {
        return const RemoteFilePreview.unsupported(
          'This file could not be decoded as UTF-8 text.',
        );
      }
    }

    if (_imageExtensions.contains(extension)) {
      final totalBytes = entry.size ?? 0;
      if (totalBytes > _imagePreviewLimitBytes) {
        return const RemoteFilePreview.unsupported(
          'This image is too large to preview safely.',
        );
      }

      final bytes = await _readFileBytes(
        entry.fullPath,
        maxBytes: _imagePreviewLimitBytes,
      );
      return RemoteFilePreview.image(bytes);
    }

    return const RemoteFilePreview.unsupported(
      'Only text files and common image formats can be previewed right now.',
    );
  }

  Future<Uint8List> _readFileBytes(String path, {int? maxBytes}) async {
    final file = await _sftp.open(path);
    final buffer = BytesBuilder(copy: false);
    try {
      await for (final chunk in file.read()) {
        if (maxBytes != null) {
          final remaining = maxBytes - buffer.length;
          if (remaining <= 0) {
            break;
          }
          if (chunk.length > remaining) {
            buffer.add(chunk.sublist(0, remaining));
            break;
          }
        }
        buffer.add(chunk);
      }
      return buffer.takeBytes();
    } finally {
      await file.close();
    }
  }

  Future<void> writeFile(String remotePath, Uint8List bytes) async {
    final file = await _sftp.open(
      remotePath,
      mode:
          SftpFileOpenMode.create |
          SftpFileOpenMode.write |
          SftpFileOpenMode.truncate,
    );
    try {
      await file.writeBytes(bytes);
    } finally {
      await file.close();
    }
  }

  Future<String> sshRun(String command) async {
    final result = await _ssh.run(command);
    return String.fromCharCodes(result).trim();
  }

  Future<SSHSession> openShell({int width = 80, int height = 24}) async {
    return _ssh.shell(pty: SSHPtyConfig(width: width, height: height));
  }

  Future<void> close() async {
    _sftp.close();
    _ssh.close();
  }

  static String _shellQuote(String value) {
    return "'${value.replaceAll("'", "'\"'\"'")}'";
  }

  static String normalizeRemotePath(String directory, String childName) {
    if (directory == '/') {
      return '/$childName';
    }
    return '$directory/$childName';
  }

  static const Set<String> _textExtensions = <String>{
    '.txt',
    '.log',
    '.md',
    '.json',
    '.yaml',
    '.yml',
    '.xml',
    '.csv',
    '.ini',
    '.conf',
    '.sh',
    '.dart',
    '.js',
    '.ts',
    '.css',
    '.html',
    '.py',
    '.java',
    '.kt',
    '.swift',
    '.go',
    '.rs',
    '.c',
    '.cc',
    '.cpp',
    '.h',
    '.hpp',
  };

  static const Set<String> _imageExtensions = <String>{
    '.png',
    '.jpg',
    '.jpeg',
    '.gif',
    '.webp',
    '.bmp',
  };
}
