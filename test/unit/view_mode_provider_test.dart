import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jot_app/utils/view_mode_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // -------------------------------------------------------------------------
  // Task 14.3 — defaults to grid on first install (req 7.6, 7.8)
  // -------------------------------------------------------------------------
  test('defaults to grid mode when no preference stored (req 7.6, 7.8)', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = ViewModeProvider();
    // Initial value before async load
    expect(provider.mode, ViewMode.grid);
    // After async load completes
    await Future.delayed(const Duration(milliseconds: 50));
    expect(provider.mode, ViewMode.grid);
  });

  // -------------------------------------------------------------------------
  // Property 7 — ViewMode persistence round-trip
  // -------------------------------------------------------------------------
  group('ViewMode persistence round-trip (Property 7)', () {
    for (final mode in ViewMode.values) {
      test('setMode(${mode.name}) is restored on next load', () async {
        SharedPreferences.setMockInitialValues({});
        final provider1 = ViewModeProvider();
        await Future.delayed(const Duration(milliseconds: 50));

        await provider1.setMode(mode);

        // Simulate app restart by creating a new provider instance
        final provider2 = ViewModeProvider();
        await Future.delayed(const Duration(milliseconds: 50));

        expect(provider2.mode, mode);
      });
    }
  });

  // -------------------------------------------------------------------------
  // Falls back to grid if stored value is invalid (req 7.8)
  // -------------------------------------------------------------------------
  test('falls back to grid if stored value is invalid (req 7.8)', () async {
    SharedPreferences.setMockInitialValues({'view_mode': 'invalid_mode'});
    final provider = ViewModeProvider();
    await Future.delayed(const Duration(milliseconds: 50));
    expect(provider.mode, ViewMode.grid);
  });
}
