import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:jot_app/screens/responsive_notes_screen.dart';
import 'package:jot_app/services/i_auth_service.dart';
import 'package:jot_app/services/note_service.dart';
import 'package:jot_app/services/sync_engine.dart';
import 'package:jot_app/services/todo_service.dart';
import 'package:jot_app/models/note_model.dart';
import 'package:jot_app/models/auth_state.dart';
import 'package:jot_app/utils/view_mode_provider.dart';
import 'package:jot_app/utils/theme_provider.dart';
import 'stubs.dart';

List<Note> _makeTwoNotes() {
  final now = DateTime.now();
  return [
    Note(id: 'note-1', userId: 'test-user', title: 'Note Alpha', content: 'Content alpha', createdAt: now, modifiedAt: now),
    Note(id: 'note-2', userId: 'test-user', title: 'Note Beta', content: 'Content beta', createdAt: now, modifiedAt: now),
  ];
}

Widget _buildTestApp(List<Note> notes) {
  final auth = StubAuthService();
  final noteService = StubNoteService(notes: notes);
  final syncEngine = StubSyncEngine();
  final todoService = TodoService();

  return MultiProvider(
    providers: [
      Provider<IAuthService>.value(value: auth),
      Provider<NoteService>.value(value: noteService),
      Provider<SyncEngine>.value(value: syncEngine),
      ChangeNotifierProvider<TodoService>.value(value: todoService),
      ChangeNotifierProvider(create: (_) => ViewModeProvider()),
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      StreamProvider<AuthState>.value(
        value: auth.authStateChanges,
        initialData: AuthState(status: AuthStatus.authenticated, user: auth.getCurrentUser()),
      ),
    ],
    child: const MaterialApp(
      home: ResponsiveNotesScreen(),
    ),
  );
}

void _useMobileViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  group('ResponsiveNotesScreen', () {
    testWidgets('shows both note titles', (tester) async {
      _useMobileViewport(tester);
      await tester.pumpWidget(_buildTestApp(_makeTwoNotes()));
      await tester.pumpAndSettle();
      expect(find.text('Note Alpha'), findsOneWidget);
      expect(find.text('Note Beta'), findsOneWidget);
    });

    testWidgets('shows search field (desktop sidebar)', (tester) async {
      await tester.pumpWidget(_buildTestApp(_makeTwoNotes()));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Search notes...'), findsOneWidget);
    });

    testWidgets('shows empty state when no notes', (tester) async {
      _useMobileViewport(tester);
      await tester.pumpWidget(_buildTestApp([]));
      await tester.pumpAndSettle();
      expect(find.text('Nothing here yet'), findsOneWidget);
    });
  });
}
