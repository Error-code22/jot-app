import 'dart:typed_data';

import '../models/note_model.dart';

/// Interface for remote note storage operations.
/// 
/// Abstraction layer for cloud providers (Firestore, Telegram, etc.)
abstract class IRemoteStorageService {
  /// Upload a note to remote storage
  /// 
  /// Creates or updates a note in the cloud.
  /// Returns the updated note (with remoteId if it was newly created).
  Future<Note> uploadNote(Note note);
  
  /// Download a note from remote storage by ID
  /// 
  /// Returns the note if found, null otherwise.
  Future<Note?> downloadNote(String userId, String noteId);
  
  /// Download all notes for a specific user
  /// 
  /// Returns a list of all notes belonging to the specified user.
  Future<List<Note>> downloadAllNotes(String userId);
  
  /// Delete a note from remote storage
  /// 
  /// Permanently removes or marks the note as deleted in the cloud.
  Future<void> deleteNote(String userId, String noteId, {String? remoteId});
  
  /// Listen to note changes for current user (if supported)
  /// 
  /// Returns a stream that emits the complete list of notes
  /// whenever any note is added, modified, or deleted.
  Stream<List<Note>> watchNotes(String userId);
  
  /// Batch upload multiple notes
  Future<void> batchUploadNotes(List<Note> notes);

  /// Upload an image to remote storage
  ///
  /// Accepts raw image bytes and a filename hint.
  /// Returns a file ID or path that can later be resolved to a URL.
  Future<String> uploadImage(Uint8List bytes, String filename);

  /// Retrieve a publicly accessible URL for a previously uploaded image
  ///
  /// [fileId] is the identifier returned by [uploadImage].
  /// Returns the URL string for the image.
  Future<String> getImageUrl(String fileId);
}
