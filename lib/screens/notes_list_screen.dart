import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/note_model.dart';
import '../services/note_service.dart';
import '../services/i_auth_service.dart';
import '../services/sync_engine.dart';
import '../widgets/sync_indicator.dart';
import 'note_editor_screen.dart';

/// Notes list screen displaying all user notes in a simple list
class NotesListScreen extends StatelessWidget {
  const NotesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final noteService = Provider.of<NoteService>(context, listen: false);
    final authService = Provider.of<IAuthService>(context, listen: false);
    final syncEngine = Provider.of<SyncEngine>(context, listen: false);
    final user = authService.getCurrentUser();

    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/login');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jot?'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          StreamBuilder(
            stream: syncEngine.syncStatus,
            builder: (context, snapshot) {
              final syncState = snapshot.data;
              if (syncState == null) return const SizedBox.shrink();
              return SyncIndicator(syncState: syncState);
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'signout') _handleSignOut(context, authService);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'signout',
                child: Row(
                  children: [Icon(Icons.logout), SizedBox(width: 8), Text('Sign out')],
                ),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<List<Note>>(
        stream: noteService.watchNotes(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final notes = snapshot.data ?? [];

          return RefreshIndicator(
            onRefresh: () => syncEngine.syncNow(user.uid),
            child: notes.isEmpty
                ? _buildEmptyState(context)
                : _buildNotesList(notes),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const NoteEditorScreen()),
          );
        },
        tooltip: 'Create new note',
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _handleSignOut(BuildContext context, IAuthService authService) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Sign out')),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await authService.signOut();
      if (!context.mounted) return;
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.note_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text('No notes yet', style: TextStyle(fontSize: 18, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildNotesList(List<Note> notes) {
    return ListView.builder(
      itemCount: notes.length,
      padding: const EdgeInsets.all(8),
      itemBuilder: (context, index) {
        final note = notes[index];
        return Card(
          child: ListTile(
            title: Text(note.title.isEmpty ? 'Untitled' : note.title),
            subtitle: Text(
              note.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => NoteEditorScreen(note: note)),
              );
            },
          ),
        );
      },
    );
  }
}
