/// Model for IDE collaboration configuration
/// Represents the shared configuration file readable by Kiro, Antigravity, and Cursor IDEs
class IDEConfig {
  final String projectName;
  final String flutterVersion;
  final List<String> supportedPlatforms;
  final Map<String, dynamic> sharedState;
  final DateTime lastModified;

  IDEConfig({
    required this.projectName,
    required this.flutterVersion,
    required this.supportedPlatforms,
    required this.sharedState,
    required this.lastModified,
  });

  /// Convert to JSON for file storage
  Map<String, dynamic> toJson() {
    return {
      'projectName': projectName,
      'flutterVersion': flutterVersion,
      'supportedPlatforms': supportedPlatforms,
      'sharedState': sharedState,
      'lastModified': lastModified.toIso8601String(),
    };
  }

  /// Create from JSON
  factory IDEConfig.fromJson(Map<String, dynamic> json) {
    return IDEConfig(
      projectName: json['projectName'] as String,
      flutterVersion: json['flutterVersion'] as String,
      supportedPlatforms: (json['supportedPlatforms'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      sharedState: json['sharedState'] as Map<String, dynamic>,
      lastModified: DateTime.parse(json['lastModified'] as String),
    );
  }

  /// Create a copy with updated fields
  IDEConfig copyWith({
    String? projectName,
    String? flutterVersion,
    List<String>? supportedPlatforms,
    Map<String, dynamic>? sharedState,
    DateTime? lastModified,
  }) {
    return IDEConfig(
      projectName: projectName ?? this.projectName,
      flutterVersion: flutterVersion ?? this.flutterVersion,
      supportedPlatforms: supportedPlatforms ?? this.supportedPlatforms,
      sharedState: sharedState ?? this.sharedState,
      lastModified: lastModified ?? this.lastModified,
    );
  }
}
