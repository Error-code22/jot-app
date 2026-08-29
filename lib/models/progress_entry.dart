/// Model representing a single progress entry in PROGRESS.md
class ProgressEntry {
  final DateTime timestamp;
  final String message;

  ProgressEntry({
    required this.timestamp,
    required this.message,
  });

  /// Convert to markdown format
  /// Format: - **YYYY-MM-DDTHH:MM:SS.sssZ**: message
  String toMarkdown() {
    return '- **${timestamp.toIso8601String()}**: $message';
  }

  /// Parse from markdown line
  /// Expected format: - **YYYY-MM-DDTHH:MM:SS.sssZ**: message
  static ProgressEntry? fromMarkdown(String line) {
    // Remove leading/trailing whitespace
    final trimmed = line.trim();

    // Check if line starts with "- **"
    if (!trimmed.startsWith('- **')) {
      return null;
    }

    // Find the closing "**:"
    final closingIndex = trimmed.indexOf('**:', 4);
    if (closingIndex == -1) {
      return null;
    }

    // Extract timestamp string
    final timestampStr = trimmed.substring(4, closingIndex);

    // Extract message (skip "**: ")
    final message = trimmed.substring(closingIndex + 4).trim();

    // Parse timestamp
    try {
      final timestamp = DateTime.parse(timestampStr);
      return ProgressEntry(
        timestamp: timestamp,
        message: message,
      );
    } catch (e) {
      // Invalid timestamp format
      return null;
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProgressEntry &&
        other.timestamp == timestamp &&
        other.message == message;
  }

  @override
  int get hashCode => timestamp.hashCode ^ message.hashCode;

  @override
  String toString() {
    return 'ProgressEntry(timestamp: $timestamp, message: $message)';
  }
}
