import '../models/note_model.dart';

/// Interface for resolving conflicts between local and cloud note versions
/// 
/// Conflicts occur when the same note is modified on multiple devices.
/// The resolver determines which version should be kept.
abstract class IConflictResolver {
  /// Resolve conflict between local and cloud versions
  /// 
  /// Returns the note version that should be kept based on the conflict
  /// resolution strategy (most recent timestamp wins).
  /// 
  /// Parameters:
  /// - [localNote]: The version of the note stored locally
  /// - [cloudNote]: The version of the note from Firestore
  /// 
  /// Returns: The note that should be kept
  Note resolveConflict(Note localNote, Note cloudNote);
  
  /// Determine if notes are in conflict
  /// 
  /// Two notes are in conflict if they have the same ID but different
  /// content or timestamps.
  /// 
  /// Parameters:
  /// - [localNote]: The version of the note stored locally
  /// - [cloudNote]: The version of the note from Firestore
  /// 
  /// Returns: true if the notes are in conflict, false otherwise
  bool hasConflict(Note localNote, Note cloudNote);
}
