import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:jot_app/screens/login_screen.dart';
import 'package:jot_app/screens/responsive_notes_screen.dart';
import 'package:jot_app/services/i_auth_service.dart';
import 'package:jot_app/services/note_service.dart';
import 'package:jot_app/services/sync_engine.dart';
import 'package:jot_app/services/todo_service.dart';
import 'package:jot_app/models/auth_state.dart';
import 'package:jot_app/utils/view_mode_provider.dart';
import 'package:jot_app/utils/theme_provider.dart';
import '../widget/stubs.dart';

Widget _buildApp(StubAuthService auth) {
  final noteService = StubNoteService();
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
        initialData: AuthState(status: AuthStatus.unauthenticated),
      ),
    ],
    child: MaterialApp(
      routes: {
        '/': (_) => const LoginScreen(),
        '/notes': (_) => const ResponsiveNotesScreen(),
        '/login': (_) => const LoginScreen(),
      },
    ),
  );
}

void main() {
  group('Auth flow integration', () {
    testWidgets('successful sign-in navigates to ResponsiveNotesScreen', (tester) async {
      final auth = StubAuthService(
        signInResult: AuthResult(success: true),
      );
      await tester.pumpWidget(_buildApp(auth));
      await tester.pump();

      // Fill the form and sign in
      await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'test@test.com');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'password123');
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      // Should navigate to notes screen
      expect(find.byType(ResponsiveNotesScreen), findsOneWidget);
    });

    testWidgets('failed sign-in shows error message on LoginScreen', (tester) async {
      final auth = StubAuthService(
        signInResult: AuthResult(success: false, errorMessage: 'Test error'),
      );
      await tester.pumpWidget(_buildApp(auth));
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'test@test.com');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'wrong-password');
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      // Should stay on login screen and show error
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Test error'), findsOneWidget);
    });
  });
}
