import 'dart:io';

import 'package:koadmap_plus/services/repo_scanner.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  String? rootPath;
  String? outputDirectory;

  for (var index = 0; index < args.length; index++) {
    final String arg = args[index];
    if (arg == '--root' && index + 1 < args.length) {
      rootPath = args[index + 1];
      index++;
      continue;
    }
    if (arg == '--out' && index + 1 < args.length) {
      outputDirectory = args[index + 1];
      index++;
    }
  }

  rootPath ??= Directory.current.path;
  outputDirectory ??= p.join(rootPath, '.codedrop', 'current');

  try {
    const RepoScanner scanner = RepoScanner();
    final result = await scanner.scan(
      rootPath,
      outputDirectory: outputDirectory,
      writeArtifacts: true,
    );

    stdout.writeln('Repo scan staged successfully.');
    stdout.writeln('Root: ${result.snapshot.rootPath}');
    stdout.writeln('Output: ${result.receipt.outputDirectory}');
    stdout.writeln(
      'Files: ${result.snapshot.summary.totalFiles}, Directories: ${result.snapshot.summary.totalDirectories}',
    );
    if (result.receipt.warnings.isNotEmpty) {
      stdout.writeln('Warnings: ${result.receipt.warnings.length}');
    }
  } catch (error, stackTrace) {
    stderr.writeln('Repo scan failed: $error');
    stderr.writeln(stackTrace);
    exitCode = 1;
  }
}
