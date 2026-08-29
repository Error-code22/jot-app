import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/note_model.dart';
import 'i_local_storage_service.dart';
import 'import_service.dart';

Future<ImportResult> importTxtFolderImpl(String folderPath, String userId,
    ILocalStorageService storage, Uuid uuid, List<String> exts) async {
  final dir = Directory(folderPath);
  if (!await dir.exists()) {
    return ImportResult(success: false, message: 'Folder not found: $folderPath', imported: 0, skipped: 0);
  }
  final files = await dir
      .list(recursive: true)
      .where((f) => f is File && exts.any((e) => f.path.toLowerCase().endsWith(e)))
      .cast<File>()
      .toList();
  if (files.isEmpty) {
    return ImportResult(success: false, message: 'No supported files found (.txt, .md)', imported: 0, skipped: 0);
  }
  return _doImport(files, userId, folderPath, storage, uuid, exts);
}

Future<ImportResult> importFilesImpl(List<String> paths, String userId,
    ILocalStorageService storage, Uuid uuid, List<String> exts) async {
  final files = <File>[];
  for (final p in paths) {
    final f = File(p);
    if (await f.exists()) files.add(f);
  }
  if (files.isEmpty) {
    return ImportResult(success: false, message: 'No valid files found', imported: 0, skipped: 0);
  }
  return _doImport(files, userId, null, storage, uuid, exts);
}

Future<ImportResult> _doImport(List<File> files, String userId, String? basePath,
    ILocalStorageService storage, Uuid uuid, List<String> exts) async {
  int imported = 0, skipped = 0;
  for (final file in files) {
    try {
      final content = await file.readAsString();
      final filename = file.path.split(Platform.pathSeparator).last;
      String title = filename;
      for (final e in exts) {
        title = title.replaceAll(RegExp('${RegExp.escape(e)}\$', caseSensitive: false), '');
      }
      title = title
          .replaceAll(RegExp(r'\s*\(\d+\)\s*$'), '')
          .replaceAll(RegExp(r'_\d{6}_\d{6}$'), '')
          .replaceAll(RegExp(r'_+$'), '')
          .trim();
      if (title.isEmpty) title = 'Untitled';
      final tags = <String>['imported'];
      if (basePath != null) {
        final rel = file.parent.path
            .replaceFirst(basePath, '')
            .replaceAll('\\', '/')
            .replaceAll('/', '')
            .trim();
        if (rel.isNotEmpty) tags.add(rel.toLowerCase());
      }
      final now = DateTime.now();
      await storage.insertNote(Note(
        id: uuid.v4(),
        userId: userId,
        title: title,
        content: content.trim(),
        createdAt: now,
        modifiedAt: now,
        tags: tags,
      ));
      imported++;
    } catch (e) {
      debugPrint('Import error for ${file.path}: $e');
      skipped++;
    }
  }
  final msg = imported > 0
      ? 'Imported $imported note${imported == 1 ? '' : 's'}${skipped > 0 ? ', $skipped failed' : ''}'
      : 'Import failed — $skipped error${skipped == 1 ? '' : 's'}';
  return ImportResult(success: imported > 0, imported: imported, skipped: skipped, message: msg);
}
