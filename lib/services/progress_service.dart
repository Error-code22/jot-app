import 'dart:io';
import 'package:path/path.dart' as path;
import '../models/progress_entry.dart';
import 'i_progress_service.dart';

/// Implementation of progress tracking service
/// Manages append-only PROGRESS.md file for development history
class ProgressService implements IProgressService {
  final String _progressFileName = 'PROGRESS.md';

  /// Get the progress file path
  /// In a real app, this would be the project root
  /// For testing, we can inject the directory
  String getProgressFilePath([String? directory]) {
    final dir = directory ?? Directory.current.path;
    return path.join(dir, _progressFileName);
  }

  @override
  Future<void> addEntry(String message, [String? directory]) async {
    final filePath = getProgressFilePath(directory);
    final file = File(filePath);

    // Create file with header if it doesn't exist
    if (!await file.exists()) {
      await file.writeAsString('# Development Progress\n\n');
    }

    // Create progress entry with current timestamp
    final entry = ProgressEntry(
      timestamp: DateTime.now().toUtc(),
      message: message,
    );

    // Append entry to file
    final markdown = entry.toMarkdown();
    await file.writeAsString('$markdown\n', mode: FileMode.append);
  }

  @override
  Future<List<ProgressEntry>> readEntries([String? directory]) async {
    final filePath = getProgressFilePath(directory);
    final file = File(filePath);

    // Return empty list if file doesn't exist
    if (!await file.exists()) {
      return [];
    }

    try {
      // Read file content
      final content = await file.readAsString();

      // Split into lines
      final lines = content.split('\n');

      // Parse each line into ProgressEntry
      final entries = <ProgressEntry>[];
      for (final line in lines) {
        final entry = ProgressEntry.fromMarkdown(line);
        if (entry != null) {
          entries.add(entry);
        }
      }

      return entries;
    } catch (e) {
      throw Exception('Failed to read progress file: $e');
    }
  }
}
