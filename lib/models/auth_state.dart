import 'user_model.dart';

/// Authentication state model for the Jot? application
/// 
/// Represents the current authentication status and user information.
/// Used to track authentication flow progress and manage user session state.

/// Authentication status enumeration
enum AuthStatus {
  /// User is successfully authenticated
  authenticated,
  
  /// User is not authenticated
  unauthenticated,
  
  /// Authentication in progress
  authenticating,
  
  /// Authentication failed with error
  error,
}

/// Authentication state model
class AuthState {
  /// Current authentication status
  final AuthStatus status;
  
  /// Authenticated user information (optional)
  final User? user;
  
  /// Error message from failed authentication (optional)
  final String? errorMessage;

  AuthState({
    required this.status,
    this.user,
    this.errorMessage,
  });

  /// Check if user is authenticated
  bool get isAuthenticated => status == AuthStatus.authenticated;

  /// Create a copy with updated fields
  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is AuthState &&
        other.status == status &&
        other.user == user &&
        other.errorMessage == errorMessage;
  }

  @override
  int get hashCode {
    return Object.hash(
      status,
      user,
      errorMessage,
    );
  }

  @override
  String toString() {
    return 'AuthState(status: $status, user: $user, errorMessage: $errorMessage)';
  }
}
