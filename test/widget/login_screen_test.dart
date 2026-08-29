import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:jot_app/screens/login_screen.dart';
import 'package:jot_app/models/auth_state.dart';
import 'package:jot_app/services/i_auth_service.dart';
import 'package:jot_app/utils/theme_provider.dart';
import 'stubs.dart';

Widget _buildTestApp({StubAuthService? authService}) {
  final auth = authService ?? StubAuthService();
  return MultiProvider(
    providers: [
      Provider<IAuthService>.value(value: auth),
      StreamProvider<AuthState>.value(
        value: auth.authStateChanges,
        initialData: AuthState(status: AuthStatus.unauthenticated),
      ),
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
    ],
    child: const MaterialApp(
      home: LoginScreen(),
    ),
  );
}

void main() {
  group('LoginScreen', () {
    testWidgets('shows app title Jot?', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      expect(find.text('Jot?'), findsOneWidget);
    });

    testWidgets('shows email and password fields', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
    });

    testWidgets('Sign In button is an ElevatedButton', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      final button = find.ancestor(
        of: find.text('Sign In'),
        matching: find.byType(ElevatedButton),
      );
      expect(button, findsOneWidget);
    });

    testWidgets('toggles between sign in and sign up', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      expect(find.text('Sign In'), findsOneWidget);
      final toggle = find.text("Don't have an account? Sign Up");
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pump();
      expect(find.text('Create Account'), findsWidgets);
      expect(find.widgetWithText(TextFormField, 'Display Name'), findsOneWidget);
    });

    testWidgets('shows validation error for empty email', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      await tester.tap(find.text('Sign In'));
      await tester.pump();
      expect(find.text('Please enter your email'), findsOneWidget);
    });

    testWidgets('shows error message when sign-in fails', (tester) async {
      final failAuth = StubAuthService(
        signInResult: AuthResult(success: false, errorMessage: 'Test error'),
      );
      await tester.pumpWidget(_buildTestApp(authService: failAuth));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'test@test.com');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'password123');
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();
      expect(find.text('Test error'), findsOneWidget);
    });
  });
}
