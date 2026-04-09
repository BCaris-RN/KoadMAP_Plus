import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'domain/operator_session.dart';
import 'domain/repo_models.dart';
import 'services/repo_analysis.dart';
import 'services/repo_service.dart';
import 'services/session_store.dart';

void main() {
  runApp(const CodeTreeViewerApp());
}

class CodeTreeViewerApp extends StatelessWidget {
  const CodeTreeViewerApp({
    super.key,
    this.initialRootPath,
    this.autoScanOnStart = false,
    this.initialSession,
    this.sessionStore = const SessionStore(),
  });

  final String? initialRootPath;
  final bool autoScanOnStart;
  final OperatorSession? initialSession;
  final SessionStore sessionStore;

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
      home: _AppBootstrap(
        initialRootPath: initialRootPath,
        autoScanOnStart: autoScanOnStart,
        initialSession: initialSession,
        sessionStore: sessionStore,
      ),
    );
  }
}

class _AppBootstrap extends StatefulWidget {
  const _AppBootstrap({
    required this.initialRootPath,
    required this.autoScanOnStart,
    required this.initialSession,
    required this.sessionStore,
  });

  final String? initialRootPath;
  final bool autoScanOnStart;
  final OperatorSession? initialSession;
  final SessionStore sessionStore;

  @override
  State<_AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<_AppBootstrap> {
  OperatorSession? _session;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    if (widget.initialSession != null) {
      setState(() {
        _session = widget.initialSession;
        _loading = false;
      });
      return;
    }

    final OperatorSession? session = await widget.sessionStore.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _session = session;
      _loading = false;
    });
  }

  Future<void> _createSession(AccessDraft draft) async {
    final OperatorSession session = await widget.sessionStore.create(draft);
    if (!mounted) {
      return;
    }
    setState(() {
      _session = session;
    });
  }

  Future<void> _recordScan(String target) async {
    final OperatorSession? current = _session;
    if (current == null) {
      return;
    }
    final OperatorSession updated = await widget.sessionStore.recordScan(
      current,
      target: target,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _session = updated;
    });
  }

  Future<void> _logout() async {
    await widget.sessionStore.clear();
    if (!mounted) {
      return;
    }
    setState(() {
      _session = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const _LaunchScreen();
    }

    if (_session == null) {
      return _AccessSplash(onContinue: _createSession);
    }

    return RepoWorkbenchPage(
      initialRootPath: widget.initialRootPath,
      autoScanOnStart: widget.autoScanOnStart,
      session: _session!,
      onLogout: _logout,
      onScanTracked: _recordScan,
    );
  }
}

class _LaunchScreen extends StatelessWidget {
  const _LaunchScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.4,
            colors: <Color>[
              Color(0xFF19304A),
              Color(0xFF0A111B),
              Color(0xFF04070C),
            ],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                width: 72,
                height: 72,
                child: CircularProgressIndicator(strokeWidth: 3.4),
              ),
              SizedBox(height: 18),
              Text(
                'Initializing KoadMAP Plus',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccessSplash extends StatefulWidget {
  const _AccessSplash({required this.onContinue});

  final Future<void> Function(AccessDraft draft) onContinue;

  @override
  State<_AccessSplash> createState() => _AccessSplashState();
}

class _AccessSplashState extends State<_AccessSplash> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _organizationController = TextEditingController();
  bool _marketingOptIn = true;
  bool _analyticsOptIn = true;
  bool _usageOptIn = true;
  bool _submitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _organizationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      await widget.onContinue(
        AccessDraft(
          email: _emailController.text.trim(),
          fullName: _nameController.text.trim(),
          organization: _organizationController.text.trim(),
          marketingOptIn: _marketingOptIn,
          analyticsOptIn: _analyticsOptIn,
          usageOptIn: _usageOptIn,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFF050811),
              Color(0xFF0D1725),
              Color(0xFF05070B),
            ],
          ),
        ),
        child: Stack(
          children: <Widget>[
            Positioned(
              top: -80,
              left: -60,
              child: Container(
                width: 320,
                height: 320,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[Color(0x55D37C55), Color(0x0010181F)],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -120,
              right: -40,
              child: Container(
                width: 380,
                height: 380,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[Color(0x337AD7C3), Color(0x00070B11)],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.94, end: 1),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    builder:
                        (BuildContext context, double value, Widget? child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, (1 - value) * 28),
                              child: child,
                            ),
                          );
                        },
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1220),
                      child: LayoutBuilder(
                        builder:
                            (BuildContext context, BoxConstraints constraints) {
                              final bool compact = constraints.maxWidth < 980;
                              return compact
                                  ? Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        _AccessHero(compact: true),
                                        const SizedBox(height: 20),
                                        _AccessPanel(
                                          formKey: _formKey,
                                          emailController: _emailController,
                                          nameController: _nameController,
                                          organizationController:
                                              _organizationController,
                                          marketingOptIn: _marketingOptIn,
                                          analyticsOptIn: _analyticsOptIn,
                                          usageOptIn: _usageOptIn,
                                          submitting: _submitting,
                                          onMarketingChanged: (bool value) =>
                                              setState(() {
                                                _marketingOptIn = value;
                                              }),
                                          onAnalyticsChanged: (bool value) =>
                                              setState(() {
                                                _analyticsOptIn = value;
                                              }),
                                          onUsageChanged: (bool value) =>
                                              setState(() {
                                                _usageOptIn = value;
                                              }),
                                          onSubmit: _submit,
                                        ),
                                      ],
                                    )
                                  : Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: <Widget>[
                                        const Expanded(
                                          flex: 6,
                                          child: _AccessHero(compact: false),
                                        ),
                                        const SizedBox(width: 24),
                                        Expanded(
                                          flex: 5,
                                          child: _AccessPanel(
                                            formKey: _formKey,
                                            emailController: _emailController,
                                            nameController: _nameController,
                                            organizationController:
                                                _organizationController,
                                            marketingOptIn: _marketingOptIn,
                                            analyticsOptIn: _analyticsOptIn,
                                            usageOptIn: _usageOptIn,
                                            submitting: _submitting,
                                            onMarketingChanged: (bool value) =>
                                                setState(() {
                                                  _marketingOptIn = value;
                                                }),
                                            onAnalyticsChanged: (bool value) =>
                                                setState(() {
                                                  _analyticsOptIn = value;
                                                }),
                                            onUsageChanged: (bool value) =>
                                                setState(() {
                                                  _usageOptIn = value;
                                                }),
                                            onSubmit: _submit,
                                          ),
                                        ),
                                      ],
                                    );
                            },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RepoWorkbenchPage extends StatefulWidget {
  const RepoWorkbenchPage({
    super.key,
    this.initialRootPath,
    this.autoScanOnStart = false,
    required this.session,
    required this.onLogout,
    required this.onScanTracked,
  });

  final String? initialRootPath;
  final bool autoScanOnStart;
  final OperatorSession session;
  final Future<void> Function() onLogout;
  final Future<void> Function(String target) onScanTracked;

  @override
  State<RepoWorkbenchPage> createState() => _RepoWorkbenchPageState();
}

class _RepoWorkbenchPageState extends State<RepoWorkbenchPage> {
  final TextEditingController _rootController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final RepoService _repoService = const RepoService();

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
    if (!_repoService.supportsLocalFolders) {
      return;
    }
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
      final RepoScanResult result = await _repoService.load(trimmed);
      await widget.onScanTracked(trimmed);
      setState(() {
        _snapshot = result.snapshot;
        _receipt = result.receipt;
        _treeText = result.treeText;
        _selectedSectionId = null;
      });
    } catch (error, stackTrace) {
      debugPrint('Scan failed: $error\n$stackTrace');
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

  Future<void> _copyText(String label, String text) async {
    if (text.trim().isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label copied to clipboard')));
  }

  String _buildSummaryClipboardText(
    RepoSnapshot snapshot,
    ScanReceipt? receipt,
  ) {
    final RepoSummary summary = snapshot.summary;
    final StringBuffer buffer = StringBuffer()
      ..writeln('Repository: ${summary.repoName}')
      ..writeln('Root: ${summary.rootPath}')
      ..writeln('Files: ${summary.totalFiles}')
      ..writeln('Directories: ${summary.totalDirectories}')
      ..writeln('Max Depth: ${summary.maxDepth}')
      ..writeln('Scan Time: ${summary.scanDurationMs} ms')
      ..writeln()
      ..writeln('Sections:');

    for (final RepoSection section in summary.sections) {
      buffer.writeln(
        '- ${section.title}: ${section.fileCount} files, ${section.directoryCount} dirs',
      );
    }

    if (receipt != null) {
      buffer
        ..writeln()
        ..writeln('Artifacts:')
        ..writeln('Output: ${receipt.outputDirectory}');
      for (final String path in receipt.generatedFiles) {
        buffer.writeln('- $path');
      }
    }

    return buffer.toString();
  }

  String _buildArtifactClipboardText(ScanReceipt? receipt) {
    if (receipt == null) {
      return '';
    }
    final StringBuffer buffer = StringBuffer()
      ..writeln('Output: ${receipt.outputDirectory}');
    for (final String path in receipt.generatedFiles) {
      buffer.writeln(path);
    }
    return buffer.toString();
  }

  String _buildReviewPackText(
    RepoSnapshot snapshot,
    ScanReceipt? receipt,
    String visibleTreeText,
  ) {
    final StringBuffer buffer = StringBuffer()
      ..writeln(_buildSummaryClipboardText(snapshot, receipt).trim())
      ..writeln()
      ..writeln('Visible Tree:')
      ..writeln(visibleTreeText.trim());

    final String artifactText = _buildArtifactClipboardText(receipt).trim();
    if (artifactText.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Artifacts:')
        ..writeln(artifactText);
    }
    return buffer.toString().trim();
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
    final String visibleTreeText = filteredRoot == null
        ? ''
        : buildTreeText(filteredRoot);

    return Scaffold(
      body: SelectionArea(
        child: Container(
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
                    session: widget.session,
                    supportsLocalFolders: _repoService.supportsLocalFolders,
                    loading: _loading,
                    error: _error,
                    onBrowse: _browseAndScan,
                    onScan: () => _scanRoot(_rootController.text),
                    onLogout: widget.onLogout,
                    onCopyEmail: () => _copyText('Email', widget.session.email),
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
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: <Widget>[
                                    SizedBox(
                                      width: 280,
                                      child: _NavigationRailPanel(
                                        compact: false,
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
                                        compact: false,
                                        root: filteredRoot,
                                        treeText: _treeText,
                                        visibleTreeText: visibleTreeText,
                                        searchController: _searchController,
                                        onSearchChanged: () => setState(() {}),
                                        onCopyText: _copyText,
                                        onCopySummary: () => _copyText(
                                          'Summary',
                                          _buildSummaryClipboardText(
                                            snapshot,
                                            _receipt,
                                          ),
                                        ),
                                        onCopyArtifacts: () => _copyText(
                                          'Artifacts',
                                          _buildArtifactClipboardText(_receipt),
                                        ),
                                        onCopyReviewPack: () => _copyText(
                                          'Review pack',
                                          _buildReviewPackText(
                                            snapshot,
                                            _receipt,
                                            visibleTreeText,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    SizedBox(
                                      width: 320,
                                      child: _InsightPanel(
                                        compact: false,
                                        snapshot: snapshot,
                                        receipt: _receipt,
                                        selectedSectionId: _selectedSectionId,
                                      ),
                                    ),
                                  ],
                                );
                              }

                              return Scrollbar(
                                thumbVisibility: true,
                                child: ListView(
                                  padding: EdgeInsets.zero,
                                  children: <Widget>[
                                    _NavigationRailPanel(
                                      compact: true,
                                      snapshot: snapshot,
                                      selectedSectionId: _selectedSectionId,
                                      onSectionSelected: (String? id) {
                                        setState(() {
                                          _selectedSectionId = id;
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    _TreeWorkspace(
                                      compact: true,
                                      root: filteredRoot,
                                      treeText: _treeText,
                                      visibleTreeText: visibleTreeText,
                                      searchController: _searchController,
                                      onSearchChanged: () => setState(() {}),
                                      onCopyText: _copyText,
                                      onCopySummary: () => _copyText(
                                        'Summary',
                                        _buildSummaryClipboardText(
                                          snapshot,
                                          _receipt,
                                        ),
                                      ),
                                      onCopyArtifacts: () => _copyText(
                                        'Artifacts',
                                        _buildArtifactClipboardText(_receipt),
                                      ),
                                      onCopyReviewPack: () => _copyText(
                                        'Review pack',
                                        _buildReviewPackText(
                                          snapshot,
                                          _receipt,
                                          visibleTreeText,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    _InsightPanel(
                                      compact: true,
                                      snapshot: snapshot,
                                      receipt: _receipt,
                                      selectedSectionId: _selectedSectionId,
                                    ),
                                  ],
                                ),
                              );
                            },
                      ),
                    ),
                ],
              ),
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
    required this.session,
    required this.supportsLocalFolders,
    required this.loading,
    required this.error,
    required this.onBrowse,
    required this.onScan,
    required this.onLogout,
    required this.onCopyEmail,
  });

  final TextEditingController rootController;
  final OperatorSession session;
  final bool supportsLocalFolders;
  final bool loading;
  final String? error;
  final Future<void> Function() onBrowse;
  final VoidCallback onScan;
  final Future<void> Function() onLogout;
  final VoidCallback onCopyEmail;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return _Surface(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool compact = constraints.maxWidth < 980;
          final Widget statusChip = Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
          );
          final Widget accountChip = Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0x1C7AD7C3),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0x3358D6C6)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF142434),
                    border: Border.all(color: const Color(0x44FFFFFF)),
                  ),
                  child: const Icon(Icons.lock_person_rounded, size: 18),
                ),
                const SizedBox(width: 10),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      session.displayName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      session.email,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF99B6D2),
                      ),
                    ),
                  ],
                ),
                PopupMenuButton<String>(
                  tooltip: 'Session options',
                  onSelected: (String value) {
                    switch (value) {
                      case 'copy':
                        onCopyEmail();
                        break;
                      case 'logout':
                        onLogout();
                        break;
                    }
                  },
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<String>>[
                        const PopupMenuItem<String>(
                          value: 'copy',
                          child: Text('Copy email'),
                        ),
                        const PopupMenuItem<String>(
                          value: 'logout',
                          child: Text('Log out'),
                        ),
                      ],
                ),
              ],
            ),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (compact)
                Column(
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
                    const SizedBox(height: 14),
                    _OperatorTelemetryStrip(session: session),
                    const SizedBox(height: 16),
                    statusChip,
                    const SizedBox(height: 12),
                    accountChip,
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'KoadMAP Plus',
                            style: Theme.of(context).textTheme.displaySmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -1.2,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'One-button repository harvesting with staged artifacts, grouped insights, and a navigable tree of every pertinent file.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: const Color(0xFF93A6BE)),
                          ),
                          const SizedBox(height: 14),
                          _OperatorTelemetryStrip(session: session),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        statusChip,
                        const SizedBox(height: 10),
                        accountChip,
                      ],
                    ),
                  ],
                ),
              const SizedBox(height: 18),
              if (compact)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    TextField(
                      controller: rootController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Repository target',
                        labelStyle: const TextStyle(color: Color(0xFF9CB0C7)),
                        hintText: supportsLocalFolders
                            ? r'G:\devops\KoadMAP_Plus or owner/repo'
                            : 'owner/repo or https://github.com/owner/repo',
                        hintStyle: const TextStyle(color: Color(0xFF5C6B7D)),
                        filled: true,
                        fillColor: const Color(0x33131B29),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: Icon(
                          supportsLocalFolders
                              ? Icons.folder_open_rounded
                              : Icons.public_rounded,
                        ),
                      ),
                      onSubmitted: (_) => onScan(),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: <Widget>[
                        if (supportsLocalFolders)
                          FilledButton.tonalIcon(
                            onPressed: loading ? null : onBrowse,
                            icon: const Icon(Icons.travel_explore_rounded),
                            label: const Text('Browse'),
                          ),
                        FilledButton.icon(
                          onPressed: loading ? null : onScan,
                          icon: const Icon(Icons.radar_rounded),
                          label: Text(
                            supportsLocalFolders
                                ? 'Ingest Target'
                                : 'Analyze Repo',
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              else
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
                          labelText: 'Repository target',
                          labelStyle: const TextStyle(color: Color(0xFF9CB0C7)),
                          hintText: supportsLocalFolders
                              ? r'G:\devops\KoadMAP_Plus or owner/repo'
                              : 'owner/repo or https://github.com/owner/repo',
                          hintStyle: const TextStyle(color: Color(0xFF5C6B7D)),
                          filled: true,
                          fillColor: const Color(0x33131B29),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: Icon(
                            supportsLocalFolders
                                ? Icons.folder_open_rounded
                                : Icons.public_rounded,
                          ),
                        ),
                        onSubmitted: (_) => onScan(),
                      ),
                    ),
                    if (supportsLocalFolders)
                      FilledButton.tonalIcon(
                        onPressed: loading ? null : onBrowse,
                        icon: const Icon(Icons.travel_explore_rounded),
                        label: const Text('Browse'),
                      ),
                    FilledButton.icon(
                      onPressed: loading ? null : onScan,
                      icon: const Icon(Icons.radar_rounded),
                      label: Text(
                        supportsLocalFolders ? 'Ingest Target' : 'Analyze Repo',
                      ),
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
          );
        },
      ),
    );
  }
}

class _OperatorTelemetryStrip extends StatelessWidget {
  const _OperatorTelemetryStrip({required this.session});

  final OperatorSession session;

  @override
  Widget build(BuildContext context) {
    final List<String> flags = <String>[
      if (session.marketingOptIn) 'marketing',
      if (session.analyticsOptIn) 'analytics',
      if (session.usageOptIn) 'usage',
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        _MiniPill(
          label: '${session.scansRun} scans tracked',
          accent: const Color(0xFFD37C55),
        ),
        _MiniPill(
          label: flags.isEmpty ? 'no active consents' : flags.join(' + '),
          accent: const Color(0xFF7AD7C3),
        ),
        if (session.organization.trim().isNotEmpty)
          _MiniPill(
            label: session.organization.trim(),
            accent: const Color(0xFFE6C06A),
          ),
      ],
    );
  }
}

class _AccessHero extends StatelessWidget {
  const _AccessHero({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(0, compact ? 6 : 24, compact ? 0 : 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0x2217222E),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0x333A536D)),
            ),
            child: Text(
              'Repository intelligence, operator-first access',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: const Color(0xFFBFD1E7),
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'KoadMAP Plus',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: -2.4,
              height: 0.94,
            ),
          ),
          const SizedBox(height: 18),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Text(
              'Sign in once, capture the operator profile, then move from folder ingest to grouped repo review without losing context.',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFF9CB0C7),
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 30),
          const _AccessMetricRow(),
          const SizedBox(height: 26),
          const _AccessFeatureList(),
        ],
      ),
    );
  }
}

class _AccessMetricRow extends StatelessWidget {
  const _AccessMetricRow();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: const <Widget>[
        _HeroStat(label: 'Workflow', value: 'Splash -> Access -> Review'),
        _HeroStat(
          label: 'Signals',
          value: 'Email, marketing, analytics, usage',
        ),
        _HeroStat(label: 'Targets', value: 'Folders + GitHub repos'),
      ],
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x161A2532),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x223D536B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: const Color(0xFFD37C55),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccessFeatureList extends StatelessWidget {
  const _AccessFeatureList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const <Widget>[
        _FeatureLine(
          index: '01',
          title: 'Identity-backed workspace',
          body:
              'Persist the operator, their team, and consent state before scanning begins.',
        ),
        _FeatureLine(
          index: '02',
          title: 'Marketing-ready capture',
          body:
              'Collect email plus opt-ins so product follow-up and reporting can grow later.',
        ),
        _FeatureLine(
          index: '03',
          title: 'Analytics-aware usage',
          body:
              'Track session activity locally now, ready to forward to real telemetry later.',
        ),
      ],
    );
  }
}

class _FeatureLine extends StatelessWidget {
  const _FeatureLine({
    required this.index,
    required this.title,
    required this.body,
  });

  final String index;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 44,
            child: Text(
              index,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: const Color(0x66FFFFFF),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF95A8BF),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccessPanel extends StatelessWidget {
  const _AccessPanel({
    required this.formKey,
    required this.emailController,
    required this.nameController,
    required this.organizationController,
    required this.marketingOptIn,
    required this.analyticsOptIn,
    required this.usageOptIn,
    required this.submitting,
    required this.onMarketingChanged,
    required this.onAnalyticsChanged,
    required this.onUsageChanged,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController nameController;
  final TextEditingController organizationController;
  final bool marketingOptIn;
  final bool analyticsOptIn;
  final bool usageOptIn;
  final bool submitting;
  final ValueChanged<bool> onMarketingChanged;
  final ValueChanged<bool> onAnalyticsChanged;
  final ValueChanged<bool> onUsageChanged;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      padding: const EdgeInsets.all(22),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Log in to the workspace',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Capture the operator profile once. KoadMAP Plus will reuse it for access, telemetry posture, and future outbound workflows.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF93A6BE),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            _AccessInput(
              controller: emailController,
              label: 'Email',
              hintText: 'operator@company.com',
              keyboardType: TextInputType.emailAddress,
              validator: (String? value) {
                final String email = value?.trim() ?? '';
                final RegExp pattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                if (!pattern.hasMatch(email)) {
                  return 'Enter a valid email address.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _AccessInput(
              controller: nameController,
              label: 'Full name',
              hintText: 'Optional',
            ),
            const SizedBox(height: 12),
            _AccessInput(
              controller: organizationController,
              label: 'Organization',
              hintText: 'Team or company',
            ),
            const SizedBox(height: 18),
            Text(
              'Consent posture',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            _ConsentTile(
              value: marketingOptIn,
              title: 'Marketing contact',
              subtitle: 'Allow release notes, feature notices, and follow-up.',
              onChanged: onMarketingChanged,
            ),
            _ConsentTile(
              value: analyticsOptIn,
              title: 'Analytics',
              subtitle: 'Allow anonymous product behavior measurement.',
              onChanged: onAnalyticsChanged,
            ),
            _ConsentTile(
              value: usageOptIn,
              title: 'Usage telemetry',
              subtitle:
                  'Track scans, targets, and operator activity locally for reporting.',
              onChanged: onUsageChanged,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0x1A142231),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x22324A61)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(
                    Icons.privacy_tip_outlined,
                    color: Color(0xFF7AD7C3),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'This release stores access state locally so desktop and GitHub Pages can work without backend setup. The session model is ready for a real auth or CRM handoff later.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF9AB3C8),
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: submitting ? null : () => onSubmit(),
                icon: Icon(
                  submitting
                      ? Icons.hourglass_top_rounded
                      : Icons.login_rounded,
                ),
                label: Text(
                  submitting ? 'Opening workspace' : 'Log in and continue',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccessInput extends StatelessWidget {
  const _AccessInput({
    required this.controller,
    required this.label,
    required this.hintText,
    this.keyboardType,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        labelStyle: const TextStyle(color: Color(0xFF9CB0C7)),
        hintStyle: const TextStyle(color: Color(0xFF5C6B7D)),
        filled: true,
        fillColor: const Color(0x33131B29),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _ConsentTile extends StatelessWidget {
  const _ConsentTile({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.onChanged,
  });

  final bool value;
  final String title;
  final String subtitle;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0x161A2532),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x22374A5F)),
      ),
      child: CheckboxListTile(
        value: value,
        onChanged: (bool? next) => onChanged(next ?? false),
        checkboxShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
        title: Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: const Color(0xFF91A4BB)),
        ),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
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
    required this.compact,
    required this.snapshot,
    required this.selectedSectionId,
    required this.onSectionSelected,
  });

  final bool compact;
  final RepoSnapshot snapshot;
  final String? selectedSectionId;
  final ValueChanged<String?> onSectionSelected;

  @override
  Widget build(BuildContext context) {
    final RepoSummary summary = snapshot.summary;
    final List<Widget> sectionButtons = <Widget>[
      _SectionButton(
        label: 'All Surfaces',
        subtitle:
            '${summary.totalFiles} files | ${summary.totalDirectories} dirs',
        selected: selectedSectionId == null,
        onTap: () => onSectionSelected(null),
      ),
      ...summary.sections.map(
        (RepoSection section) => _SectionButton(
          label: section.title,
          subtitle:
              '${section.fileCount} files | ${section.directoryCount} dirs',
          selected: section.id == selectedSectionId,
          onTap: () => onSectionSelected(section.id),
        ),
      ),
    ];
    return _Surface(
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
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
          if (compact)
            ...sectionButtons.map(
              (Widget button) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: button,
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: sectionButtons.length,
                itemBuilder: (BuildContext context, int index) {
                  return sectionButtons[index];
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
    required this.compact,
    required this.root,
    required this.treeText,
    required this.visibleTreeText,
    required this.searchController,
    required this.onSearchChanged,
    required this.onCopyText,
    required this.onCopySummary,
    required this.onCopyArtifacts,
    required this.onCopyReviewPack,
  });

  final bool compact;
  final RepoNode? root;
  final String treeText;
  final String visibleTreeText;
  final TextEditingController searchController;
  final VoidCallback onSearchChanged;
  final Future<void> Function(String label, String text) onCopyText;
  final VoidCallback onCopySummary;
  final VoidCallback onCopyArtifacts;
  final VoidCallback onCopyReviewPack;

  @override
  Widget build(BuildContext context) {
    final int visibleNodes = root == null ? 0 : root!.flatten().length - 1;
    final Widget treeList = root == null || root!.children.isEmpty
        ? Center(
            key: const ValueKey<String>('empty-tree'),
            child: Text(
              'No files match the current search or section filter.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          )
        : Scrollbar(
            thumbVisibility: true,
            child: ListView.builder(
              key: const ValueKey<String>('tree-view'),
              itemCount: root!.children.length,
              itemBuilder: (BuildContext context, int index) {
                final RepoNode child = root!.children[index];
                return _RepoNodeTile(
                  node: child,
                  depth: 0,
                  forceOpen: searchController.text.trim().isNotEmpty,
                  onCopyText: onCopyText,
                );
              },
            ),
          );

    return _Surface(
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            runSpacing: 12,
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              SizedBox(
                width: compact ? double.infinity : 420,
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
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: visibleTreeText.isEmpty
                        ? null
                        : () => onCopyText('Visible tree', visibleTreeText),
                    icon: const Icon(Icons.copy_all_rounded),
                    label: const Text('Copy Tree'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onCopySummary,
                    icon: const Icon(Icons.summarize_rounded),
                    label: const Text('Copy Summary'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onCopyArtifacts,
                    icon: const Icon(Icons.inventory_2_rounded),
                    label: const Text('Copy Artifacts'),
                  ),
                  OutlinedButton.icon(
                    onPressed: visibleTreeText.isEmpty
                        ? null
                        : onCopyReviewPack,
                    icon: const Icon(Icons.assignment_rounded),
                    label: const Text('Copy Review Pack'),
                  ),
                ],
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
          if (compact)
            SizedBox(
              height: 420,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                child: treeList,
              ),
            )
          else
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                child: treeList,
              ),
            ),
          if (treeText.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            _TextArtifactPreview(
              treeText: treeText,
              onCopy: () => onCopyText('Headless export', treeText),
            ),
          ],
        ],
      ),
    );
  }
}

class _InsightPanel extends StatelessWidget {
  const _InsightPanel({
    required this.compact,
    required this.snapshot,
    required this.receipt,
    required this.selectedSectionId,
  });

  final bool compact;
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

    final List<Widget> content = <Widget>[
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
          if (selectedSection != null && selectedSection.highlights.isNotEmpty)
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
                ...receipt!.generatedFiles.map((String path) => path).take(4),
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
    ];

    return _Surface(
      padding: const EdgeInsets.all(18),
      child: compact
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: content,
            )
          : Scrollbar(
              thumbVisibility: true,
              child: ListView(children: content),
            ),
    );
  }
}

class _TextArtifactPreview extends StatelessWidget {
  const _TextArtifactPreview({required this.treeText, required this.onCopy});

  final String treeText;
  final VoidCallback onCopy;

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
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Headless Export Preview',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Copy headless export',
                onPressed: onCopy,
                icon: const Icon(Icons.content_copy_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: SingleChildScrollView(
              child: SelectableText(
                lines.join('\n'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'Consolas',
                  color: const Color(0xFFC0D0E2),
                  height: 1.35,
                ),
              ),
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
    required this.onCopyText,
  });

  final RepoNode node;
  final int depth;
  final bool forceOpen;
  final Future<void> Function(String label, String text) onCopyText;

  @override
  Widget build(BuildContext context) {
    final Color badgeColor = node.isDirectory
        ? const Color(0xFF7AD7C3)
        : const Color(0xFFD37C55);

    final PopupMenuButton<String> copyMenu = PopupMenuButton<String>(
      tooltip: 'Copy options',
      onSelected: (String value) {
        switch (value) {
          case 'path':
            onCopyText('Path', node.path);
            break;
          case 'entry':
            onCopyText(
              'Entry',
              '${node.name} (${node.typeLabel})${node.path == '.' ? '' : ' - ${node.path}'}',
            );
            break;
          case 'tree':
            onCopyText('Subtree', buildTreeText(node));
            break;
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(value: 'path', child: Text('Copy path')),
        const PopupMenuItem<String>(value: 'entry', child: Text('Copy entry')),
        if (node.isDirectory)
          const PopupMenuItem<String>(
            value: 'tree',
            child: Text('Copy subtree'),
          ),
      ],
    );

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
                copyMenu,
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
          trailing: Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              _TypeBadge(label: node.typeLabel, color: badgeColor),
              copyMenu,
            ],
          ),
          children: node.children
              .map(
                (RepoNode child) => _RepoNodeTile(
                  node: child,
                  depth: depth + 1,
                  forceOpen: forceOpen,
                  onCopyText: onCopyText,
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
              : 'Select a folder or enter a GitHub repo.',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Text(
          'The scanner stages a full snapshot, summary, receipt, and headless text tree. On web, enter a GitHub repository and analyze it in-browser.',
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
