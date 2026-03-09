class RemoteEntry {
  const RemoteEntry({
    required this.name,
    required this.fullPath,
    required this.isDirectory,
    this.size,
    this.modifiedAt,
    this.permissions,
  });

  final String name;
  final String fullPath;
  final bool isDirectory;
  final int? size;
  final DateTime? modifiedAt;
  final int? permissions;
}
