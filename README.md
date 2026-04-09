# KoadMAP Plus

KoadMAP Plus is a Windows-first repository harvesting application with two operating modes:

- a headless scanner that stages structured repo artifacts
- a desktop and web runtime workbench for exploring the tree, grouped sections, and key insights

The current release opens directly into the workbench in guest mode so desktop and GitHub Pages stay frictionless.

## Run the app

```powershell
cd G:\devops\KoadMAP_Plus
flutter run -d windows
```

Desktop mode supports:

- local folder browsing
- direct path entry
- GitHub repository input such as `owner/repo` or `https://github.com/owner/repo`

## Run the web app locally

```powershell
cd G:\devops\KoadMAP_Plus
flutter run -d chrome
```

Web mode is GitHub-backed. Paste a repository like `BCaris-RN/KoadMAP_Plus` or a full GitHub URL into the target field and analyze it in-browser.

## Build for GitHub Pages

```powershell
cd G:\devops\KoadMAP_Plus
flutter build web --release --base-href /KoadMAP_Plus/
```

The repo now includes a GitHub Pages workflow at `.github/workflows/deploy-pages.yml`. Push to `main` or run the workflow manually to publish the latest web build.

## Run the headless scanner

```powershell
cd G:\devops\KoadMAP_Plus
dart run .\tool\repo_scan.dart --root G:\devops\KoadMAP_Plus
```

Artifacts are staged under `.codedrop/current`:

- `repo_snapshot.json`
- `repo_summary.json`
- `scan_receipt.json`
- `repo_tree.txt`
