import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jot_app/widgets/sync_indicator.dart';
import 'package:jot_app/models/sync_state.dart';

Widget _buildIndicator(SyncState state) {
  return MaterialApp(
    home: Scaffold(
      appBar: AppBar(
        actions: [SyncIndicator(syncState: state)],
      ),
    ),
  );
}

void main() {
  group('SyncIndicator icons', () {
    testWidgets('idle shows cloud_done_rounded', (tester) async {
      await tester.pumpWidget(_buildIndicator(
        SyncState(status: SyncStatus.idle, pendingChanges: 0),
      ));
      await tester.pump();
      expect(find.byIcon(Icons.cloud_done_rounded), findsOneWidget);
    });

    testWidgets('success shows cloud_done_rounded', (tester) async {
      await tester.pumpWidget(_buildIndicator(
        SyncState(status: SyncStatus.success, pendingChanges: 0),
      ));
      await tester.pump();
      expect(find.byIcon(Icons.cloud_done_rounded), findsOneWidget);
    });

    testWidgets('syncing shows sync_rounded', (tester) async {
      await tester.pumpWidget(_buildIndicator(
        SyncState(status: SyncStatus.syncing, pendingChanges: 0),
      ));
      await tester.pump();
      expect(find.byIcon(Icons.sync_rounded), findsOneWidget);
    });

    testWidgets('error shows cloud_off_rounded', (tester) async {
      await tester.pumpWidget(_buildIndicator(
        SyncState(status: SyncStatus.error, pendingChanges: 0),
      ));
      await tester.pump();
      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    });

    testWidgets('offline shows cloud_off_rounded', (tester) async {
      await tester.pumpWidget(_buildIndicator(
        SyncState(status: SyncStatus.offline, pendingChanges: 0),
      ));
      await tester.pump();
      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    });
  });

  group('SyncIndicator pending badge', () {
    testWidgets('shows orange dot when pendingChanges > 0 and not syncing', (tester) async {
      await tester.pumpWidget(_buildIndicator(
        SyncState(status: SyncStatus.idle, pendingChanges: 3),
      ));
      await tester.pump();

      // Find the orange 6x6 dot container
      final orangeDots = tester.widgetList<Container>(find.byType(Container)).where((c) {
        final decoration = c.decoration;
        if (decoration is BoxDecoration) {
          return decoration.color == Colors.orange && decoration.shape == BoxShape.circle;
        }
        return false;
      });
      expect(orangeDots.isNotEmpty, isTrue);
    });

    testWidgets('no orange dot when syncing even with pending changes', (tester) async {
      await tester.pumpWidget(_buildIndicator(
        SyncState(status: SyncStatus.syncing, pendingChanges: 3),
      ));
      await tester.pump();

      final orangeDots = tester.widgetList<Container>(find.byType(Container)).where((c) {
        final decoration = c.decoration;
        if (decoration is BoxDecoration) {
          return decoration.color == Colors.orange && decoration.shape == BoxShape.circle;
        }
        return false;
      });
      expect(orangeDots.isEmpty, isTrue);
    });
  });
}
