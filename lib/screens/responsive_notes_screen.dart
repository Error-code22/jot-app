import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/note_model.dart';
import '../services/app_settings.dart';
import '../services/cloudinary_service.dart';
import '../services/feedback_service.dart';
import '../services/i_auth_service.dart';
import '../services/note_service.dart';
import '../services/sync_engine.dart';
import '../services/todo_service.dart';
import '../utils/color_utils.dart';
import '../utils/theme_provider.dart';
import '../utils/view_mode_provider.dart';
import '../widgets/jot_ui.dart';
import '../widgets/sync_indicator.dart';
import 'feedback_screen.dart';
import 'import_screen.dart';
import 'note_editor_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'todo_screen.dart';

Color? _hexToColor(String? hex) => ColorUtils.fromHex(hex);

List<Note> _filterNotes(
  List<Note> notes, {
  required String query,
  String? tag,
}) {
  if (query.isEmpty && tag == null) return notes;
  final q = query.toLowerCase();
  return notes.where((note) {
    if (tag != null && !note.tags.contains(tag)) return false;
    if (q.isEmpty) return true;
    return note.title.toLowerCase().contains(q) ||
        note.content.toLowerCase().contains(q) ||
        note.tags.any((t) => t.toLowerCase().contains(q));
  }).toList();
}

/// Human-readable preview of a note, including checklist content.
String _previewText(Note note) {
  if (note.type != NoteType.checklist) return note.content;
  try {
    final decoded = jsonDecode(note.content);
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((item) =>
              '${item['isChecked'] == true ? '☑' : '☐'} ${item['text'] ?? ''}')
          .join('\n');
    }
  } catch (_) {
    // Fall through to the raw content for malformed legacy values.
  }
  return note.content;
}

String _formatDate(DateTime date) {
  final now = DateTime.now();
  final days = now.difference(date).inDays;
  if (days == 0) return 'Today';
  if (days == 1) return 'Yesterday';
  return '${date.day}/${date.month}';
}

class ResponsiveNotesScreen extends StatefulWidget {
  const ResponsiveNotesScreen({super.key});

  @override
  State<ResponsiveNotesScreen> createState() => _ResponsiveNotesScreenState();
}

class _ResponsiveNotesScreenState extends State<ResponsiveNotesScreen> {
  Note? _selectedNote;
  bool _isCreatingNewNote = false;
  String _searchQuery = '';
  String? _tagFilter;
  int _currentTab = 0;
  bool _fabExpanded = false;
  bool _isSearching = false;
  final Set<String> _selectedNoteIds = {};
  final TextEditingController _searchController = TextEditingController();
  static const double _desktopBreakpoint = 800.0;
  late final Future<List<Note>> _initialNotesFuture;

  bool get _isSelecting => _selectedNoteIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final authService = Provider.of<IAuthService>(context, listen: false);
    final noteService = Provider.of<NoteService>(context, listen: false);
    final user = authService.getCurrentUser();
    _initialNotesFuture = user == null
        ? Future.value(const <Note>[])
        : noteService.getAllNotes(user.uid);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _setSearch(String value) {
    setState(() => _searchQuery = value);
  }

  void _closeSearch() {
    _searchController.clear();
    setState(() {
      _isSearching = false;
      _searchQuery = '';
    });
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _openNote(Note note) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => NoteEditorScreen(note: note)),
    );
  }

  void _toggleSelection(Note note) {
    setState(() {
      if (!_selectedNoteIds.remove(note.id)) {
        _selectedNoteIds.add(note.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<IAuthService>(context, listen: false);
    final user = authService.getCurrentUser();

    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pushReplacementNamed('/login');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= _desktopBreakpoint;
        return isDesktop
            ? _buildDesktopLayout(user.uid)
            : _buildMobileLayout(user.uid);
      },
    );
  }

  // ── Desktop ───────────────────────────────────────────────────────────────

  Widget _buildDesktopLayout(String userId) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Row(
          children: [
            _buildDesktopSidebar(userId),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(
              child: Column(
                children: [
                  _buildAppBar(showTitle: false, desktop: true),
                  Expanded(
                    child: _selectedNote != null || _isCreatingNewNote
                        ? NoteEditorScreen(
                            key: ValueKey(
                                _selectedNote?.id ?? 'new-desktop-note'),
                            note: _selectedNote,
                            embedded: true,
                            onClose: _closeDesktopEditor,
                          )
                        : _buildEmptyEditorState(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _closeDesktopEditor() {
    if (!mounted) return;
    setState(() {
      _selectedNote = null;
      _isCreatingNewNote = false;
    });
  }

  Widget _buildDesktopSidebar(String userId) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 320,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Hero(
                  tag: 'app_logo',
                  child: Icon(Icons.note_alt_rounded,
                      color: theme.colorScheme.primary, size: 32),
                ),
                const SizedBox(width: 12),
                Text('Jot?',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton.icon(
              onPressed: () => setState(() {
                _selectedNote = null;
                _isCreatingNewNote = true;
              }),
              icon: const Icon(Icons.add),
              label: const Text('New Note'),
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50)),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              onChanged: _setSearch,
              decoration: InputDecoration(
                hintText: 'Search notes...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _setSearch('');
                        },
                      ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                filled: true,
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (_tagFilter != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FilterChip(
                  label: Text('#$_tagFilter'),
                  selected: true,
                  onSelected: (_) {},
                  onDeleted: () => setState(() => _tagFilter = null),
                ),
              ),
            ),
          Expanded(
            child: _NotesListPane(
              userId: userId,
              selectedNote: _selectedNote,
              searchQuery: _searchQuery,
              tagFilter: _tagFilter,
              onNoteSelected: (note) => setState(() {
                _selectedNote = note;
                _isCreatingNewNote = false;
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ── Mobile ────────────────────────────────────────────────────────────────

  Widget _buildMobileLayout(String userId) {
    final noteService = Provider.of<NoteService>(context, listen: false);
    final syncEngine = Provider.of<SyncEngine>(context, listen: false);
    final viewMode = Provider.of<ViewModeProvider>(context).mode;
    final settings = Provider.of<AppSettings>(context);

    return JotGradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: _buildAppBar(),
        body: Stack(
          children: [
            IndexedStack(
              index: _currentTab,
              children: [
                FutureBuilder<List<Note>>(
                  future: _initialNotesFuture,
                  builder: (context, futureSnapshot) {
                    return StreamBuilder<List<Note>>(
                      stream: noteService.watchNotes(userId),
                      builder: (context, snapshot) {
                        final notes = snapshot.data ?? futureSnapshot.data;
                        if (notes == null) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return _buildErrorState('${snapshot.error}');
                        }
                        if (notes.isEmpty) return _buildEmptyState();
                        return RefreshIndicator(
                          onRefresh: () async {
                            try {
                              await syncEngine.syncNow(userId);
                            } catch (e) {
                              _showSnack('Sync failed: $e');
                            }
                          },
                          child: Column(
                            children: [
                              if (_tagFilter != null)
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 8, 16, 0),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: FilterChip(
                                      label: Text('#$_tagFilter'),
                                      selected: true,
                                      onSelected: (_) {},
                                      onDeleted: () =>
                                          setState(() => _tagFilter = null),
                                    ),
                                  ),
                                ),
                              Expanded(
                                child: _buildNotesView(
                                  notes,
                                  viewMode,
                                  hidePreviews: settings.hideNotePreviews,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
                const TodoScreen(),
              ],
            ),
            if (_fabExpanded)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => _fabExpanded = false),
                  child: ColoredBox(color: Colors.black.withValues(alpha: 0.4)),
                ),
              ),
            if (_isSelecting)
              Positioned(
                bottom: 12,
                left: 16,
                right: 16,
                child: SafeArea(
                  top: false,
                  child: Card(
                    elevation: 8,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Text('${_selectedNoteIds.length} selected',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded,
                                color: Colors.red),
                            tooltip: 'Delete selected',
                            onPressed: () => _batchAction('delete'),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            tooltip: 'Cancel',
                            onPressed: () =>
                                setState(() => _selectedNoteIds.clear()),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentTab,
          onTap: (i) => setState(() {
            _currentTab = i;
            _fabExpanded = false;
            if (i != 0) _closeSearch();
          }),
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.notes_rounded), label: 'Notes'),
            BottomNavigationBarItem(
                icon: Icon(Icons.checklist_rounded), label: 'To-do'),
          ],
        ),
        floatingActionButton:
            _currentTab == 0 && !_isSelecting ? _buildSpeedDial(userId) : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }

  Widget _buildSpeedDial(String userId) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_fabExpanded) ...[
          _SpeedDialItem(
            icon: Icons.upload_file_outlined,
            label: 'Import',
            onTap: () {
              setState(() => _fabExpanded = false);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ImportScreen()));
            },
          ),
          const SizedBox(height: 8),
          _SpeedDialItem(
            icon: Icons.checklist_rounded,
            label: 'New To-do',
            onTap: () {
              setState(() => _fabExpanded = false);
              _createTodoList();
            },
          ),
          const SizedBox(height: 8),
          _SpeedDialItem(
            icon: Icons.edit_note_rounded,
            label: 'New Note',
            onTap: () {
              setState(() => _fabExpanded = false);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const NoteEditorScreen()));
            },
          ),
          const SizedBox(height: 8),
        ],
        FloatingActionButton(
          onPressed: () => setState(() => _fabExpanded = !_fabExpanded),
          child: AnimatedRotation(
            turns: _fabExpanded ? 0.125 : 0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(Icons.add_rounded, size: 28),
          ),
        ),
      ],
    );
  }

  Widget _buildNotesView(
    List<Note> notes,
    ViewMode viewMode, {
    required bool hidePreviews,
  }) {
    final filtered = _filterNotes(notes, query: _searchQuery, tag: _tagFilter);
    if (filtered.isEmpty && (_searchQuery.isNotEmpty || _tagFilter != null)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off_rounded,
                  size: 48, color: Colors.grey),
              const SizedBox(height: 8),
              const Text('No notes match your search',
                  style: TextStyle(color: Colors.grey)),
              if (_isSearching)
                TextButton(
                  onPressed: _closeSearch,
                  child: const Text('Clear search'),
                ),
            ],
          ),
        ),
      );
    }

    switch (viewMode) {
      case ViewMode.grid:
        return MasonryGridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          itemCount: filtered.length,
          addAutomaticKeepAlives: false,
          itemBuilder: (context, index) {
            final note = filtered[index];
            return _NoteCard(
              note: note,
              hidePreview: hidePreviews,
              isSelected: _selectedNoteIds.contains(note.id),
              isSelecting: _isSelecting,
              onTagTap: (tag) => setState(() => _tagFilter = tag),
              onTap: () =>
                  _isSelecting ? _toggleSelection(note) : _openNote(note),
              onLongPress: () => _toggleSelection(note),
              onShare: () => _shareNoteText(note),
            );
          },
        );
      case ViewMode.list:
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          itemCount: filtered.length,
          addAutomaticKeepAlives: false,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final note = filtered[index];
            return _NoteListTile(
              note: note,
              hidePreview: hidePreviews,
              isSelected: _selectedNoteIds.contains(note.id),
              isSelecting: _isSelecting,
              onTap: () =>
                  _isSelecting ? _toggleSelection(note) : _openNote(note),
              onLongPress: () => _toggleSelection(note),
              onShare: () => _shareNoteText(note),
            );
          },
        );
      case ViewMode.compact:
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          itemCount: filtered.length,
          addAutomaticKeepAlives: false,
          itemBuilder: (context, index) {
            final note = filtered[index];
            return _NoteCompactTile(
              note: note,
              hidePreview: hidePreviews,
              onTap: () =>
                  _isSelecting ? _toggleSelection(note) : _openNote(note),
              onLongPress: () => _toggleSelection(note),
            );
          },
        );
    }
  }

  // ── App bar and menus ─────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar({
    bool showTitle = true,
    bool desktop = false,
  }) {
    final syncEngine = Provider.of<SyncEngine>(context, listen: false);
    final authService = Provider.of<IAuthService>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final viewProvider = Provider.of<ViewModeProvider>(context);
    final user = authService.getCurrentUser();
    final showSearchAction = !desktop && _currentTab == 0;

    Widget? title;
    if (_isSelecting) {
      title = Text('${_selectedNoteIds.length} selected',
          style: const TextStyle(fontWeight: FontWeight.bold));
    } else if (_isSearching && !desktop) {
      title = TextField(
        controller: _searchController,
        autofocus: true,
        onChanged: _setSearch,
        textInputAction: TextInputAction.search,
        decoration: const InputDecoration(
          hintText: 'Search notes...',
          border: InputBorder.none,
        ),
      );
    } else if (showTitle) {
      title = Text('Jot?',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold));
    }

    return AppBar(
      title: title,
      centerTitle: false,
      leading: _isSelecting
          ? IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Cancel selection',
              onPressed: () => setState(() => _selectedNoteIds.clear()))
          : (_isSearching && !desktop
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  tooltip: 'Close search',
                  onPressed: _closeSearch,
                )
              : null),
      actions: _isSelecting
          ? _buildSelectionActions()
          : [
              StreamBuilder(
                stream: syncEngine.syncStatus,
                builder: (context, snapshot) => snapshot.data != null
                    ? SyncIndicator(syncState: snapshot.data!)
                    : const SizedBox(),
              ),
              const SizedBox(width: 4),
              if (showSearchAction && !_isSearching)
                IconButton(
                  icon: const Icon(Icons.search_rounded),
                  tooltip: 'Search notes',
                  onPressed: () => setState(() => _isSearching = true),
                ),
              if (!desktop)
                PopupMenuButton<ViewMode>(
                  icon: Icon(_viewModeIcon(viewProvider.mode)),
                  tooltip: 'View mode',
                  offset: const Offset(0, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  onSelected: (mode) => viewProvider.setMode(mode),
                  itemBuilder: (_) => [
                    _viewMenuItem(ViewMode.grid, Icons.grid_view_rounded,
                        'Tiles', viewProvider.mode),
                    _viewMenuItem(ViewMode.list, Icons.view_list_rounded,
                        'List', viewProvider.mode),
                    _viewMenuItem(ViewMode.compact, Icons.density_small_rounded,
                        'Compact', viewProvider.mode),
                  ],
                ),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                offset: const Offset(0, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.15),
                    child: Icon(Icons.person_rounded,
                        size: 20, color: Theme.of(context).colorScheme.primary),
                  ),
                ),
                onSelected: (value) {
                  switch (value) {
                    case 'signout':
                      _handleSignOut(authService);
                      break;
                    case 'profile':
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const ProfileScreen()));
                      break;
                    case 'settings':
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const SettingsScreen()));
                      break;
                    case 'theme':
                      themeProvider.setMode(themeProvider.isDark
                          ? AppThemeMode.light
                          : AppThemeMode.dark);
                      break;
                    case 'feature':
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const FeedbackScreen(
                              initialType: FeedbackType.feature)));
                      break;
                    case 'bug':
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const FeedbackScreen(
                              initialType: FeedbackType.bug)));
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    enabled: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.displayName ?? 'Local User',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color:
                                    Theme.of(context).colorScheme.onSurface)),
                        Text(user?.email ?? '',
                            style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.6))),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                      value: 'profile',
                      child: Row(children: [
                        Icon(Icons.person_outline_rounded, size: 20),
                        SizedBox(width: 12),
                        Text('Profile')
                      ])),
                  const PopupMenuItem(
                      value: 'settings',
                      child: Row(children: [
                        Icon(Icons.settings_outlined, size: 20),
                        SizedBox(width: 12),
                        Text('Settings')
                      ])),
                  PopupMenuItem(
                      value: 'theme',
                      child: Row(children: [
                        Icon(
                            themeProvider.isDark
                                ? Icons.light_mode_rounded
                                : Icons.dark_mode_rounded,
                            size: 20),
                        const SizedBox(width: 12),
                        Text(themeProvider.isDark
                            ? 'Light appearance'
                            : 'Dark appearance')
                      ])),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                      value: 'feature',
                      child: Row(children: [
                        Icon(Icons.lightbulb_outline_rounded,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 12),
                        const Text('Request Feature')
                      ])),
                  PopupMenuItem(
                      value: 'bug',
                      child: Row(children: [
                        Icon(Icons.bug_report_outlined,
                            size: 20,
                            color: Theme.of(context).colorScheme.error),
                        const SizedBox(width: 12),
                        Text('Report Bug',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error))
                      ])),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                      value: 'signout',
                      child: Row(children: [
                        Icon(Icons.logout_rounded, size: 20, color: Colors.red),
                        SizedBox(width: 12),
                        Text('Sign out', style: TextStyle(color: Colors.red))
                      ])),
                ],
              ),
              const SizedBox(width: 8),
            ],
    );
  }

  IconData _viewModeIcon(ViewMode mode) {
    switch (mode) {
      case ViewMode.grid:
        return Icons.grid_view_rounded;
      case ViewMode.list:
        return Icons.view_list_rounded;
      case ViewMode.compact:
        return Icons.density_small_rounded;
    }
  }

  PopupMenuItem<ViewMode> _viewMenuItem(
      ViewMode mode, IconData icon, String label, ViewMode current) {
    return PopupMenuItem(
      value: mode,
      child: Row(children: [
        Icon(icon,
            size: 20,
            color:
                current == mode ? Theme.of(context).colorScheme.primary : null),
        const SizedBox(width: 12),
        Text(label,
            style: TextStyle(
                color: current == mode
                    ? Theme.of(context).colorScheme.primary
                    : null,
                fontWeight: current == mode ? FontWeight.bold : null)),
        const Spacer(),
        if (current == mode)
          Icon(Icons.check,
              size: 16, color: Theme.of(context).colorScheme.primary),
      ]),
    );
  }

  List<Widget> _buildSelectionActions() {
    return [
      IconButton(
        icon: const Icon(Icons.push_pin_outlined),
        tooltip: 'Pin selected',
        onPressed: () => _batchAction('pin'),
      ),
      IconButton(
        icon: const Icon(Icons.label_outline_rounded),
        tooltip: 'Tag selected',
        onPressed: () => _batchAction('tag'),
      ),
      IconButton(
        icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
        tooltip: 'Delete selected',
        onPressed: () => _batchAction('delete'),
      ),
      const SizedBox(width: 8),
    ];
  }

  Future<void> _batchAction(String action) async {
    if (_selectedNoteIds.isEmpty) return;
    final noteService = Provider.of<NoteService>(context, listen: false);
    final authService = Provider.of<IAuthService>(context, listen: false);
    final user = authService.getCurrentUser();
    if (user == null) return;

    if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
              'Delete ${_selectedNoteIds.length} note${_selectedNoteIds.length == 1 ? '' : 's'}?'),
          content: const Text('This cannot be undone.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    String? tag;
    if (action == 'tag') {
      final controller = TextEditingController();
      tag = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Add tag to selected notes'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration:
                const InputDecoration(hintText: 'Tag name', prefixText: '# '),
            onSubmitted: (v) => Navigator.pop(dialogContext, v),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, controller.text),
                child: const Text('Add')),
          ],
        ),
      );
      if (tag == null || tag.trim().isEmpty) return;
    }

    final allNotes = await noteService.getAllNotes(user.uid);
    final selected = allNotes.where((n) => _selectedNoteIds.contains(n.id));
    for (final note in selected) {
      switch (action) {
        case 'delete':
          await noteService.deleteNote(note);
          break;
        case 'pin':
          await noteService.togglePin(note);
          break;
        case 'tag':
          final newTags =
              <String>{...note.tags, tag!.trim().toLowerCase()}.toList();
          await noteService.updateNote(note, tags: newTags);
          break;
      }
    }

    if (mounted) setState(() => _selectedNoteIds.clear());
  }

  Future<void> _createTodoList() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New To-do List'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'List name...'),
          onSubmitted: (v) => Navigator.pop(dialogContext, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('Create')),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty || !mounted) return;
    final todoService = Provider.of<TodoService>(context, listen: false);
    final list = await todoService.createList(name.trim());
    if (!mounted) return;
    setState(() => _currentTab = 1);
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => TodoDetailScreen(list: list)));
  }

  void _shareNoteText(Note note) {
    if (note.isLocked) {
      _showSnack('Unlock this note before sharing it.');
      return;
    }
    final title = note.title.isEmpty ? 'Jot? Note' : note.title;
    final content = _previewText(note);
    Share.share(title.isEmpty ? content : '$title\n\n$content', subject: title);
  }

  Future<void> _handleSignOut(IAuthService authService) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out'),
        content: const Text(
            'Are you sure you want to sign out? Your notes are safely synced to the cloud.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Sign out')),
        ],
      ),
    );
    if (confirmed != true) return;
    await authService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/login');
  }

  // ── States ────────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notes_rounded, size: 100, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('Nothing here yet',
                style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            Text('Your notes will appear here',
                style: TextStyle(color: Colors.grey.shade400)),
            if (_searchQuery.isNotEmpty) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _closeSearch,
                child: const Text('Clear search'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyEditorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.edit_note_rounded, size: 100, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          Text('Select a note to view',
              style: TextStyle(
                  color: Colors.grey.shade300,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => setState(() => _isCreatingNewNote = true),
            icon: const Icon(Icons.add_rounded),
            label: const Text('New Note'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text('Could not load notes.\n$error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            const Text('Pull down to try again.',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

// ── Note cards ──────────────────────────────────────────────────────────────

class _NoteCard extends StatelessWidget {
  final Note note;
  final bool hidePreview;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onShare;
  final bool isSelected;
  final bool isSelecting;
  final void Function(String tag)? onTagTap;

  const _NoteCard({
    required this.note,
    required this.hidePreview,
    required this.onTap,
    required this.onLongPress,
    required this.onShare,
    this.isSelected = false,
    this.isSelecting = false,
    this.onTagTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = ColorUtils.noteBackground(note.color, isDark, context);
    final textColor = ColorUtils.textColor(bgColor);
    final subTextColor = ColorUtils.secondaryTextColor(bgColor);
    final hidden = note.isLocked || note.hidePreview || hidePreview;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: isDark ? [] : JotUI.premiumShadow(),
              border: isSelected
                  ? Border.all(color: theme.colorScheme.primary, width: 2.5)
                  : (isDark
                      ? Border.all(color: const Color(0xFF313244), width: 1)
                      : null),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPreview(context, hidden, textColor),
                if (note.title.isNotEmpty || note.isPinned) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (note.isPinned)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(Icons.push_pin_rounded,
                              size: 14, color: theme.colorScheme.primary),
                        ),
                      if (note.isLocked)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(Icons.lock_rounded,
                              size: 14, color: Colors.orange),
                        ),
                      Expanded(
                        child: Text(
                          note.title.isEmpty ? 'Untitled' : note.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: textColor),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(_formatDate(note.modifiedAt),
                        style: TextStyle(
                            fontSize: 10,
                            color: subTextColor,
                            fontWeight: FontWeight.bold)),
                    if (note.audioIds.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.graphic_eq_rounded,
                          size: 13, color: subTextColor),
                    ],
                    if (note.imageIds.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.image_outlined, size: 13, color: subTextColor),
                    ],
                    const Spacer(),
                    if (theme.brightness == Brightness.dark)
                      Icon(Icons.nightlight_round,
                          size: 10, color: subTextColor.withValues(alpha: 0.4)),
                  ],
                ),
                if (note.tags.isNotEmpty && !hidden) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 2,
                    children: note.tags
                        .take(3)
                        .map((tag) => GestureDetector(
                              onTap: () => onTagTap?.call(tag),
                              child: Text('#$tag',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: textColor.withValues(alpha: 0.7),
                                      fontWeight: FontWeight.w600)),
                            ))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          if (isSelected)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 16, color: Colors.white),
              ),
            )
          else if (!isSelecting && !note.isLocked)
            Positioned(
              top: 6,
              right: 6,
              child: _RoundIconButton(
                icon: Icons.share_outlined,
                color: bgColor.withValues(alpha: 0.85),
                iconColor: textColor.withValues(alpha: 0.6),
                tooltip: 'Share',
                onTap: onShare,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPreview(BuildContext context, bool hidden, Color textColor) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (hidden) {
      return Container(
        width: double.infinity,
        height: 76,
        decoration: BoxDecoration(
          color: textColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              note.isLocked ? Icons.lock_rounded : Icons.visibility_off_rounded,
              size: 24,
              color: note.isLocked
                  ? Colors.orange
                  : textColor.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 4),
            Text(
              note.isLocked ? 'Locked' : 'Preview hidden',
              style: TextStyle(
                  fontSize: 10, color: textColor.withValues(alpha: 0.5)),
            ),
          ],
        ),
      );
    }

    if (note.imageIds.isNotEmpty) {
      final cloudinary = Provider.of<CloudinaryService>(context, listen: false);
      final url = cloudinary.getThumbnailUrl(note.imageIds.first, size: 400);
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          url,
          width: double.infinity,
          height: 90,
          fit: BoxFit.cover,
          cacheWidth: 400,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded || frame != null) return child;
            return Container(
              height: 90,
              color: textColor.withValues(alpha: 0.05),
              alignment: Alignment.center,
              child: const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            );
          },
          errorBuilder: (_, __, ___) => Container(
            height: 90,
            color: textColor.withValues(alpha: 0.05),
            alignment: Alignment.center,
            child: Icon(Icons.broken_image_outlined,
                size: 24, color: textColor.withValues(alpha: 0.4)),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      height: 76,
      decoration: BoxDecoration(
        color: isDark
            ? textColor.withValues(alpha: 0.05)
            : (note.color != null
                ? textColor.withValues(alpha: 0.05)
                : theme.colorScheme.primary.withValues(alpha: 0.06)),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(10),
      child: Text(
        _previewText(note).isEmpty ? 'Empty note' : _previewText(note),
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
            fontSize: 11, height: 1.4, color: textColor.withValues(alpha: 0.6)),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color iconColor;
  final String tooltip;
  final VoidCallback onTap;

  const _RoundIconButton({
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(icon, size: 15, color: iconColor),
        ),
      ),
    );
  }
}

class _NotesListPane extends StatelessWidget {
  final String userId;
  final Note? selectedNote;
  final String searchQuery;
  final String? tagFilter;
  final Function(Note) onNoteSelected;

  const _NotesListPane({
    required this.userId,
    required this.selectedNote,
    required this.searchQuery,
    this.tagFilter,
    required this.onNoteSelected,
  });

  @override
  Widget build(BuildContext context) {
    final noteService = Provider.of<NoteService>(context, listen: false);
    return StreamBuilder<List<Note>>(
      stream: noteService.watchNotes(userId),
      builder: (context, snapshot) {
        final notes = snapshot.data;
        if (notes == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final filtered =
            _filterNotes(notes, query: searchQuery, tag: tagFilter);
        if (filtered.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                (searchQuery.isEmpty && tagFilter == null)
                    ? 'No notes yet.\nTap + New Note to start.'
                    : 'No notes match your search',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          );
        }
        return ListView.builder(
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final note = filtered[index];
            final selected = selectedNote?.id == note.id;
            final hidden = note.isLocked || note.hidePreview;
            return ListTile(
              selected: selected,
              onTap: () => onNoteSelected(note),
              leading: SizedBox(
                width: 32,
                child: note.isLocked
                    ? const Icon(Icons.lock_rounded,
                        size: 18, color: Colors.orange)
                    : (note.imageIds.isNotEmpty
                        ? const Icon(Icons.image_outlined, size: 18)
                        : Icon(
                            note.type == NoteType.checklist
                                ? Icons.checklist_rounded
                                : Icons.notes_rounded,
                            size: 18,
                            color: Colors.grey)),
              ),
              title: Text(note.title.isEmpty ? 'Untitled' : note.title,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(hidden ? 'Preview hidden' : _previewText(note),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              trailing: note.audioIds.isNotEmpty
                  ? const Icon(Icons.graphic_eq_rounded, size: 16)
                  : null,
            );
          },
        );
      },
    );
  }
}

class _NoteListTile extends StatelessWidget {
  final Note note;
  final bool hidePreview;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback onShare;
  final bool isSelected;
  final bool isSelecting;

  const _NoteListTile({
    required this.note,
    required this.hidePreview,
    required this.onTap,
    required this.onShare,
    this.onLongPress,
    this.isSelected = false,
    this.isSelecting = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = ColorUtils.noteBackground(note.color, isDark, context);
    final textColor = ColorUtils.textColor(bgColor);
    final hidden = note.isLocked || note.hidePreview || hidePreview;

    Widget thumbnail;
    if (!hidden && note.imageIds.isNotEmpty) {
      final cloudinary = Provider.of<CloudinaryService>(context, listen: false);
      thumbnail = ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          cloudinary.getThumbnailUrl(note.imageIds.first, size: 120),
          width: 48,
          height: 48,
          cacheWidth: 120,
          cacheHeight: 120,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _thumbPlaceholder(
              Icons.broken_image_outlined, bgColor, textColor),
        ),
      );
    } else {
      thumbnail = hidden
          ? _thumbPlaceholder(
              note.isLocked ? Icons.lock_rounded : Icons.visibility_off_rounded,
              bgColor,
              note.isLocked ? Colors.orange : textColor)
          : _thumbPlaceholder(
              note.type == NoteType.checklist
                  ? Icons.checklist_rounded
                  : Icons.notes_rounded,
              bgColor,
              textColor);
    }

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF252536) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isDark ? [] : JotUI.premiumShadow(),
          border: isSelected
              ? Border.all(color: theme.colorScheme.primary, width: 2.5)
              : (isDark
                  ? Border.all(color: const Color(0xFF313244), width: 1)
                  : null),
        ),
        child: Row(
          children: [
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(Icons.check_circle_rounded,
                    color: theme.colorScheme.primary),
              ),
            thumbnail,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (note.isPinned)
                        Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(Icons.push_pin_rounded,
                                size: 12, color: theme.colorScheme.primary)),
                      if (note.isLocked)
                        const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(Icons.lock_rounded,
                                size: 12, color: Colors.orange)),
                      Expanded(
                        child: Text(
                          note.title.isEmpty ? 'Untitled' : note.title,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: isDark ? Colors.white : Colors.black87),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(_formatDate(note.modifiedAt),
                          style: TextStyle(
                              fontSize: 11,
                              color:
                                  isDark ? Colors.grey : Colors.grey.shade500)),
                      if (!note.isLocked && !isSelecting)
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert_rounded,
                              size: 16,
                              color: textColor.withValues(alpha: 0.5)),
                          tooltip: 'Note actions',
                          onSelected: (value) {
                            if (value == 'share') onShare();
                            if (value == 'delete') _deleteNote(context);
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'share', child: Text('Share')),
                            PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete',
                                    style: TextStyle(color: Colors.red))),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hidden
                        ? (note.isLocked ? 'Locked' : 'Preview hidden')
                        : (_previewText(note).isEmpty
                            ? 'Empty note'
                            : _previewText(note)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: hidden
                            ? (note.isLocked
                                ? Colors.orange.shade700
                                : Colors.grey)
                            : (isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600),
                        fontSize: 13),
                  ),
                  if ((note.tags.isNotEmpty && !hidden) ||
                      note.audioIds.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (note.audioIds.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Icon(Icons.graphic_eq_rounded,
                                size: 13,
                                color: theme.colorScheme.primary
                                    .withValues(alpha: 0.7)),
                          ),
                        Expanded(
                          child: Wrap(
                            spacing: 4,
                            children: hidden
                                ? const []
                                : note.tags
                                    .take(3)
                                    .map((tag) => Text('#$tag',
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: theme.colorScheme.primary
                                                .withValues(alpha: 0.7),
                                            fontWeight: FontWeight.w600)))
                                    .toList(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumbPlaceholder(IconData icon, Color bgColor, Color iconColor) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 20, color: iconColor.withValues(alpha: 0.6)),
    );
  }

  void _deleteNote(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text('This will remove the note from all your devices.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade400,
                foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await Provider.of<NoteService>(context, listen: false).deleteNote(note);
    }
  }
}

class _NoteCompactTile extends StatelessWidget {
  final Note note;
  final bool hidePreview;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _NoteCompactTile({
    required this.note,
    required this.hidePreview,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor =
        theme.brightness == Brightness.dark ? Colors.white : Colors.black87;
    final hidden = note.isLocked || note.hidePreview || hidePreview;

    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      leading: Container(
        width: 4,
        height: 40,
        decoration: BoxDecoration(
          color: _hexToColor(note.color) ?? theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      title: Row(
        children: [
          if (note.isLocked)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.lock_rounded, size: 12, color: Colors.orange),
            ),
          if (note.isPinned)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(Icons.push_pin_rounded,
                  size: 12, color: theme.colorScheme.primary),
            ),
          if (note.audioIds.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.graphic_eq_rounded, size: 12),
            ),
          Expanded(
            child: Text(
              note.title.isEmpty ? 'Untitled' : note.title,
              style: TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 14, color: textColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      subtitle: Text(
        hidden
            ? (note.isLocked ? 'Locked' : 'Preview hidden')
            : (_previewText(note).isEmpty ? 'Empty note' : _previewText(note)),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
            fontSize: 12,
            color: hidden
                ? (note.isLocked ? Colors.orange.shade700 : Colors.grey)
                : textColor.withValues(alpha: 0.6)),
      ),
      trailing: Text(_formatDate(note.modifiedAt),
          style: const TextStyle(fontSize: 10, color: Colors.grey)),
    );
  }
}

class _SpeedDialItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SpeedDialItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)
            ],
          ),
          child: Text(label,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ),
        const SizedBox(width: 8),
        FloatingActionButton.small(
          heroTag: label,
          onPressed: onTap,
          child: Icon(icon),
        ),
      ],
    );
  }
}
