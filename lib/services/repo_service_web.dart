import '../domain/repo_models.dart';
import 'repo_github_loader.dart';

class RepoService {
  const RepoService();

  bool get supportsLocalFolders => false;

  Future<RepoScanResult> load(String input) {
    return const GitHubRepoLoader().load(input.trim());
  }
}
