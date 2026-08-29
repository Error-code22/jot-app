import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:jot_app/screens/note_editor_screen.dart';
import 'package:jot_app/services/i_auth_service.dart';
import 'package:jot_app/services/note_service.dart';
import 'package:jot_app/utils/view_mode_provider.dart';
import 'package:jot_app/utils/theme_provider.dart';
import 'stubs.dart';

Widget _buildTestApp() {
  final auth = StubAuthService();
  final notes = StubNoteService();
  return MultiProvider(
    providers: [
      Provider<IAuthService>.value(value: auth),
      Provider<NoteService>.value(value: notes),
      ChangeNotifierProvider(create: (_) => ViewModeProvider()),
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
    ],
    child: const MaterialApp(
      home: NoteEditorScreen(),
    ),
  );
}

void main() {
  group('NoteEditorScreen', () {
    testWidgets('shows title text field', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      expect(find.widgetWithText(TextField, 'Title'), findsOneWidget);
    });

    testWidgets('shows content text field', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      expect(find.widgetWithText(TextField, 'Start writing...'), findsOneWidget);
    });

    testWidgets('shows checklist toggle button', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      expect(find.byTooltip('Toggle checklist'), findsOneWidget);
    });

    testWidgets('shows word count', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      expect(find.textContaining('words'), findsOneWidget);
    });

    testWidgets('shows image attachment button', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      expect(find.byTooltip('Attach image'), findsOneWidget);
    });
  });
}
