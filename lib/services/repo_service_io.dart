import '../domain/repo_models.dart';
import 'repo_github_loader.dart';
import 'repo_scanner.dart';

class RepoService {
  const RepoService();

  bool get supportsLocalFolders => true;

  Future<RepoScanResult> load(String input) async {
    final String trimmed = input.trim();
    if (_looksLikeGitHubInput(trimmed)) {
      return const GitHubRepoLoader().load(trimmed);
    }
    return const RepoScanner().scan(trimmed);
  }
}

bool _looksLikeGitHubInput(String input) {
  return input.startsWith('https://github.com/') ||
      RegExp(r'^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$').hasMatch(input);
}
