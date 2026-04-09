# KoadMAP Plus

KoadMAP Plus is a Windows-first repository harvesting application with two operating modes:

- a headless scanner that stages structured repo artifacts
- a desktop runtime workbench for exploring the tree, grouped sections, and key insights

## Run the app

```powershell
cd G:\devops\KoadMAP_Plus
flutter run -d windows
```

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
