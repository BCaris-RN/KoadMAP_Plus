import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/repo_models.dart';
import 'repo_analysis.dart';

class GitHubRepoLoader {
  const GitHubRepoLoader();

  Future<RepoScanResult> load(String input) async {
    final GitHubTarget target = GitHubTarget.parse(input);
    final Stopwatch stopwatch = Stopwatch()..start();

    final Map<String, String> headers = <String, String>{
      'Accept': 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
    };

    final Uri repoUri = Uri.https(
      'api.github.com',
      '/repos/${target.owner}/${target.repo}',
    );
    final http.Response repoResponse = await http.get(
      repoUri,
      headers: headers,
    );
    if (repoResponse.statusCode >= 400) {
      throw Exception(
        'GitHub repository lookup failed (${repoResponse.statusCode})',
      );
    }
    final Map<String, dynamic> repoJson =
        jsonDecode(repoResponse.body) as Map<String, dynamic>;
    final String branch =
        target.branch ?? repoJson['default_branch'] as String? ?? 'main';

    final Uri treeUri = Uri.https(
      'api.github.com',
      '/repos/${target.owner}/${target.repo}/git/trees/$branch',
      <String, String>{'recursive': '1'},
    );
    final http.Response treeResponse = await http.get(
      treeUri,
      headers: headers,
    );
    if (treeResponse.statusCode >= 400) {
      throw Exception('GitHub tree lookup failed (${treeResponse.statusCode})');
    }
    final Map<String, dynamic> treeJson =
        jsonDecode(treeResponse.body) as Map<String, dynamic>;
    final List<dynamic> entries =
        treeJson['tree'] as List<dynamic>? ?? <dynamic>[];

    final _MutableNode mutableRoot = _MutableNode.directory('.', target.repo);
    for (final dynamic item in entries) {
      final Map<String, dynamic> entry = item as Map<String, dynamic>;
      final String path = entry['path'] as String? ?? '';
      final String type = entry['type'] as String? ?? '';
      if (path.isEmpty) {
        continue;
      }
      if (type == 'tree') {
        mutableRoot.ensureDirectory(path);
      } else if (type == 'blob') {
        mutableRoot.ensureFile(
          path,
          sizeBytes: (entry['size'] as num?)?.toInt() ?? 0,
        );
      }
    }

    final RepoNode rootNode = mutableRoot.toRepoNode(
      path: '.',
      name: target.repo,
    );
    final GitSummary gitSummary = GitSummary(
      isRepository: true,
      trackedFiles: rootNode
          .flatten()
          .where((RepoNode node) => !node.isDirectory)
          .length,
      modifiedFiles: 0,
      stagedFiles: 0,
      untrackedFiles: 0,
      changedPaths: const <String>[],
    );
    final List<String> warnings = <String>[
      if (treeJson['truncated'] == true)
        'GitHub API truncated the tree; very large repositories may be partial.',
    ];

    final String rootPath = 'https://github.com/${target.owner}/${target.repo}';
    final RepoSummary summary = buildRepoSummary(
      rootNode,
      repoName: target.repo,
      rootPath: rootPath,
      durationMs: stopwatch.elapsedMilliseconds,
      git: gitSummary,
      ignoredDirectories: const <String>['GitHub API mode'],
    );
    final String scannedAtUtc = DateTime.now().toUtc().toIso8601String();
    final RepoSnapshot snapshot = RepoSnapshot(
      schemaVersion: 1,
      generatedAtUtc: scannedAtUtc,
      rootPath: rootPath,
      repoName: target.repo,
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
    final String treeText = buildTreeText(rootNode);

    return RepoScanResult(
      snapshot: snapshot,
      receipt: ScanReceipt(
        status: 'Generated',
        rootPath: rootPath,
        outputDirectory: 'GitHub API / in-browser session',
        scannedAtUtc: scannedAtUtc,
        scanDurationMs: stopwatch.elapsedMilliseconds,
        generatedFiles: const <String>[
          'repo_snapshot.json',
          'repo_summary.json',
          'scan_receipt.json',
          'repo_tree.txt',
        ],
        warnings: warnings,
      ),
      treeText: treeText,
    );
  }
}

class GitHubTarget {
  const GitHubTarget({required this.owner, required this.repo, this.branch});

  final String owner;
  final String repo;
  final String? branch;

  static GitHubTarget parse(String input) {
    final String trimmed = input.trim();
    final RegExp shortPattern = RegExp(r'^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$');
    if (shortPattern.hasMatch(trimmed)) {
      final List<String> segments = trimmed.split('/');
      return GitHubTarget(owner: segments[0], repo: segments[1]);
    }

    final Uri? uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.host.contains('github.com')) {
      throw Exception(
        'Enter a GitHub repository like owner/repo or https://github.com/owner/repo',
      );
    }

    final List<String> segments = uri.pathSegments
        .where((String s) => s.isNotEmpty)
        .toList();
    if (segments.length < 2) {
      throw Exception('GitHub repository path is incomplete.');
    }

    String? branch;
    if (segments.length >= 4 && segments[2] == 'tree') {
      branch = segments.sublist(3).join('/');
    }

    return GitHubTarget(
      owner: segments[0],
      repo: segments[1].replaceAll('.git', ''),
      branch: branch,
    );
  }
}

class _MutableNode {
  _MutableNode.directory(this.segment, this.displayName)
    : isDirectory = true,
      sizeBytes = 0,
      extension = null,
      typeLabel = 'Directory';

  _MutableNode.file(
    this.segment,
    this.displayName, {
    required this.sizeBytes,
    required this.extension,
    required this.typeLabel,
  }) : isDirectory = false;

  final String segment;
  final String displayName;
  final bool isDirectory;
  final int sizeBytes;
  final String? extension;
  final String typeLabel;
  final Map<String, _MutableNode> children = <String, _MutableNode>{};

  _MutableNode ensureDirectory(String path) {
    _MutableNode current = this;
    final List<String> segments = path.split('/');
    for (final String segment in segments) {
      current = current.children.putIfAbsent(
        segment,
        () => _MutableNode.directory(segment, segment),
      );
    }
    return current;
  }

  void ensureFile(String path, {required int sizeBytes}) {
    final List<String> segments = path.split('/');
    if (segments.length > 1) {
      ensureDirectory(segments.sublist(0, segments.length - 1).join('/'));
    }
    _MutableNode current = this;
    for (var index = 0; index < segments.length - 1; index++) {
      current = current.children[segments[index]]!;
    }

    final String fileName = segments.last;
    final String extension = fileName.contains('.')
        ? '.${fileName.split('.').last.toLowerCase()}'
        : '';
    current.children[fileName] = _MutableNode.file(
      fileName,
      fileName,
      sizeBytes: sizeBytes,
      extension: extension.isEmpty ? null : extension,
      typeLabel: describeFileType(fileName, extension),
    );
  }

  RepoNode toRepoNode({required String path, required String name}) {
    final List<RepoNode> childNodes =
        children.entries
            .map(
              (MapEntry<String, _MutableNode> entry) => entry.value.toRepoNode(
                path: path == '.' ? entry.key : '$path/${entry.key}',
                name: entry.value.displayName,
              ),
            )
            .toList()
          ..sort((RepoNode a, RepoNode b) {
            if (a.isDirectory != b.isDirectory) {
              return a.isDirectory ? -1 : 1;
            }
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });

    if (isDirectory) {
      return RepoNode(
        path: path,
        name: name,
        kind: RepoNodeKind.directory,
        typeLabel: path == '.' ? 'Repository Root' : 'Directory',
        children: childNodes,
      );
    }

    return RepoNode(
      path: path,
      name: name,
      kind: RepoNodeKind.file,
      typeLabel: typeLabel,
      extension: extension,
      sizeBytes: sizeBytes,
    );
  }
}
