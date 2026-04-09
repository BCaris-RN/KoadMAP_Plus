import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../domain/repo_models.dart';
import 'repo_analysis.dart' as analysis;

class RepoScanOptions {
  const RepoScanOptions({
    this.ignoredDirectoryNames = const <String>{
      '.git',
      '.codedrop',
      '.dart_tool',
      '.idea',
      '.gradle',
      'build',
      'dist',
      'node_modules',
      '__pycache__',
      '.venv',
      'venv',
      '.next',
      '.turbo',
      '.vs',
    },
  });

  final Set<String> ignoredDirectoryNames;
}

class RepoScanner {
  const RepoScanner();

  Future<RepoScanResult> scan(
    String rootPath, {
    String? outputDirectory,
    RepoScanOptions options = const RepoScanOptions(),
    bool writeArtifacts = true,
  }) async {
    final Stopwatch stopwatch = Stopwatch()..start();
    final String normalizedRoot = p.normalize(p.absolute(rootPath));
    final Directory rootDirectory = Directory(normalizedRoot);
    if (!rootDirectory.existsSync()) {
      throw FileSystemException('Directory does not exist', normalizedRoot);
    }

    final _ScanContext context = _ScanContext(
      rootPath: normalizedRoot,
      repoName: p.basename(normalizedRoot),
      options: options,
    );

    final RepoNode rootNode = context.scanDirectory(rootDirectory, depth: 0);
    final GitSummary git = await _readGitSummary(normalizedRoot, context);
    final RepoSummary summary = analysis.buildRepoSummary(
      rootNode,
      repoName: context.repoName,
      rootPath: context.rootPath,
      durationMs: stopwatch.elapsedMilliseconds,
      git: git,
      ignoredDirectories: List<String>.from(
        context.options.ignoredDirectoryNames,
      ),
    );
    final String scannedAtUtc = DateTime.now().toUtc().toIso8601String();
    final RepoSnapshot snapshot = RepoSnapshot(
      schemaVersion: 1,
      generatedAtUtc: scannedAtUtc,
      rootPath: normalizedRoot,
      repoName: p.basename(normalizedRoot),
      root: rootNode,
      summary: RepoSummary(
        repoName: summary.repoName,
        rootPath: summary.rootPath,
        scannedAtUtc: scannedAtUtc,
        scanDurationMs: stopwatch.elapsedMilliseconds,
        totalFiles: summary.totalFiles,
        totalDirectories: summary.totalDirectories,
        maxDepth: summary.maxDepth,
        topLevelDirectories: summary.topLevelDirectories,
        fileTypeCounts: summary.fileTypeCounts,
        ignoredDirectories: summary.ignoredDirectories,
        sections: summary.sections,
        git: summary.git,
      ),
    );

    final String treeText = analysis.buildTreeText(rootNode);
    final String artifactDirectory = p.normalize(
      outputDirectory ?? p.join(normalizedRoot, '.codedrop', 'current'),
    );

    final List<String> generatedFiles = <String>[];
    if (writeArtifacts) {
      final Directory outDir = Directory(artifactDirectory);
      outDir.createSync(recursive: true);
      final String snapshotPath = p.join(outDir.path, 'repo_snapshot.json');
      final String summaryPath = p.join(outDir.path, 'repo_summary.json');
      final String receiptPath = p.join(outDir.path, 'scan_receipt.json');
      final String treePath = p.join(outDir.path, 'repo_tree.txt');

      File(snapshotPath).writeAsStringSync(snapshot.toPrettyJson());
      File(summaryPath).writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(snapshot.summary.toJson()),
      );
      File(treePath).writeAsStringSync(treeText);
      generatedFiles.addAll(<String>[snapshotPath, summaryPath, treePath]);

      final ScanReceipt receipt = ScanReceipt(
        status: 'Staged',
        rootPath: normalizedRoot,
        outputDirectory: artifactDirectory,
        scannedAtUtc: scannedAtUtc,
        scanDurationMs: stopwatch.elapsedMilliseconds,
        generatedFiles: generatedFiles,
        warnings: context.warnings,
      );
      File(receiptPath).writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(receipt.toJson()),
      );
      generatedFiles.add(receiptPath);

      stopwatch.stop();
      return RepoScanResult(
        snapshot: snapshot,
        receipt: ScanReceipt(
          status: 'Staged',
          rootPath: normalizedRoot,
          outputDirectory: artifactDirectory,
          scannedAtUtc: scannedAtUtc,
          scanDurationMs: stopwatch.elapsedMilliseconds,
          generatedFiles: generatedFiles,
          warnings: context.warnings,
        ),
        treeText: treeText,
      );
    }

    stopwatch.stop();
    return RepoScanResult(
      snapshot: snapshot,
      receipt: ScanReceipt(
        status: 'Generated',
        rootPath: normalizedRoot,
        outputDirectory: artifactDirectory,
        scannedAtUtc: scannedAtUtc,
        scanDurationMs: stopwatch.elapsedMilliseconds,
        generatedFiles: generatedFiles,
        warnings: context.warnings,
      ),
      treeText: treeText,
    );
  }

  Future<GitSummary> _readGitSummary(
    String rootPath,
    _ScanContext context,
  ) async {
    try {
      final ProcessResult probe = await Process.run('git', <String>[
        '-C',
        rootPath,
        'rev-parse',
        '--is-inside-work-tree',
      ]);
      if (probe.exitCode != 0 ||
          probe.stdout.toString().trim().toLowerCase() != 'true') {
        return const GitSummary.empty();
      }

      final ProcessResult trackedResult = await Process.run('git', <String>[
        '-C',
        rootPath,
        'ls-files',
      ]);
      final List<String> trackedFiles = _cleanLines(
        trackedResult.stdout.toString(),
      );

      final ProcessResult statusResult = await Process.run('git', <String>[
        '-C',
        rootPath,
        'status',
        '--short',
      ]);
      final List<String> statusLines = _cleanLines(
        statusResult.stdout.toString(),
      );

      var modifiedFiles = 0;
      var stagedFiles = 0;
      var untrackedFiles = 0;
      final List<String> changedPaths = <String>[];

      for (final String line in statusLines) {
        if (line.startsWith('??')) {
          untrackedFiles++;
          changedPaths.add(line.substring(3).trim());
          continue;
        }

        if (line.length < 3) {
          continue;
        }
        final String x = line.substring(0, 1);
        final String y = line.substring(1, 2);
        final String path = line.substring(3).trim();

        if (x.trim().isNotEmpty) {
          stagedFiles++;
        }
        if (y.trim().isNotEmpty || x == 'M') {
          modifiedFiles++;
        }
        changedPaths.add(path);
      }

      return GitSummary(
        isRepository: true,
        trackedFiles: trackedFiles.length,
        modifiedFiles: modifiedFiles,
        stagedFiles: stagedFiles,
        untrackedFiles: untrackedFiles,
        changedPaths: changedPaths.take(12).toList(),
      );
    } catch (error) {
      context.warnings.add('Git scan unavailable: $error');
      return const GitSummary.empty();
    }
  }
}

class _ScanContext {
  _ScanContext({
    required this.rootPath,
    required this.repoName,
    required this.options,
  });

  final String rootPath;
  final String repoName;
  final RepoScanOptions options;
  final List<String> warnings = <String>[];

  RepoNode scanDirectory(Directory directory, {required int depth}) {
    final String relativePath = _relativePath(rootPath, directory.path);
    final List<RepoNode> children = <RepoNode>[];

    List<FileSystemEntity> entities = <FileSystemEntity>[];
    try {
      entities = directory.listSync(followLinks: false);
    } catch (error) {
      warnings.add('Unable to read $relativePath: $error');
    }

    for (final FileSystemEntity entity in entities) {
      final String name = p.basename(entity.path);
      final FileStat stat;
      try {
        stat = entity.statSync();
      } catch (error) {
        warnings.add('Unable to stat ${entity.path}: $error');
        continue;
      }

      if (stat.type == FileSystemEntityType.directory &&
          options.ignoredDirectoryNames.contains(name)) {
        continue;
      }

      if (stat.type == FileSystemEntityType.directory) {
        children.add(scanDirectory(Directory(entity.path), depth: depth + 1));
        continue;
      }

      if (stat.type == FileSystemEntityType.file) {
        final String extension = p.extension(name).toLowerCase();
        children.add(
          RepoNode(
            path: _relativePath(rootPath, entity.path),
            name: name,
            kind: RepoNodeKind.file,
            typeLabel: analysis.describeFileType(name, extension),
            extension: extension.isEmpty ? null : extension,
            sizeBytes: stat.size,
          ),
        );
        continue;
      }
    }

    children.sort((RepoNode a, RepoNode b) {
      if (a.isDirectory != b.isDirectory) {
        return a.isDirectory ? -1 : 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return RepoNode(
      path: relativePath,
      name: depth == 0 ? repoName : p.basename(directory.path),
      kind: RepoNodeKind.directory,
      typeLabel: depth == 0 ? 'Repository Root' : 'Directory',
      children: children,
    );
  }
}

class SectionAccumulator {
  SectionAccumulator(SectionMetadata metadata)
    : id = metadata.id,
      title = metadata.title,
      description = metadata.description;

  final String id;
  final String title;
  final String description;
  int fileCount = 0;
  int directoryCount = 0;
  final List<String> highlights = <String>[];
}

class SectionMetadata {
  const SectionMetadata(this.id, this.title, this.description);

  final String id;
  final String title;
  final String description;
}

List<String> _cleanLines(String input) {
  return input
      .split(RegExp(r'\r?\n'))
      .map((String line) => line.trimRight())
      .where((String line) => line.trim().isNotEmpty)
      .toList();
}

String _relativePath(String root, String entityPath) {
  final String relative = p.relative(entityPath, from: root);
  if (relative == '.') {
    return '.';
  }
  return p.posix.joinAll(p.split(relative));
}

String classifySectionId(String path) {
  if (path == '.') {
    return 'workspace';
  }

  final List<String> segments = p.posix.split(path);
  final String first = segments.first.toLowerCase();
  final String fileName = segments.last.toLowerCase();

  const Set<String> productFolders = <String>{'lib', 'src', 'bin', 'cmd'};
  const Set<String> qualityFolders = <String>{
    'test',
    'tests',
    'integration_test',
  };
  const Set<String> platformFolders = <String>{
    'android',
    'ios',
    'macos',
    'windows',
    'linux',
    'web',
  };
  const Set<String> assetFolders = <String>{'assets', 'images', 'fonts'};

  if (productFolders.contains(first)) {
    return 'core';
  }
  if (qualityFolders.contains(first)) {
    return 'quality';
  }
  if (platformFolders.contains(first)) {
    return 'platform';
  }
  if (assetFolders.contains(first)) {
    return 'assets';
  }
  if (first == '.github' ||
      fileName == 'pubspec.yaml' ||
      fileName == 'build_spec.yaml' ||
      fileName == 'analysis_options.yaml' ||
      fileName.endsWith('.json') ||
      fileName.endsWith('.yaml') ||
      fileName.endsWith('.yml')) {
    return 'control';
  }
  if (fileName == 'readme.md' ||
      fileName == 'license' ||
      fileName == 'changelog.md') {
    return 'briefing';
  }
  return 'workspace';
}

SectionMetadata metadataForSection(String id) {
  switch (id) {
    case 'briefing':
      return const SectionMetadata(
        'briefing',
        'Briefing',
        'Orientation files that explain the repository and how to use it.',
      );
    case 'core':
      return const SectionMetadata(
        'core',
        'Core Source',
        'Primary product code and runtime logic.',
      );
    case 'quality':
      return const SectionMetadata(
        'quality',
        'Quality',
        'Tests and verification surfaces that prove behavior.',
      );
    case 'platform':
      return const SectionMetadata(
        'platform',
        'Platform',
        'Platform adapters, shells, and native integration surfaces.',
      );
    case 'assets':
      return const SectionMetadata(
        'assets',
        'Assets',
        'Static media, fonts, and design resources.',
      );
    case 'control':
      return const SectionMetadata(
        'control',
        'Control Files',
        'Build, configuration, and project authority files.',
      );
    default:
      return const SectionMetadata(
        'workspace',
        'Workspace',
        'Additional files and directories that round out the repository.',
      );
  }
}

String describeFileType(String name, String extension) {
  final String lowerName = name.toLowerCase();
  switch (extension) {
    case '.dart':
      return 'Dart';
    case '.md':
      return 'Markdown';
    case '.yaml':
    case '.yml':
      return 'YAML';
    case '.json':
      return 'JSON';
    case '.kt':
      return 'Kotlin';
    case '.swift':
      return 'Swift';
    case '.java':
      return 'Java';
    case '.cc':
    case '.cpp':
    case '.c':
    case '.h':
      return 'C++';
    case '.plist':
      return 'Property List';
    case '.gradle':
    case '.kts':
      return 'Gradle';
    case '.xml':
      return 'XML';
    case '.html':
      return 'HTML';
    case '.png':
    case '.jpg':
    case '.jpeg':
    case '.webp':
    case '.gif':
      return 'Image';
    case '.ico':
      return 'Icon';
    case '.txt':
      return 'Text';
    case '.lock':
      return 'Lockfile';
  }

  if (lowerName == 'license') {
    return 'License';
  }
  if (lowerName == '.gitignore') {
    return 'Git Ignore';
  }
  if (lowerName == 'readme.md') {
    return 'Readme';
  }
  return extension.isEmpty
      ? 'File'
      : extension.replaceFirst('.', '').toUpperCase();
}

String buildTreeText(RepoNode root) {
  final StringBuffer buffer = StringBuffer();
  void writeNode(RepoNode node, String prefix, bool isLast) {
    final String connector = prefix.isEmpty ? '' : (isLast ? '└─ ' : '├─ ');
    buffer.writeln(
      '$prefix$connector${node.name}${node.isDirectory ? '/' : ''}',
    );
    final String nextPrefix = prefix.isEmpty
        ? ''
        : '$prefix${isLast ? '   ' : '│  '}';
    for (var index = 0; index < node.children.length; index++) {
      writeNode(
        node.children[index],
        nextPrefix,
        index == node.children.length - 1,
      );
    }
  }

  buffer.writeln('${root.name}/');
  for (var index = 0; index < root.children.length; index++) {
    writeNode(root.children[index], '', index == root.children.length - 1);
  }
  return buffer.toString();
}
