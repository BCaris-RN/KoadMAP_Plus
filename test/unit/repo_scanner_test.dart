import 'dart:io';

import 'package:koadmap_plus/services/repo_scanner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('scanner stages snapshot, summary, receipt, and tree output', () async {
    const RepoScanner scanner = RepoScanner();
    final String fixtureRoot = p.normalize(
      p.join(Directory.current.path, 'test', 'fixtures', 'sample_repo'),
    );
    final Directory output = await Directory.systemTemp.createTemp(
      'repo_atlas_',
    );

    try {
      final result = await scanner.scan(
        fixtureRoot,
        outputDirectory: output.path,
      );

      expect(result.snapshot.summary.totalFiles, greaterThanOrEqualTo(4));
      expect(result.snapshot.summary.totalDirectories, greaterThanOrEqualTo(2));
      expect(
        result.snapshot.summary.sections.any((section) => section.id == 'core'),
        isTrue,
      );
      expect(
        result.snapshot.summary.sections.any(
          (section) => section.id == 'quality',
        ),
        isTrue,
      );
      expect(
        File(p.join(output.path, 'repo_snapshot.json')).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(output.path, 'repo_summary.json')).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(output.path, 'scan_receipt.json')).existsSync(),
        isTrue,
      );
      expect(File(p.join(output.path, 'repo_tree.txt')).existsSync(), isTrue);
    } finally {
      if (output.existsSync()) {
        output.deleteSync(recursive: true);
      }
    }
  });
}
