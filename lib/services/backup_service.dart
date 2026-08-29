import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:archive/archive.dart';
import '../models/note_model.dart';
import 'i_local_storage_service.dart';

/// Service for backing up and exporting notes.
class BackupService {
  final ILocalStorageService _localStorage;

  BackupService(this._localStorage);

  /// Export all notes as JSON
  Future<String> exportNotesAsJson(String userId) async {
    try {
      final notes = await _localStorage.getAllNotes(userId);
      final jsonData = notes.map((note) => note.toJson()).toList();
      return jsonEncode(jsonData);
    } catch (e) {
      debugPrint('Export JSON error: $e');
      rethrow;
    }
  }

  /// Export notes as a ZIP file with images
  Future<File> exportNotesAsZip(String userId) async {
    try {
      final notes = await _localStorage.getAllNotes(userId);
      final archive = Archive();

      // Add notes JSON
      final notesJson = notes.map((note) => note.toJson()).toList();
      final notesData = utf8.encode(jsonEncode(notesJson));
      archive.addFile(ArchiveFile('notes.json', notesData.length, notesData));

      // Add individual note files for easy import
      for (final note in notes) {
        final noteData = utf8.encode(jsonEncode(note.toJson()));
        archive.addFile(ArchiveFile(
          'notes/${note.id}.json',
          noteData.length,
          noteData,
        ));
      }

      // Create ZIP
      final zipData = ZipEncoder().encode(archive);
      if (zipData == null) throw Exception('Failed to create ZIP');

      // Save to file
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${tempDir.path}/jot_backup_$timestamp.zip');
      await file.writeAsBytes(zipData);

      return file;
    } catch (e) {
      debugPrint('Export ZIP error: $e');
      rethrow;
    }
  }

  /// Share notes as JSON
  Future<void> shareNotesAsJson(String userId) async {
    try {
      final json = await exportNotesAsJson(userId);
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/jot_notes_export.json');
      await file.writeAsString(json);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'My Jot Notes',
      );
    } catch (e) {
      debugPrint('Share JSON error: $e');
      rethrow;
    }
  }

  /// Share notes as ZIP
  Future<void> shareNotesAsZip(String userId) async {
    try {
      final file = await exportNotesAsZip(userId);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'My Jot Notes Backup',
      );
    } catch (e) {
      debugPrint('Share ZIP error: $e');
      rethrow;
    }
  }

  /// Import notes from JSON
  Future<int> importNotesFromJson(String userId, String jsonContent) async {
    try {
      final List<dynamic> jsonData = jsonDecode(jsonContent);
      int importedCount = 0;

      for (final item in jsonData) {
        final note = Note.fromJson(item as Map<String, dynamic>);
        // Check if note already exists
        final existing = await _localStorage.getNoteById(note.id);
        if (existing == null) {
          await _localStorage.insertNote(note);
          importedCount++;
        }
      }

      return importedCount;
    } catch (e) {
      debugPrint('Import JSON error: $e');
      rethrow;
    }
  }

  /// Import notes from ZIP file
  Future<int> importNotesFromZip(String userId, File zipFile) async {
    try {
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      int importedCount = 0;

      for (final file in archive) {
        if (file.isFile && file.name.endsWith('.json')) {
          final data = utf8.decode(file.content as List<int>);
          final note = Note.fromJson(jsonDecode(data) as Map<String, dynamic>);
          final existing = await _localStorage.getNoteById(note.id);
          if (existing == null) {
            await _localStorage.insertNote(note);
            importedCount++;
          }
        }
      }

      return importedCount;
    } catch (e) {
      debugPrint('Import ZIP error: $e');
      rethrow;
    }
  }

  /// Create a backup to app documents directory
  Future<String> createLocalBackup(String userId) async {
    try {
      final file = await exportNotesAsZip(userId);
      final appDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${appDir.path}/jot_backups');
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final backupPath = '${backupDir.path}/backup_$timestamp.zip';
      await file.copy(backupPath);
      
      return backupPath;
    } catch (e) {
      debugPrint('Local backup error: $e');
      rethrow;
    }
  }

  /// Get list of local backups
  Future<List<BackupInfo>> getLocalBackups() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${appDir.path}/jot_backups');
      if (!await backupDir.exists()) return [];

      final backups = <BackupInfo>[];
      await for (final entity in backupDir.list()) {
        if (entity is File && entity.path.endsWith('.zip')) {
          final stat = await entity.stat();
          backups.add(BackupInfo(
            path: entity.path,
            fileName: entity.path.split(Platform.pathSeparator).last,
            size: stat.size,
            createdAt: stat.modified,
          ));
        }
      }

      backups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return backups;
    } catch (e) {
      debugPrint('Get backups error: $e');
      return [];
    }
  }

  /// Delete a local backup
  Future<void> deleteBackup(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Delete backup error: $e');
    }
  }

  /// Get backup size in human-readable format
  static String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Information about a backup file
class BackupInfo {
  final String path;
  final String fileName;
  final int size;
  final DateTime createdAt;

  BackupInfo({
    required this.path,
    required this.fileName,
    required this.size,
    required this.createdAt,
  });
}
