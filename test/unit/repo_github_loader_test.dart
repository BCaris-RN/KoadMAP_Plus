import 'package:flutter_test/flutter_test.dart';
import 'package:koadmap_plus/services/repo_github_loader.dart';

void main() {
  test('parses short github repository syntax', () {
    final GitHubTarget target = GitHubTarget.parse('BCaris-RN/KoadMAP_Plus');

    expect(target.owner, 'BCaris-RN');
    expect(target.repo, 'KoadMAP_Plus');
    expect(target.branch, isNull);
  });

  test('parses full github url with branch path', () {
    final GitHubTarget target = GitHubTarget.parse(
      'https://github.com/BCaris-RN/KoadMAP_Plus/tree/main',
    );

    expect(target.owner, 'BCaris-RN');
    expect(target.repo, 'KoadMAP_Plus');
    expect(target.branch, 'main');
  });

  test('rejects invalid github input', () {
    expect(() => GitHubTarget.parse('not a repo'), throwsA(isA<Exception>()));
  });
}
