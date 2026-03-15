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

enum RemoteEntrySortField {
  name,
  modifiedDate,
  extension,
  size;

  String get label => switch (this) {
    RemoteEntrySortField.name => 'Name',
    RemoteEntrySortField.modifiedDate => 'Modified date',
    RemoteEntrySortField.extension => 'Extension',
    RemoteEntrySortField.size => 'Size',
  };

  bool get defaultAscending => switch (this) {
    RemoteEntrySortField.name => true,
    RemoteEntrySortField.extension => true,
    RemoteEntrySortField.modifiedDate => false,
    RemoteEntrySortField.size => false,
  };
}

class RemoteEntrySort {
  const RemoteEntrySort({
    this.field = RemoteEntrySortField.name,
    this.ascending = true,
    this.directoriesFirst = true,
  });

  final RemoteEntrySortField field;
  final bool ascending;
  final bool directoriesFirst;

  RemoteEntrySort copyWith({
    RemoteEntrySortField? field,
    bool? ascending,
    bool? directoriesFirst,
  }) {
    return RemoteEntrySort(
      field: field ?? this.field,
      ascending: ascending ?? this.ascending,
      directoriesFirst: directoriesFirst ?? this.directoriesFirst,
    );
  }

  List<RemoteEntry> sortEntries(Iterable<RemoteEntry> entries) {
    final sorted = List<RemoteEntry>.of(entries);
    sorted.sort(compare);
    return List<RemoteEntry>.unmodifiable(sorted);
  }

  int compare(RemoteEntry left, RemoteEntry right) {
    if (directoriesFirst && left.isDirectory != right.isDirectory) {
      return left.isDirectory ? -1 : 1;
    }

    final result = switch (field) {
      RemoteEntrySortField.name =>
        ascending ? _compareNames(left, right) : _compareNames(right, left),
      RemoteEntrySortField.modifiedDate => _compareOptionalInts(
        left.modifiedAt?.millisecondsSinceEpoch,
        right.modifiedAt?.millisecondsSinceEpoch,
        ascending: ascending,
      ),
      RemoteEntrySortField.extension => _compareOptionalStrings(
        _extensionOf(left),
        _extensionOf(right),
        ascending: ascending,
      ),
      RemoteEntrySortField.size => _compareOptionalInts(
        left.isDirectory ? null : left.size,
        right.isDirectory ? null : right.size,
        ascending: ascending,
      ),
    };

    if (result != 0) {
      return result;
    }

    return _compareNames(left, right);
  }

  int _compareNames(RemoteEntry left, RemoteEntry right) {
    final lowerCaseComparison = left.name.toLowerCase().compareTo(
      right.name.toLowerCase(),
    );
    if (lowerCaseComparison != 0) {
      return lowerCaseComparison;
    }

    final nameComparison = left.name.compareTo(right.name);
    if (nameComparison != 0) {
      return nameComparison;
    }

    return left.fullPath.compareTo(right.fullPath);
  }

  int _compareOptionalInts(int? left, int? right, {required bool ascending}) {
    if (left == null && right == null) {
      return 0;
    }
    if (left == null) {
      return 1;
    }
    if (right == null) {
      return -1;
    }
    return ascending ? left.compareTo(right) : right.compareTo(left);
  }

  int _compareOptionalStrings(
    String? left,
    String? right, {
    required bool ascending,
  }) {
    final normalizedLeft = _normalizeOptionalString(left);
    final normalizedRight = _normalizeOptionalString(right);

    if (normalizedLeft == null && normalizedRight == null) {
      return 0;
    }
    if (normalizedLeft == null) {
      return 1;
    }
    if (normalizedRight == null) {
      return -1;
    }

    final comparison =
        ascending
            ? normalizedLeft.compareTo(normalizedRight)
            : normalizedRight.compareTo(normalizedLeft);
    if (comparison != 0) {
      return comparison;
    }

    return 0;
  }

  String? _extensionOf(RemoteEntry entry) {
    if (entry.isDirectory) {
      return null;
    }

    final dotIndex = entry.name.lastIndexOf('.');
    if (dotIndex <= 0 || dotIndex == entry.name.length - 1) {
      return null;
    }

    return entry.name.substring(dotIndex + 1).toLowerCase();
  }

  String? _normalizeOptionalString(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }
}
