import '../domain/repo_models.dart';

RepoSummary buildRepoSummary(
  RepoNode rootNode, {
  required String repoName,
  required String rootPath,
  required int durationMs,
  required GitSummary git,
  required List<String> ignoredDirectories,
}) {
  final Map<String, int> fileTypeCounts = <String, int>{};
  final Map<String, _SectionAccumulator> sections =
      <String, _SectionAccumulator>{};
  var totalFiles = 0;
  var totalDirectories = 0;
  var maxDepth = 0;

  void walk(RepoNode node, int depth) {
    if (depth > maxDepth) {
      maxDepth = depth;
    }
    if (node.path != '.') {
      final String sectionId = classifySectionId(node.path);
      final _SectionAccumulator section = sections.putIfAbsent(
        sectionId,
        () => _SectionAccumulator(_metadataForSection(sectionId)),
      );
      if (node.isDirectory) {
        totalDirectories++;
        section.directoryCount++;
      } else {
        totalFiles++;
        section.fileCount++;
        fileTypeCounts.update(
          node.typeLabel,
          (int value) => value + 1,
          ifAbsent: () => 1,
        );
      }
      if (section.highlights.length < 6) {
        section.highlights.add(node.path);
      }
    }
    for (final RepoNode child in node.children) {
      walk(child, depth + 1);
    }
  }

  walk(rootNode, 0);

  final List<RepoSection> sectionList =
      sections.values
          .map(
            (_SectionAccumulator item) => RepoSection(
              id: item.id,
              title: item.title,
              description: item.description,
              fileCount: item.fileCount,
              directoryCount: item.directoryCount,
              highlights: item.highlights,
            ),
          )
          .toList()
        ..sort((RepoSection a, RepoSection b) {
          final int delta = (b.fileCount + b.directoryCount).compareTo(
            a.fileCount + a.directoryCount,
          );
          if (delta != 0) {
            return delta;
          }
          return a.title.compareTo(b.title);
        });

  final List<String> topDirectories =
      rootNode.children
          .where((RepoNode child) => child.isDirectory)
          .map((RepoNode child) => child.name)
          .toList()
        ..sort();

  final Map<String, int> sortedTypes = Map<String, int>.fromEntries(
    fileTypeCounts.entries.toList()
      ..sort((MapEntry<String, int> a, MapEntry<String, int> b) {
        final int delta = b.value.compareTo(a.value);
        if (delta != 0) {
          return delta;
        }
        return a.key.compareTo(b.key);
      }),
  );
  final List<String> sortedIgnoredDirectories = List<String>.from(
    ignoredDirectories,
  )..sort();

  return RepoSummary(
    repoName: repoName,
    rootPath: rootPath,
    scannedAtUtc: DateTime.now().toUtc().toIso8601String(),
    scanDurationMs: durationMs,
    totalFiles: totalFiles,
    totalDirectories: totalDirectories,
    maxDepth: maxDepth,
    topLevelDirectories: topDirectories,
    fileTypeCounts: sortedTypes,
    ignoredDirectories: sortedIgnoredDirectories,
    sections: sectionList,
    git: git,
  );
}

String classifySectionId(String path) {
  if (path == '.') {
    return 'workspace';
  }

  final List<String> segments = path.split('/');
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
    final String connector = prefix.isEmpty ? '' : (isLast ? '\\- ' : '|- ');
    buffer.writeln(
      '$prefix$connector${node.name}${node.isDirectory ? '/' : ''}',
    );
    final String nextPrefix = prefix.isEmpty
        ? ''
        : '$prefix${isLast ? '   ' : '|  '}';
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

class _SectionAccumulator {
  _SectionAccumulator(_SectionMetadata metadata)
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

class _SectionMetadata {
  const _SectionMetadata(this.id, this.title, this.description);

  final String id;
  final String title;
  final String description;
}

_SectionMetadata _metadataForSection(String id) {
  switch (id) {
    case 'briefing':
      return const _SectionMetadata(
        'briefing',
        'Briefing',
        'Orientation files that explain the repository and how to use it.',
      );
    case 'core':
      return const _SectionMetadata(
        'core',
        'Core Source',
        'Primary product code and runtime logic.',
      );
    case 'quality':
      return const _SectionMetadata(
        'quality',
        'Quality',
        'Tests and verification surfaces that prove behavior.',
      );
    case 'platform':
      return const _SectionMetadata(
        'platform',
        'Platform',
        'Platform adapters, shells, and native integration surfaces.',
      );
    case 'assets':
      return const _SectionMetadata(
        'assets',
        'Assets',
        'Static media, fonts, and design resources.',
      );
    case 'control':
      return const _SectionMetadata(
        'control',
        'Control Files',
        'Build, configuration, and project authority files.',
      );
    default:
      return const _SectionMetadata(
        'workspace',
        'Workspace',
        'Additional files and directories that round out the repository.',
      );
  }
}
