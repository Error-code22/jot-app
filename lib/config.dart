/// Supabase configuration.
/// The anon key is public by design — security is enforced by RLS policies.
/// Critical keys (service role, Cloudinary) live in Edge Functions only.
class AppConfig {
  static const String supabaseUrl = 'https://bvgtzjsnqhqyeyinbhdk.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ2Z3R6anNucWhxeWV5aW5iaGRrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ1MDk4MDMsImV4cCI6MjEwMDA4NTgwM30.clcpOq_iVv-krXR-aLYrYYjmwlZ8Gxr6waWzsmo1MKw';

  /// Base URL for Supabase Edge Functions
  static const String edgeFunctionBaseUrl = '$supabaseUrl/functions/v1';
}
