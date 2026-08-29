import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:jot_app/models/auth_state.dart';
import 'package:jot_app/screens/login_screen.dart';
import 'package:jot_app/services/i_auth_service.dart';
import 'package:jot_app/utils/theme_provider.dart';

import 'widget/stubs.dart';

void main() {
  testWidgets('app smoke test - login screen renders', (WidgetTester tester) async {
    final auth = StubAuthService();
    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider<IAuthService>.value(value: auth),
        StreamProvider<AuthState>.value(
          value: auth.authStateChanges,
          initialData: AuthState(status: AuthStatus.unauthenticated),
        ),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const MaterialApp(home: LoginScreen()),
    ));
    await tester.pump();

    expect(find.text('Jot?'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}
