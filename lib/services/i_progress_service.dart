import '../models/progress_entry.dart';

/// Interface for progress tracking service
/// Manages the append-only PROGRESS.md file for development history
abstract class IProgressService {
  /// Append a new progress entry to PROGRESS.md
  /// Creates the file if it doesn't exist
  /// Optional [directory] overrides the default directory
  Future<void> addEntry(String message, [String? directory]);

  /// Read all progress entries from PROGRESS.md
  /// Returns empty list if file doesn't exist
  /// Optional [directory] overrides the default directory
  Future<List<ProgressEntry>> readEntries([String? directory]);
}
