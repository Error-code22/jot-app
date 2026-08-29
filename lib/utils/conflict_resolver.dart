import '../models/note_model.dart';
import 'i_conflict_resolver.dart';

/// Resolves conflicts between local and cloud note versions
///
/// Implementation Strategy:
/// - Compare modifiedAt timestamps
/// - Most recent timestamp wins (last-write-wins strategy)
/// - If timestamps are identical, use note ID lexicographic comparison as tiebreaker
/// - Logs conflicts for debugging
///
/// Validates: Requirements 3.6
class ConflictResolver implements IConflictResolver {
  @override
  Note resolveConflict(Note localNote, Note cloudNote) {
    // Compare timestamps - most recent wins
    final comparison = localNote.modifiedAt.compareTo(cloudNote.modifiedAt);

    if (comparison > 0) {
      // Local note is more recent
      return localNote;
    } else if (comparison < 0) {
      // Cloud note is more recent
      return cloudNote;
    } else {
      // Timestamps are identical - use note ID lexicographic comparison as tiebreaker
      final idComparison = localNote.id.compareTo(cloudNote.id);

      // The lexicographically greater ID wins, regardless of which side it is on.
      // This ensures deterministic resolution across all devices.
      return idComparison >= 0 ? localNote : cloudNote;
    }
  }

  @override
  bool hasConflict(Note localNote, Note cloudNote) {
    // Ensure we're comparing the same note
    if (localNote.id != cloudNote.id) {
      return false;
    }

    // Notes are in conflict if they have different content or different timestamps
    return localNote.modifiedAt != cloudNote.modifiedAt ||
        localNote.title != cloudNote.title ||
        localNote.content != cloudNote.content ||
        localNote.isDeleted != cloudNote.isDeleted;
  }
}
