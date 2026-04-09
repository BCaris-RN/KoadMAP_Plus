import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'domain/repo_models.dart';
import 'services/repo_scanner.dart';

void main() {
  runApp(const CodeTreeViewerApp());
}

class CodeTreeViewerApp extends StatelessWidget {
  const CodeTreeViewerApp({
    super.key,
    this.initialRootPath,
    this.autoScanOnStart = false,
  });

  final String? initialRootPath;
  final bool autoScanOnStart;

  @override
  Widget build(BuildContext context) {
    final ThemeData baseTheme = ThemeData.dark(useMaterial3: true);
    return MaterialApp(
      title: 'KoadMAP Plus',
      debugShowCheckedModeBanner: false,
      theme: baseTheme.copyWith(
        scaffoldBackgroundColor: const Color(0xFF070B11),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFD37C55),
          secondary: Color(0xFF7AD7C3),
          tertiary: Color(0xFFE6C06A),
          surface: Color(0xFF0F1622),
          error: Color(0xFFFF7B72),
        ),
      ),
      home: RepoWorkbenchPage(
        initialRootPath: initialRootPath,
        autoScanOnStart: autoScanOnStart,
      ),
    );
  }
}

class RepoWorkbenchPage extends StatefulWidget {
  const RepoWorkbenchPage({
    super.key,
    this.initialRootPath,
    this.autoScanOnStart = false,
  });

  final String? initialRootPath;
  final bool autoScanOnStart;

  @override
  State<RepoWorkbenchPage> createState() => _RepoWorkbenchPageState();
}

class _RepoWorkbenchPageState extends State<RepoWorkbenchPage> {
  final TextEditingController _rootController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final RepoScanner _scanner = const RepoScanner();

  RepoSnapshot? _snapshot;
  ScanReceipt? _receipt;
  String _treeText = '';
  String? _error;
  String? _selectedSectionId;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final String initialRoot = widget.initialRootPath ?? '';
    _rootController.text = initialRoot;
    if (widget.autoScanOnStart && initialRoot.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scanRoot(initialRoot);
      });
    }
  }

  @override
  void dispose() {
    _rootController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _browseAndScan() async {
    final String? selectedPath = await getDirectoryPath();
    if (selectedPath == null) {
      return;
    }
    _rootController.text = selectedPath;
    await _scanRoot(selectedPath);
  }

  Future<void> _scanRoot(String rootPath) async {
    final String trimmed = rootPath.trim();
    if (trimmed.isEmpty) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final RepoScanResult result = await _scanner.scan(trimmed);
      setState(() {
        _snapshot = result.snapshot;
        _receipt = result.receipt;
        _treeText = result.treeText;
        _selectedSectionId = null;
      });
    } catch (error, stackTrace) {
      stderr.writeln('Scan failed: $error\n$stackTrace');
      setState(() {
        _error = 'Scan failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final RepoSnapshot? snapshot = _snapshot;
    final RepoNode? filteredRoot = snapshot == null
        ? null
        : _filterNode(
            snapshot.root,
            query: _searchController.text.trim(),
            sectionId: _selectedSectionId,
          );

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFF081019),
              Color(0xFF101A29),
              Color(0xFF06090F),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: <Widget>[
                _CommandDeck(
                  rootController: _rootController,
                  loading: _loading,
                  error: _error,
                  onBrowse: _browseAndScan,
                  onScan: () => _scanRoot(_rootController.text),
                ),
                const SizedBox(height: 16),
                if (snapshot != null)
                  _SummaryBand(snapshot: snapshot, receipt: _receipt),
                if (snapshot == null)
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        child: _EmptyState(loading: _loading),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: LayoutBuilder(
                      builder:
                          (BuildContext context, BoxConstraints constraints) {
                            if (constraints.maxWidth >= 1220) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  SizedBox(
                                    width: 280,
                                    child: _NavigationRailPanel(
                                      snapshot: snapshot,
                                      selectedSectionId: _selectedSectionId,
                                      onSectionSelected: (String? id) {
                                        setState(() {
                                          _selectedSectionId = id;
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _TreeWorkspace(
                                      root: filteredRoot,
                                      treeText: _treeText,
                                      searchController: _searchController,
                                      onSearchChanged: () => setState(() {}),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  SizedBox(
                                    width: 320,
                                    child: _InsightPanel(
                                      snapshot: snapshot,
                                      receipt: _receipt,
                                      selectedSectionId: _selectedSectionId,
                                    ),
                                  ),
                                ],
                              );
                            }

                            return ListView(
                              children: <Widget>[
                                _NavigationRailPanel(
                                  snapshot: snapshot,
                                  selectedSectionId: _selectedSectionId,
                                  onSectionSelected: (String? id) {
                                    setState(() {
                                      _selectedSectionId = id;
                                    });
                                  },
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  height: 520,
                                  child: _TreeWorkspace(
                                    root: filteredRoot,
                                    treeText: _treeText,
                                    searchController: _searchController,
                                    onSearchChanged: () => setState(() {}),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _InsightPanel(
                                  snapshot: snapshot,
                                  receipt: _receipt,
                                  selectedSectionId: _selectedSectionId,
                                ),
                              ],
                            );
                          },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CommandDeck extends StatelessWidget {
  const _CommandDeck({
    required this.rootController,
    required this.loading,
    required this.error,
    required this.onBrowse,
    required this.onScan,
  });

  final TextEditingController rootController;
  final bool loading;
  final String? error;
  final Future<void> Function() onBrowse;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return _Surface(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'KoadMAP Plus',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'One-button repository harvesting with staged artifacts, grouped insights, and a navigable tree of every pertinent file.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF93A6BE),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x22141824),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x33D37C55)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      loading ? Icons.motion_photos_on : Icons.bolt_rounded,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      loading ? 'Scanning' : 'Operational',
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            runSpacing: 12,
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              SizedBox(
                width: 720,
                child: TextField(
                  controller: rootController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Repository root',
                    labelStyle: const TextStyle(color: Color(0xFF9CB0C7)),
                    hintText: r'G:\devops\code_tree_viewer\code_tree_viewer',
                    hintStyle: const TextStyle(color: Color(0xFF5C6B7D)),
                    filled: true,
                    fillColor: const Color(0x33131B29),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.folder_open_rounded),
                  ),
                  onSubmitted: (_) => onScan(),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: loading ? null : onBrowse,
                icon: const Icon(Icons.travel_explore_rounded),
                label: const Text('Browse'),
              ),
              FilledButton.icon(
                onPressed: loading ? null : onScan,
                icon: const Icon(Icons.radar_rounded),
                label: const Text('Ingest Folder'),
              ),
            ],
          ),
          if (error != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              error!,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.error),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryBand extends StatelessWidget {
  const _SummaryBand({required this.snapshot, required this.receipt});

  final RepoSnapshot snapshot;
  final ScanReceipt? receipt;

  @override
  Widget build(BuildContext context) {
    final RepoSummary summary = snapshot.summary;
    return _Surface(
      padding: const EdgeInsets.all(18),
      child: Wrap(
        spacing: 14,
        runSpacing: 14,
        children: <Widget>[
          _MetricChip(
            label: 'Repository',
            value: summary.repoName,
            accent: const Color(0xFFD37C55),
          ),
          _MetricChip(
            label: 'Files',
            value: formatCompactCount(summary.totalFiles),
            accent: const Color(0xFF7AD7C3),
          ),
          _MetricChip(
            label: 'Directories',
            value: formatCompactCount(summary.totalDirectories),
            accent: const Color(0xFFE6C06A),
          ),
          _MetricChip(
            label: 'Max Depth',
            value: summary.maxDepth.toString(),
            accent: const Color(0xFF87A3FF),
          ),
          _MetricChip(
            label: 'Scan Time',
            value: '${summary.scanDurationMs} ms',
            accent: const Color(0xFFC487FF),
          ),
          _MetricChip(
            label: 'Artifacts',
            value: receipt == null
                ? '0'
                : receipt!.generatedFiles.length.toString(),
            accent: const Color(0xFF5DD4FF),
          ),
        ],
      ),
    );
  }
}

class _NavigationRailPanel extends StatelessWidget {
  const _NavigationRailPanel({
    required this.snapshot,
    required this.selectedSectionId,
    required this.onSectionSelected,
  });

  final RepoSnapshot snapshot;
  final String? selectedSectionId;
  final ValueChanged<String?> onSectionSelected;

  @override
  Widget build(BuildContext context) {
    final RepoSummary summary = snapshot.summary;
    return _Surface(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Grouped Surfaces',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Filter the tree by operational concern instead of just folder depth.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF91A3B9)),
          ),
          const SizedBox(height: 16),
          _SectionButton(
            label: 'All Surfaces',
            subtitle:
                '${summary.totalFiles} files | ${summary.totalDirectories} dirs',
            selected: selectedSectionId == null,
            onTap: () => onSectionSelected(null),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.separated(
              itemCount: summary.sections.length,
              itemBuilder: (BuildContext context, int index) {
                final RepoSection section = summary.sections[index];
                return _SectionButton(
                  label: section.title,
                  subtitle:
                      '${section.fileCount} files | ${section.directoryCount} dirs',
                  selected: section.id == selectedSectionId,
                  onTap: () => onSectionSelected(section.id),
                );
              },
              separatorBuilder: (BuildContext context, int index) =>
                  const SizedBox(height: 10),
            ),
          ),
          const SizedBox(height: 16),
          Text('Top-Level', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: summary.topLevelDirectories
                .map(
                  (String item) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x2217222F),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      item,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFD6DEEA),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _TreeWorkspace extends StatelessWidget {
  const _TreeWorkspace({
    required this.root,
    required this.treeText,
    required this.searchController,
    required this.onSearchChanged,
  });

  final RepoNode? root;
  final String treeText;
  final TextEditingController searchController;
  final VoidCallback onSearchChanged;

  @override
  Widget build(BuildContext context) {
    final int visibleNodes = root == null ? 0 : root!.flatten().length - 1;
    return _Surface(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Repository Tree',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.6,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Every visible file carries its name, type, and relative location. Search prunes the tree in place.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF8EA3BC),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x22161E2B),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '$visibleNodes visible nodes',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            controller: searchController,
            onChanged: (_) => onSearchChanged(),
            decoration: InputDecoration(
              labelText: 'Search by name or path',
              filled: true,
              fillColor: const Color(0x33131B29),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              child: root == null || root!.children.isEmpty
                  ? Center(
                      key: const ValueKey<String>('empty-tree'),
                      child: Text(
                        'No files match the current search or section filter.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    )
                  : Column(
                      key: const ValueKey<String>('tree-view'),
                      children: <Widget>[
                        Expanded(
                          child: ListView.builder(
                            itemCount: root!.children.length,
                            itemBuilder: (BuildContext context, int index) {
                              final RepoNode child = root!.children[index];
                              return _RepoNodeTile(
                                node: child,
                                depth: 0,
                                forceOpen: searchController.text
                                    .trim()
                                    .isNotEmpty,
                              );
                            },
                          ),
                        ),
                        if (treeText.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 12),
                          _TextArtifactPreview(treeText: treeText),
                        ],
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightPanel extends StatelessWidget {
  const _InsightPanel({
    required this.snapshot,
    required this.receipt,
    required this.selectedSectionId,
  });

  final RepoSnapshot snapshot;
  final ScanReceipt? receipt;
  final String? selectedSectionId;

  @override
  Widget build(BuildContext context) {
    final RepoSummary summary = snapshot.summary;
    final RepoSection? selectedSection = selectedSectionId == null
        ? null
        : summary.sections
              .where((RepoSection item) => item.id == selectedSectionId)
              .firstOrNull;

    return _Surface(
      padding: const EdgeInsets.all(18),
      child: ListView(
        children: <Widget>[
          Text(
            'Insights',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Text(
            selectedSection?.description ??
                'The scanner groups the repository into meaningful operating surfaces so the first pass is useful, not just exhaustive.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF93A6BE)),
          ),
          const SizedBox(height: 18),
          _InsightBlock(
            title: selectedSection?.title ?? 'Current Focus',
            rows: <String>[
              if (selectedSection == null)
                'All surfaces are active.'
              else
                '${selectedSection.fileCount} files and ${selectedSection.directoryCount} directories in view.',
              if (selectedSection != null &&
                  selectedSection.highlights.isNotEmpty)
                'Highlights: ${selectedSection.highlights.take(4).join(' | ')}',
            ],
          ),
          const SizedBox(height: 14),
          _InsightBlock(
            title: 'Git Pulse',
            rows: summary.git.isRepository
                ? <String>[
                    '${summary.git.trackedFiles} tracked files',
                    '${summary.git.modifiedFiles} modified, ${summary.git.stagedFiles} staged, ${summary.git.untrackedFiles} untracked',
                    if (summary.git.changedPaths.isNotEmpty)
                      'Changes: ${summary.git.changedPaths.take(4).join(' | ')}',
                  ]
                : const <String>[
                    'No git repository detected in the selected root.',
                  ],
          ),
          const SizedBox(height: 14),
          _TypeHistogram(fileTypeCounts: summary.fileTypeCounts),
          const SizedBox(height: 14),
          _InsightBlock(
            title: 'Staged Output',
            rows: receipt == null
                ? const <String>['No artifacts staged yet.']
                : <String>[
                    receipt!.outputDirectory,
                    ...receipt!.generatedFiles
                        .map((String path) => path)
                        .take(4),
                    if (receipt!.warnings.isNotEmpty)
                      '${receipt!.warnings.length} warnings captured in receipt',
                  ],
          ),
          if (receipt != null && receipt!.warnings.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            _InsightBlock(
              title: 'Warnings',
              rows: receipt!.warnings.take(4).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _TextArtifactPreview extends StatelessWidget {
  const _TextArtifactPreview({required this.treeText});

  final String treeText;

  @override
  Widget build(BuildContext context) {
    final List<String> lines = treeText
        .split('\n')
        .where((String line) => line.isNotEmpty)
        .take(10)
        .toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xAA08111C),
        border: Border.all(color: const Color(0x222B415C)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Headless Export Preview',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            lines.join('\n'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontFamily: 'Consolas',
              color: const Color(0xFFC0D0E2),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _RepoNodeTile extends StatelessWidget {
  const _RepoNodeTile({
    required this.node,
    required this.depth,
    required this.forceOpen,
  });

  final RepoNode node;
  final int depth;
  final bool forceOpen;

  @override
  Widget build(BuildContext context) {
    final Color badgeColor = node.isDirectory
        ? const Color(0xFF7AD7C3)
        : const Color(0xFFD37C55);

    if (!node.isDirectory) {
      return Padding(
        padding: EdgeInsets.only(left: depth * 14.0, bottom: 6),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0x1A151D2A),
            borderRadius: BorderRadius.circular(14),
          ),
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.description_outlined),
            title: Text(node.name),
            subtitle: Text(
              node.path,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF8395AA)),
            ),
            trailing: Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                _TypeBadge(label: node.typeLabel, color: badgeColor),
                Text(
                  formatBytes(node.sizeBytes),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF90A3B8),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(left: depth * 12.0, bottom: 4),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          initiallyExpanded: forceOpen || depth < 1,
          childrenPadding: EdgeInsets.zero,
          leading: const Icon(Icons.folder_open_rounded),
          title: Text(node.name),
          subtitle: Text(
            '${node.children.length} children',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFF8395AA)),
          ),
          trailing: _TypeBadge(label: node.typeLabel, color: badgeColor),
          children: node.children
              .map(
                (RepoNode child) => _RepoNodeTile(
                  node: child,
                  depth: depth + 1,
                  forceOpen: forceOpen,
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.9, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double valueScale, Widget? child) {
        return Transform.scale(scale: valueScale, child: child);
      },
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0x22131B29),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label.toUpperCase(),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: accent,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionButton extends StatelessWidget {
  const _SectionButton({
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? const Color(0x33D37C55) : const Color(0x18131B29),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0x99D37C55) : const Color(0x221E2937),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF93A6BE)),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TypeHistogram extends StatelessWidget {
  const _TypeHistogram({required this.fileTypeCounts});

  final Map<String, int> fileTypeCounts;

  @override
  Widget build(BuildContext context) {
    final List<MapEntry<String, int>> topTypes = fileTypeCounts.entries
        .take(6)
        .toList();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x1A131B29),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Dominant File Types',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          for (final MapEntry<String, int> entry in topTypes) ...<Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    entry.key,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Text(
                  entry.value.toString(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFD37C55),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _InsightBlock extends StatelessWidget {
  const _InsightBlock({required this.title, required this.rows});

  final String title;
  final List<String> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x1A131B29),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          for (final String row in rows) ...<Widget>[
            Text(
              row,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFFC8D4E2),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xCC101928), Color(0xCC0B111C)],
        ),
        border: Border.all(color: const Color(0x332C3E57)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x66040A14),
            blurRadius: 30,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 120,
          height: 120,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: <Color>[Color(0x33D37C55), Color(0x227AD7C3)],
            ),
          ),
          child: Icon(
            loading ? Icons.radar_rounded : Icons.account_tree_outlined,
            size: 52,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 22),
        Text(
          loading
              ? 'Ingesting repository...'
              : 'Select a folder and ingest it.',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Text(
          'The scanner will stage a full snapshot, summary, receipt, and headless text tree in `.codedrop/current`.',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF93A6BE)),
        ),
      ],
    );
  }
}

RepoNode? _filterNode(
  RepoNode node, {
  required String query,
  required String? sectionId,
}) {
  final String lowerQuery = query.toLowerCase();
  final bool queryMatches =
      lowerQuery.isEmpty ||
      node.name.toLowerCase().contains(lowerQuery) ||
      node.path.toLowerCase().contains(lowerQuery);

  if (!node.isDirectory) {
    final bool sectionMatches =
        sectionId == null || classifySectionId(node.path) == sectionId;
    return queryMatches && sectionMatches ? node : null;
  }

  final List<RepoNode> children = node.children
      .map(
        (RepoNode child) =>
            _filterNode(child, query: query, sectionId: sectionId),
      )
      .whereType<RepoNode>()
      .toList();

  if (node.path == '.') {
    return RepoNode(
      path: node.path,
      name: node.name,
      kind: node.kind,
      typeLabel: node.typeLabel,
      children: children,
    );
  }

  final bool sectionMatches =
      sectionId == null || classifySectionId(node.path) == sectionId;
  if (children.isEmpty && !(queryMatches && sectionMatches)) {
    return null;
  }

  return RepoNode(
    path: node.path,
    name: node.name,
    kind: node.kind,
    typeLabel: node.typeLabel,
    children: children,
  );
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
