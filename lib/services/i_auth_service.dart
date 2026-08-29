import '../models/user_model.dart';
import '../models/auth_state.dart';

/// Result of an authentication operation
class AuthResult {
  final bool success;
  final String? errorMessage;
  final User? user;

  AuthResult({
    required this.success,
    this.errorMessage,
    this.user,
  });
}

/// Interface for authentication service
/// 
/// Defines the contract for authentication via Supabase Auth.
/// Implementations should handle sign-in, sign-out, and authentication state management.
abstract class IAuthService {
  /// Sign in with email and password
  /// 
  /// Returns [AuthResult] with success status, user data on success, or error message on failure.
  Future<AuthResult> signInWithEmail(String email, String password);

  /// Sign up with email and password
  /// 
  /// Creates a new account and returns [AuthResult].
  Future<AuthResult> signUpWithEmail(String email, String password, {String? displayName});

  /// Sign in with a Gmail account via OAuth
  /// 
  /// Initiates the Google authentication flow and returns the result.
  Future<AuthResult> signInWithGmail();
  
  /// Attempt to restore session from stored credentials
  /// 
  /// Returns true if session was successfully restored, false otherwise.
  /// This should be called on app startup to auto-authenticate the user.
  Future<bool> restoreSession();
  
  /// Sign out
  /// 
  /// Signs out the current user and clears stored credentials and local data.
  Future<void> signOut();
  
  /// Get current user
  /// 
  /// Returns the currently authenticated user, or null if not authenticated.
  User? getCurrentUser();
  
  /// Check if user is authenticated
  /// 
  /// Returns true if a user is currently authenticated, false otherwise.
  bool isAuthenticated();
  
  /// Get authentication state stream
  /// 
  /// Returns a stream that emits authentication state changes.
  /// Useful for reactive UI updates based on authentication status.
  Stream<AuthState> get authStateChanges;
}
