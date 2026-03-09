import 'dart:io';

class FilePickerResult {
  const FilePickerResult(this.files);

  final List<PlatformFile> files;
}

class PlatformFile {
  const PlatformFile({
    required this.name,
    required this.path,
  });

  final String name;
  final String? path;
}

class FilePicker {
  FilePicker._();

  static final FilePicker platform = FilePicker._();

  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    bool allowMultiple = false,
  }) async {
    final executable = await _findZenity();
    if (executable == null) {
      return null;
    }

    final args = <String>[
      '--file-selection',
      if (allowMultiple) '--multiple',
      if (allowMultiple) '--separator=|',
      if (dialogTitle != null && dialogTitle.isNotEmpty) '--title=$dialogTitle',
    ];

    final result = await Process.run(executable, args);
    if (result.exitCode != 0) {
      return null;
    }

    final raw = (result.stdout as String).trim();
    if (raw.isEmpty) {
      return null;
    }

    final paths = allowMultiple ? raw.split('|') : <String>[raw];
    final files = paths
        .where((value) => value.trim().isNotEmpty)
        .map((path) => PlatformFile(name: _basename(path), path: path))
        .toList(growable: false);

    if (files.isEmpty) {
      return null;
    }

    return FilePickerResult(files);
  }

  Future<String?> getDirectoryPath({
    String? dialogTitle,
  }) async {
    final executable = await _findZenity();
    if (executable == null) {
      return null;
    }

    final args = <String>[
      '--file-selection',
      '--directory',
      if (dialogTitle != null && dialogTitle.isNotEmpty) '--title=$dialogTitle',
    ];

    final result = await Process.run(executable, args);
    if (result.exitCode != 0) {
      return null;
    }

    final raw = (result.stdout as String).trim();
    return raw.isEmpty ? null : raw;
  }

  Future<String?> _findZenity() async {
    final result = await Process.run('which', ['zenity']);
    if (result.exitCode != 0) {
      return null;
    }

    final executable = (result.stdout as String).trim();
    return executable.isEmpty ? null : executable;
  }

  String _basename(String path) {
    final normalized = path.replaceAll('\\', '/');
    final segments = normalized.split('/');
    return segments.isEmpty ? path : segments.last;
  }
}
