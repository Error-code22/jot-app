import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/note_model.dart';
import '../services/note_service.dart';
import '../services/i_auth_service.dart';
import '../services/cloudinary_service.dart';
import '../services/sync_engine.dart';
import '../services/todo_service.dart';
import '../widgets/sync_indicator.dart';
import '../widgets/jot_ui.dart';
import '../utils/theme_provider.dart';
import '../utils/view_mode_provider.dart';
import '../utils/color_utils.dart';
import 'note_editor_screen.dart';
import 'settings_screen.dart';
import 'profile_screen.dart';
import 'todo_screen.dart';
import 'import_screen.dart';

// Remove old _hexToColor helper — now using ColorUtils
Color? _hexToColor(String? hex) => ColorUtils.fromHex(hex);

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
  int _currentTab = 0; // 0 = Notes, 1 = Todo
  bool _fabExpanded = false;
  final Set<String> _selectedNoteIds = {};
  bool get _isSelecting => _selectedNoteIds.isNotEmpty;
  static const double _desktopBreakpoint = 800.0;
  late final Future<List<Note>> _initialNotesFuture;

  @override
  void initState() {
    super.initState();
    final authService = Provider.of<IAuthService>(context, listen: false);
    final noteService = Provider.of<NoteService>(context, listen: false);
    final user = authService.getCurrentUser();
    if (user != null) {
      _initialNotesFuture = noteService.getAllNotes(user.uid);
    } else {
      _initialNotesFuture = Future.value([]);
    }
  }

  List<Note> _applyFilters(List<Note> notes) {
    if (_searchQuery.isEmpty && _tagFilter == null) return notes;
    return notes.where((note) {
      // Tag filter: exact match
      if (_tagFilter != null && !note.tags.contains(_tagFilter)) return false;
      // Search filter: case-insensitive substring on title, content, or any tag
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesTitle = note.title.toLowerCase().contains(q);
        final matchesContent = note.content.toLowerCase().contains(q);
        final matchesTag = note.tags.any((t) => t.toLowerCase().contains(q));
        if (!matchesTitle && !matchesContent && !matchesTag) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<IAuthService>(context, listen: false);
    final user = authService.getCurrentUser();

    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/login');
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

  Widget _buildDesktopLayout(String userId) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Row(
        children: [
          // Left sidebar
          _buildDesktopSidebar(userId),

          const VerticalDivider(width: 1, thickness: 1),

          // Main content
          Expanded(
            child: Column(
              children: [
                _buildAppBar(showTitle: false),
                Expanded(
                  child: _selectedNote != null || _isCreatingNewNote
                      ? _DesktopNoteEditor(
                          note: _selectedNote,
                          onNoteDeleted: () => setState(() {
                            _selectedNote = null;
                            _isCreatingNewNote = false;
                          }),
                          onNoteUpdated: (note) => setState(() {
                            _selectedNote = note;
                          }),
                        )
                      : _buildEmptyEditorState(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopSidebar(String userId) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      child: SizedBox(
        width: 320,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
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
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'Search notes...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
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
                child: Row(
                  children: [
                    FilterChip(
                      label: Text('#$_tagFilter'),
                      selected: true,
                      onSelected: (_) {},
                      onDeleted: () => setState(() => _tagFilter = null),
                    ),
                  ],
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
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout(String userId) {
    final noteService = Provider.of<NoteService>(context, listen: false);
    final syncEngine = Provider.of<SyncEngine>(context, listen: false);
    final viewMode = Provider.of<ViewModeProvider>(context).mode;

    return JotGradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: _buildAppBar(),
        body: Stack(
          children: [
            // Tab content
            IndexedStack(
              index: _currentTab,
              children: [
                // Notes tab
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
                          return _buildErrorState(snapshot.error.toString());
                        }
                        if (notes.isEmpty) return _buildEmptyState();
                        return RefreshIndicator(
                          onRefresh: () async =>
                              await syncEngine.syncNow(userId),
                          child: Column(
                            children: [
                              if (_tagFilter != null)
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 8, 16, 0),
                                  child: Row(
                                    children: [
                                      FilterChip(
                                        label: Text('#$_tagFilter'),
                                        selected: true,
                                        onSelected: (_) {},
                                        onDeleted: () =>
                                            setState(() => _tagFilter = null),
                                      ),
                                    ],
                                  ),
                                ),
                              Expanded(child: _buildNotesView(notes, viewMode)),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
                // Todo tab
                const TodoScreen(),
              ],
            ),
            // FAB speed dial overlay
            if (_fabExpanded)
              GestureDetector(
                onTap: () => setState(() => _fabExpanded = false),
                child: Container(color: Colors.black.withValues(alpha: 0.4)),
              ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentTab,
          onTap: (i) => setState(() {
            _currentTab = i;
            _fabExpanded = false;
          }),
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.notes_rounded), label: 'Notes'),
            BottomNavigationBarItem(
                icon: Icon(Icons.checklist_rounded), label: 'To-do'),
          ],
        ),
        floatingActionButton: _buildSpeedDial(userId),
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
              _createTodoList(userId);
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

  Future<void> _createTodoList(String userId) async {
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
    if (name != null && name.trim().isNotEmpty && mounted) {
      final todoService = Provider.of<TodoService>(context, listen: false);
      final list = await todoService.createList(name.trim());
      if (!mounted) return;
      setState(() => _currentTab = 1);
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => TodoDetailScreen(list: list)));
    }
  }

  Widget _buildNotesView(List<Note> notes, ViewMode viewMode) {
    final filtered = _applyFilters(notes);
    if (filtered.isEmpty && (_searchQuery.isNotEmpty || _tagFilter != null)) {
      return const Center(child: Text('No notes match your search'));
    }
    switch (viewMode) {
      case ViewMode.grid:
        return MasonryGridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          addAutomaticKeepAlives: false,
          itemBuilder: (context, index) => _NoteCard(
            note: filtered[index],
            isSelected: _selectedNoteIds.contains(filtered[index].id),
            isSelecting: _isSelecting,
            onTagTap: (tag) => setState(() => _tagFilter = tag),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => NoteEditorScreen(note: filtered[index]))),
            onLongPress: () => setState(() {
              if (_selectedNoteIds.contains(filtered[index].id)) {
                _selectedNoteIds.remove(filtered[index].id);
              } else {
                _selectedNoteIds.add(filtered[index].id);
              }
            }),
          ),
        );
      case ViewMode.list:
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          addAutomaticKeepAlives: false,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) => _NoteListTile(
            note: filtered[index],
            isSelected: _selectedNoteIds.contains(filtered[index].id),
            isSelecting: _isSelecting,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => NoteEditorScreen(note: filtered[index]))),
            onLongPress: () => setState(() {
              if (_selectedNoteIds.contains(filtered[index].id)) {
                _selectedNoteIds.remove(filtered[index].id);
              } else {
                _selectedNoteIds.add(filtered[index].id);
              }
            }),
          ),
        );
      case ViewMode.compact:
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: filtered.length,
          addAutomaticKeepAlives: false,
          itemBuilder: (context, index) => _NoteCompactTile(
            note: filtered[index],
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => NoteEditorScreen(note: filtered[index]))),
          ),
        );
    }
  }

  PreferredSizeWidget _buildAppBar({bool showTitle = true}) {
    final syncEngine = Provider.of<SyncEngine>(context, listen: false);
    final authService = Provider.of<IAuthService>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final viewProvider = Provider.of<ViewModeProvider>(context);
    final user = authService.getCurrentUser();

    return AppBar(
      title: _isSelecting
          ? Text('${_selectedNoteIds.length} selected',
              style: const TextStyle(fontWeight: FontWeight.bold))
          : (showTitle
              ? Text('Jot?',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold))
              : null),
      centerTitle: false,
      leading: _isSelecting
          ? IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _selectedNoteIds.clear()))
          : null,
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
              PopupMenuButton<ViewMode>(
                icon: Icon(_viewModeIcon(viewProvider.mode)),
                tooltip: 'View mode',
                offset: const Offset(0, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                onSelected: (mode) => viewProvider.setMode(mode),
                itemBuilder: (_) => [
                  _viewMenuItem(ViewMode.grid, Icons.grid_view_rounded, 'Tiles',
                      viewProvider.mode),
                  _viewMenuItem(ViewMode.list, Icons.view_list_rounded, 'List',
                      viewProvider.mode),
                  _viewMenuItem(ViewMode.compact, Icons.density_small_rounded,
                      'Compact', viewProvider.mode),
                ],
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(themeProvider.isDark
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded),
                tooltip: themeProvider.isDark ? 'Light mode' : 'Dark mode',
                onPressed: () => themeProvider.setMode(themeProvider.isDark
                    ? AppThemeMode.light
                    : AppThemeMode.dark),
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
                  if (value == 'signout') _handleSignOut(authService);
                  if (value == 'profile') {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const ProfileScreen()));
                  }
                  if (value == 'settings') {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const SettingsScreen()));
                  }
                  if (value == 'feature') {
                    launchUrl(Uri.parse('https://github.com/reueldroner/jot-app/issues/new?template=feature_request.md'));
                  }
                  if (value == 'bug') {
                    launchUrl(Uri.parse('https://github.com/reueldroner/jot-app/issues/new?template=bug_report.md'));
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
                                color: Theme.of(context).colorScheme.onSurface)),
                        Text(user?.email ?? '',
                            style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
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
                  const PopupMenuDivider(),
                  PopupMenuItem(
                      value: 'feature',
                      child: Row(children: [
                        Icon(Icons.lightbulb_outline_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 12),
                        const Text('Request Feature')
                      ])),
                  PopupMenuItem(
                      value: 'bug',
                      child: Row(children: [
                        Icon(Icons.bug_report_outlined, size: 20, color: Theme.of(context).colorScheme.error),
                        const SizedBox(width: 12),
                        Text('Report Bug', style: TextStyle(color: Theme.of(context).colorScheme.error))
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
    final noteService = Provider.of<NoteService>(context, listen: false);
    final authService = Provider.of<IAuthService>(context, listen: false);
    final user = authService.getCurrentUser();
    if (user == null) return;

    if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(
              'Delete ${_selectedNoteIds.length} note${_selectedNoteIds.length == 1 ? '' : 's'}?'),
          content: const Text('This cannot be undone.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;

      final allNotes = await noteService.getAllNotes(user.uid);
      for (final note
          in allNotes.where((n) => _selectedNoteIds.contains(n.id))) {
        await noteService.deleteNote(note);
      }
    } else if (action == 'pin') {
      final allNotes = await noteService.getAllNotes(user.uid);
      for (final note
          in allNotes.where((n) => _selectedNoteIds.contains(n.id))) {
        await noteService.togglePin(note);
      }
    } else if (action == 'tag') {
      final controller = TextEditingController();
      final tag = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Add tag to selected notes'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration:
                const InputDecoration(hintText: 'Tag name', prefixText: '# '),
            onSubmitted: (v) => Navigator.pop(context, v),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () => Navigator.pop(context, controller.text),
                child: const Text('Add')),
          ],
        ),
      );
      if (tag != null && tag.trim().isNotEmpty) {
        final allNotes = await noteService.getAllNotes(user.uid);
        for (final note
            in allNotes.where((n) => _selectedNoteIds.contains(n.id))) {
          final newTags =
              <String>{...note.tags, tag.trim().toLowerCase()}.toList();
          await noteService.updateNote(note, tags: newTags);
        }
      }
    }

    setState(() => _selectedNoteIds.clear());
  }

  Future<void> _handleSignOut(IAuthService authService) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out'),
        content: const Text(
            'Are you sure you want to sign out? Your notes are safely synced to the cloud.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sign out')),
        ],
      ),
    );
    if (confirmed == true) {
      await authService.signOut();
      if (mounted) Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  Widget _buildEmptyState() {
    return Center(
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
        ],
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
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
        child:
            Text('Error: $error', style: const TextStyle(color: Colors.red)));
  }
}

class _NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool isSelected;
  final bool isSelecting;
  final void Function(String tag)? onTagTap;
  const _NoteCard(
      {required this.note,
      required this.onTap,
      required this.onLongPress,
      this.isSelected = false,
      this.isSelecting = false,
      this.onTagTap});

  Future<void> _handleTap(BuildContext context) async {
    if (isSelecting) {
      onLongPress(); // toggle selection
      return;
    }
    if (note.isLocked) {
      final ok = await _showUnlockDialog(context);
      if (!ok) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Incorrect PIN'), backgroundColor: Colors.red),
          );
        }
        return;
      }
    }
    onTap();
  }

  Future<bool> _showUnlockDialog(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Locked Note'),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(hintText: 'Enter PIN'),
          onSubmitted: (_) => Navigator.pop(dialogContext, true),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Open')),
        ],
      ),
    );
    if (result != true || controller.text.length < 4) return false;
    return note.verifyPin(controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = ColorUtils.noteBackground(note.color, isDark, context);
    final textColor = ColorUtils.textColor(bgColor);
    final subTextColor = ColorUtils.secondaryTextColor(bgColor);

    return InkWell(
      onTap: () => _handleTap(context),
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
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
                // Thumbnail preview
                Container(
                  width: double.infinity,
                  height: 80,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? ColorUtils.noteBackground(note.color, true, context).withValues(alpha: 0.5)
                        : (note.color != null ? bgColor.withValues(alpha: 0.3) : theme.colorScheme.primary.withValues(alpha: 0.08)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: note.isLocked
                      ? const Center(child: Icon(Icons.lock_rounded, size: 28, color: Colors.orange))
                      : Padding(
                          padding: const EdgeInsets.all(10),
                          child: Text(
                            note.content,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.4,
                              color: textColor.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                ),
                if (note.title.isNotEmpty) ...[
                  Row(
                    children: [
                      if (note.isPinned)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(Icons.push_pin_rounded,
                              size: 14, color: theme.colorScheme.primary),
                        ),
                      Expanded(
                        child: Text(note.title,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: textColor)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
                note.isLocked
                    ? Row(children: [
                        const Icon(Icons.lock_rounded,
                            size: 16, color: Colors.orange),
                        const SizedBox(width: 6),
                        Text('Locked',
                            style: TextStyle(
                                color: Colors.orange.shade700, fontSize: 13))
                      ])
                    : const SizedBox.shrink(),
                if (note.tags.isNotEmpty && !note.isLocked) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    children: note.tags
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
                const SizedBox(height: 8),
                Text(_formatDate(note.modifiedAt),
                    style: TextStyle(
                        fontSize: 10,
                        color: subTextColor,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          // Selection checkmark overlay
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
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (now.difference(date).inDays == 0) return 'Today';
    if (now.difference(date).inDays == 1) return 'Yesterday';
    return '${date.day}/${date.month}';
  }
}

class _NotesListPane extends StatelessWidget {
  final String userId;
  final Note? selectedNote;
  final String searchQuery;
  final String? tagFilter;
  final Function(Note) onNoteSelected;

  const _NotesListPane(
      {required this.userId,
      required this.selectedNote,
      required this.searchQuery,
      this.tagFilter,
      required this.onNoteSelected});

  List<Note> _applyFilters(List<Note> notes) {
    if (searchQuery.isEmpty && tagFilter == null) return notes;
    return notes.where((note) {
      if (tagFilter != null && !note.tags.contains(tagFilter)) return false;
      if (searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        final matchesTitle = note.title.toLowerCase().contains(q);
        final matchesContent = note.content.toLowerCase().contains(q);
        final matchesTag = note.tags.any((t) => t.toLowerCase().contains(q));
        if (!matchesTitle && !matchesContent && !matchesTag) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final noteService = Provider.of<NoteService>(context, listen: false);
    return FutureBuilder<List<Note>>(
      future: noteService.getAllNotes(userId),
      builder: (context, futureSnapshot) {
        return StreamBuilder<List<Note>>(
          stream: noteService.watchNotes(userId),
          builder: (context, snapshot) {
            final notes = snapshot.data ?? futureSnapshot.data;
            if (notes == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final filtered = _applyFilters(notes);
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
                final isSelected = selectedNote?.id == note.id;
                return ListTile(
                  selected: isSelected,
                  onTap: () => onNoteSelected(note),
                  title: Text(note.title.isEmpty ? 'Untitled' : note.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(note.content,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _DesktopNoteEditor extends StatefulWidget {
  final Note? note;
  final VoidCallback onNoteDeleted;
  final Function(Note) onNoteUpdated;
  const _DesktopNoteEditor(
      {required this.note,
      required this.onNoteDeleted,
      required this.onNoteUpdated});

  @override
  State<_DesktopNoteEditor> createState() => _DesktopNoteEditorState();
}

class _DesktopNoteEditorState extends State<_DesktopNoteEditor> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController =
        TextEditingController(text: widget.note?.content ?? '');
    _titleController.addListener(_onChanged);
    _contentController.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(_DesktopNoteEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.note?.id != widget.note?.id) {
      _titleController.text = widget.note?.title ?? '';
      _contentController.text = widget.note?.content ?? '';
    }
  }

  void _onChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), _save);
  }

  Future<void> _save() async {
    final noteService = Provider.of<NoteService>(context, listen: false);
    final authService = Provider.of<IAuthService>(context, listen: false);
    final user = authService.getCurrentUser();
    if (user == null) return;

    if (widget.note == null) {
      final newNote = await noteService.createNote(
          userId: user.uid,
          title: _titleController.text,
          content: _contentController.text);
      widget.onNoteUpdated(newNote);
    } else {
      final updated = await noteService.updateNote(widget.note!,
          title: _titleController.text, content: _contentController.text);
      widget.onNoteUpdated(updated);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
                hintText: 'Title', border: InputBorder.none),
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: TextField(
              controller: _contentController,
              decoration: const InputDecoration(
                  hintText: 'Start writing...', border: InputBorder.none),
              maxLines: null,
              style: const TextStyle(fontSize: 18, height: 1.6),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                onPressed: () async {
                  if (widget.note != null) {
                    await Provider.of<NoteService>(context, listen: false)
                        .deleteNote(widget.note!);
                    widget.onNoteDeleted();
                  }
                },
                icon: const Icon(Icons.delete_outline_rounded),
                color: Colors.red,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NoteListTile extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final bool isSelecting;
  const _NoteListTile(
      {required this.note,
      required this.onTap,
      this.onLongPress,
      this.isSelected = false,
      this.isSelecting = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = ColorUtils.noteBackground(note.color, isDark, context);
    final textColor = ColorUtils.textColor(bgColor);

    Widget thumbnail;
    if (note.imageIds.isNotEmpty) {
      final cloudinary = Provider.of<CloudinaryService>(context, listen: false);
      thumbnail = ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          cloudinary.getDirectUrl(note.imageIds.first),
          width: 48,
          height: 48,
          cacheWidth: 96,
          cacheHeight: 96,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.image, size: 18, color: textColor.withValues(alpha: 0.5)),
          ),
        ),
      );
    } else {
      thumbnail = Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: isDark ? Border.all(color: const Color(0xFF313244), width: 1) : null,
        ),
        child: note.isLocked
            ? const Center(child: Icon(Icons.lock_rounded, size: 18, color: Colors.orange))
            : Padding(
                padding: const EdgeInsets.all(6),
                child: Text(
                  note.content,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 7, height: 1.3, color: textColor.withValues(alpha: 0.7)),
                ),
              ),
      );
    }

    return InkWell(
      onTap: isSelecting ? onLongPress : onTap,
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
                padding: const EdgeInsets.only(right: 12),
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
                              color: isDark ? Colors.grey : Colors.grey.shade500)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (!note.isLocked)
                    Text(note.content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            fontSize: 13)),
                  if (note.tags.isNotEmpty && !note.isLocked) ...[
                    const SizedBox(height: 4),
                    Wrap(
                        spacing: 4,
                        children: note.tags
                            .take(3)
                            .map((tag) => Text('#$tag',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: theme.colorScheme.primary.withValues(alpha: 0.7),
                                    fontWeight: FontWeight.w600)))
                            .toList()),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (now.difference(date).inDays == 0) return 'Today';
    if (now.difference(date).inDays == 1) return 'Yesterday';
    return '${date.day}/${date.month}';
  }
}

class _NoteCompactTile extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  const _NoteCompactTile({required this.note, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor =
        theme.brightness == Brightness.dark ? Colors.white : Colors.black87;

    return ListTile(
      onTap: onTap,
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
      subtitle: note.isLocked
          ? Text('Locked',
              style: TextStyle(fontSize: 12, color: Colors.orange.shade700))
          : Text(
              note.content,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12, color: textColor.withValues(alpha: 0.6)),
            ),
      trailing: Text(_formatDate(note.modifiedAt),
          style: const TextStyle(fontSize: 10, color: Colors.grey)),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (now.difference(date).inDays == 0) return 'Today';
    if (now.difference(date).inDays == 1) return 'Yesterday';
    return '${date.day}/${date.month}';
  }
}

class _SpeedDialItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SpeedDialItem(
      {required this.icon, required this.label, required this.onTap});

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
