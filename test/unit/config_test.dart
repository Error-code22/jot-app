import 'package:flutter_test/flutter_test.dart';
import 'package:jot_app/config.dart';

void main() {
  group('AppConfig', () {
    test('supabase URL is configured', () {
      expect(AppConfig.supabaseUrl, startsWith('https://'));
      expect(AppConfig.supabaseUrl, endsWith('.supabase.co'));
    });

    test('anon key is a JWT', () {
      expect(AppConfig.supabaseAnonKey, startsWith('eyJ'));
    });

    test('edge function base URL derives from supabase URL', () {
      expect(
        AppConfig.edgeFunctionBaseUrl,
        '${AppConfig.supabaseUrl}/functions/v1',
      );
    });
  });
}
