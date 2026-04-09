import 'dart:convert';

enum RepoNodeKind { directory, file }

class RepoNode {
  const RepoNode({
    required this.path,
    required this.name,
    required this.kind,
    required this.typeLabel,
    this.extension,
    this.sizeBytes = 0,
    this.children = const <RepoNode>[],
  });

  final String path;
  final String name;
  final RepoNodeKind kind;
  final String typeLabel;
  final String? extension;
  final int sizeBytes;
  final List<RepoNode> children;

  bool get isDirectory => kind == RepoNodeKind.directory;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'path': path,
      'name': name,
      'kind': kind.name,
      'typeLabel': typeLabel,
      'extension': extension,
      'sizeBytes': sizeBytes,
      'children': children.map((RepoNode node) => node.toJson()).toList(),
    };
  }

  factory RepoNode.fromJson(Map<String, dynamic> json) {
    return RepoNode(
      path: json['path'] as String,
      name: json['name'] as String,
      kind: (json['kind'] as String) == 'directory'
          ? RepoNodeKind.directory
          : RepoNodeKind.file,
      typeLabel: json['typeLabel'] as String,
      extension: json['extension'] as String?,
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      children: (json['children'] as List<dynamic>? ?? <dynamic>[])
          .map(
            (dynamic item) => RepoNode.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  Iterable<RepoNode> flatten() sync* {
    yield this;
    for (final RepoNode child in children) {
      yield* child.flatten();
    }
  }
}

class RepoSection {
  const RepoSection({
    required this.id,
    required this.title,
    required this.description,
    required this.fileCount,
    required this.directoryCount,
    required this.highlights,
  });

  final String id;
  final String title;
  final String description;
  final int fileCount;
  final int directoryCount;
  final List<String> highlights;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'description': description,
      'fileCount': fileCount,
      'directoryCount': directoryCount,
      'highlights': highlights,
    };
  }

  factory RepoSection.fromJson(Map<String, dynamic> json) {
    return RepoSection(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      fileCount: (json['fileCount'] as num?)?.toInt() ?? 0,
      directoryCount: (json['directoryCount'] as num?)?.toInt() ?? 0,
      highlights: (json['highlights'] as List<dynamic>? ?? <dynamic>[])
          .cast<String>(),
    );
  }
}

class GitSummary {
  const GitSummary({
    required this.isRepository,
    required this.trackedFiles,
    required this.modifiedFiles,
    required this.stagedFiles,
    required this.untrackedFiles,
    required this.changedPaths,
  });

  const GitSummary.empty()
    : isRepository = false,
      trackedFiles = 0,
      modifiedFiles = 0,
      stagedFiles = 0,
      untrackedFiles = 0,
      changedPaths = const <String>[];

  final bool isRepository;
  final int trackedFiles;
  final int modifiedFiles;
  final int stagedFiles;
  final int untrackedFiles;
  final List<String> changedPaths;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'isRepository': isRepository,
      'trackedFiles': trackedFiles,
      'modifiedFiles': modifiedFiles,
      'stagedFiles': stagedFiles,
      'untrackedFiles': untrackedFiles,
      'changedPaths': changedPaths,
    };
  }

  factory GitSummary.fromJson(Map<String, dynamic> json) {
    return GitSummary(
      isRepository: json['isRepository'] as bool? ?? false,
      trackedFiles: (json['trackedFiles'] as num?)?.toInt() ?? 0,
      modifiedFiles: (json['modifiedFiles'] as num?)?.toInt() ?? 0,
      stagedFiles: (json['stagedFiles'] as num?)?.toInt() ?? 0,
      untrackedFiles: (json['untrackedFiles'] as num?)?.toInt() ?? 0,
      changedPaths: (json['changedPaths'] as List<dynamic>? ?? <dynamic>[])
          .cast<String>(),
    );
  }
}

class RepoSummary {
  const RepoSummary({
    required this.repoName,
    required this.rootPath,
    required this.scannedAtUtc,
    required this.scanDurationMs,
    required this.totalFiles,
    required this.totalDirectories,
    required this.maxDepth,
    required this.topLevelDirectories,
    required this.fileTypeCounts,
    required this.ignoredDirectories,
    required this.sections,
    required this.git,
  });

  final String repoName;
  final String rootPath;
  final String scannedAtUtc;
  final int scanDurationMs;
  final int totalFiles;
  final int totalDirectories;
  final int maxDepth;
  final List<String> topLevelDirectories;
  final Map<String, int> fileTypeCounts;
  final List<String> ignoredDirectories;
  final List<RepoSection> sections;
  final GitSummary git;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'repoName': repoName,
      'rootPath': rootPath,
      'scannedAtUtc': scannedAtUtc,
      'scanDurationMs': scanDurationMs,
      'totalFiles': totalFiles,
      'totalDirectories': totalDirectories,
      'maxDepth': maxDepth,
      'topLevelDirectories': topLevelDirectories,
      'fileTypeCounts': fileTypeCounts,
      'ignoredDirectories': ignoredDirectories,
      'sections': sections.map((RepoSection item) => item.toJson()).toList(),
      'git': git.toJson(),
    };
  }

  factory RepoSummary.fromJson(Map<String, dynamic> json) {
    return RepoSummary(
      repoName: json['repoName'] as String,
      rootPath: json['rootPath'] as String,
      scannedAtUtc: json['scannedAtUtc'] as String,
      scanDurationMs: (json['scanDurationMs'] as num?)?.toInt() ?? 0,
      totalFiles: (json['totalFiles'] as num?)?.toInt() ?? 0,
      totalDirectories: (json['totalDirectories'] as num?)?.toInt() ?? 0,
      maxDepth: (json['maxDepth'] as num?)?.toInt() ?? 0,
      topLevelDirectories:
          (json['topLevelDirectories'] as List<dynamic>? ?? <dynamic>[])
              .cast<String>(),
      fileTypeCounts:
          (json['fileTypeCounts'] as Map<String, dynamic>? ??
                  <String, dynamic>{})
              .map(
                (String key, dynamic value) =>
                    MapEntry(key, (value as num).toInt()),
              ),
      ignoredDirectories:
          (json['ignoredDirectories'] as List<dynamic>? ?? <dynamic>[])
              .cast<String>(),
      sections: (json['sections'] as List<dynamic>? ?? <dynamic>[])
          .map(
            (dynamic item) =>
                RepoSection.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      git: GitSummary.fromJson(json['git'] as Map<String, dynamic>? ?? {}),
    );
  }
}

class RepoSnapshot {
  const RepoSnapshot({
    required this.schemaVersion,
    required this.generatedAtUtc,
    required this.rootPath,
    required this.repoName,
    required this.root,
    required this.summary,
  });

  final int schemaVersion;
  final String generatedAtUtc;
  final String rootPath;
  final String repoName;
  final RepoNode root;
  final RepoSummary summary;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'generatedAtUtc': generatedAtUtc,
      'rootPath': rootPath,
      'repoName': repoName,
      'root': root.toJson(),
      'summary': summary.toJson(),
    };
  }

  factory RepoSnapshot.fromJson(Map<String, dynamic> json) {
    return RepoSnapshot(
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
      generatedAtUtc: json['generatedAtUtc'] as String,
      rootPath: json['rootPath'] as String,
      repoName: json['repoName'] as String,
      root: RepoNode.fromJson(json['root'] as Map<String, dynamic>),
      summary: RepoSummary.fromJson(json['summary'] as Map<String, dynamic>),
    );
  }

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());
}

class ScanReceipt {
  const ScanReceipt({
    required this.status,
    required this.rootPath,
    required this.outputDirectory,
    required this.scannedAtUtc,
    required this.scanDurationMs,
    required this.generatedFiles,
    required this.warnings,
  });

  final String status;
  final String rootPath;
  final String outputDirectory;
  final String scannedAtUtc;
  final int scanDurationMs;
  final List<String> generatedFiles;
  final List<String> warnings;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'status': status,
      'rootPath': rootPath,
      'outputDirectory': outputDirectory,
      'scannedAtUtc': scannedAtUtc,
      'scanDurationMs': scanDurationMs,
      'generatedFiles': generatedFiles,
      'warnings': warnings,
    };
  }

  factory ScanReceipt.fromJson(Map<String, dynamic> json) {
    return ScanReceipt(
      status: json['status'] as String,
      rootPath: json['rootPath'] as String,
      outputDirectory: json['outputDirectory'] as String,
      scannedAtUtc: json['scannedAtUtc'] as String,
      scanDurationMs: (json['scanDurationMs'] as num?)?.toInt() ?? 0,
      generatedFiles: (json['generatedFiles'] as List<dynamic>? ?? <dynamic>[])
          .cast<String>(),
      warnings: (json['warnings'] as List<dynamic>? ?? <dynamic>[])
          .cast<String>(),
    );
  }
}

class RepoScanResult {
  const RepoScanResult({
    required this.snapshot,
    required this.receipt,
    required this.treeText,
  });

  final RepoSnapshot snapshot;
  final ScanReceipt receipt;
  final String treeText;
}

String formatCompactCount(int value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}M';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)}K';
  }
  return value.toString();
}

String formatBytes(int value) {
  if (value < 1024) {
    return '$value B';
  }
  const List<String> units = <String>['KB', 'MB', 'GB', 'TB'];
  double size = value.toDouble();
  var unitIndex = -1;
  while (size >= 1024 && unitIndex < units.length - 1) {
    size /= 1024;
    unitIndex++;
  }
  return '${size.toStringAsFixed(size >= 10 ? 0 : 1)} ${units[unitIndex]}';
}
