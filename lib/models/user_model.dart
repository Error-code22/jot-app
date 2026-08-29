/// User model for the Jot? application
/// 
/// Represents an authenticated user with Gmail account information.
/// Used for authentication state management and user-scoped data access.
class User {
  /// Firebase user ID (unique identifier)
  final String uid;
  
  /// User's email address
  final String email;
  
  /// User's display name (optional)
  final String? displayName;
  
  /// User's profile photo URL (optional)
  final String? photoUrl;
  
  /// Account creation timestamp
  final DateTime createdAt;
  
  /// Last login timestamp (optional)
  final DateTime? lastLoginAt;

  User({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoUrl,
    required this.createdAt,
    this.lastLoginAt,
  });

  /// Convert to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'createdAt': createdAt.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
    };
  }

  /// Create from Firestore JSON
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      uid: json['uid'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String?,
      photoUrl: json['photoUrl'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastLoginAt: json['lastLoginAt'] != null 
          ? DateTime.parse(json['lastLoginAt'] as String)
          : null,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is User &&
        other.uid == uid &&
        other.email == email &&
        other.displayName == displayName &&
        other.photoUrl == photoUrl &&
        other.createdAt == createdAt &&
        other.lastLoginAt == lastLoginAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      uid,
      email,
      displayName,
      photoUrl,
      createdAt,
      lastLoginAt,
    );
  }

  @override
  String toString() {
    return 'User(uid: $uid, email: $email, displayName: $displayName, '
        'photoUrl: $photoUrl, createdAt: $createdAt, lastLoginAt: $lastLoginAt)';
  }
}
