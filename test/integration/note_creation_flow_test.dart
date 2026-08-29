import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:jot_app/screens/responsive_notes_screen.dart';
import 'package:jot_app/services/i_auth_service.dart';
import 'package:jot_app/services/note_service.dart';
import 'package:jot_app/services/sync_engine.dart';
import 'package:jot_app/services/todo_service.dart';
import 'package:jot_app/models/auth_state.dart';
import 'package:jot_app/utils/view_mode_provider.dart';
import 'package:jot_app/utils/theme_provider.dart';
import '../widget/stubs.dart';

void main() {
  group('Note creation flow integration', () {
    testWidgets('created note appears in ResponsiveNotesScreen', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final auth = StubAuthService();
      final noteService = StubNoteService();
      final syncEngine = StubSyncEngine();
      final todoService = TodoService();

      await tester.pumpWidget(MultiProvider(
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
        child: const MaterialApp(home: ResponsiveNotesScreen()),
      ));

      // Create a note via the service
      await noteService.createNote(
        userId: 'test-user',
        title: 'Integration Test Note',
        content: 'Created in integration test',
      );

      await tester.pumpAndSettle();

      // The note title should appear in the screen
      expect(find.text('Integration Test Note'), findsOneWidget);
    });
  });
}
