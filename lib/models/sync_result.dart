/// Result of a synchronization operation
/// 
/// Contains statistics about the sync operation including:
/// - Number of notes uploaded to cloud
/// - Number of notes downloaded from cloud
/// - Number of conflicts resolved
/// - Any errors encountered during sync
/// 
/// Validates: Requirements 3.5, 3.6
class SyncResult {
  final int notesUploaded;
  final int notesDownloaded;
  final int conflictsResolved;
  final List<String> errors;

  SyncResult({
    required this.notesUploaded,
    required this.notesDownloaded,
    required this.conflictsResolved,
    required this.errors,
  });

  /// Create an empty sync result
  factory SyncResult.empty() {
    return SyncResult(
      notesUploaded: 0,
      notesDownloaded: 0,
      conflictsResolved: 0,
      errors: [],
    );
  }

  /// Check if sync was successful (no errors)
  bool get isSuccess => errors.isEmpty;

  /// Check if any notes were synced
  bool get hasChanges => notesUploaded > 0 || notesDownloaded > 0;

  @override
  String toString() {
    return 'SyncResult(uploaded: $notesUploaded, downloaded: $notesDownloaded, '
        'conflicts: $conflictsResolved, errors: ${errors.length})';
  }
}
