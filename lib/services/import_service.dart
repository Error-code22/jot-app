import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'i_local_storage_service.dart';
import 'import_service_stub.dart' if (dart.library.io) 'import_service_io.dart';

export 'import_service_stub.dart' if (dart.library.io) 'import_service_io.dart'
    show importTxtFolderImpl, importFilesImpl;

class ImportService {
  final ILocalStorageService _storage;
  static final _uuid = const Uuid();
  static const List<String> supportedExtensions = ['.txt', '.md', '.text', '.markdown'];

  ImportService(this._storage);

  Future<ImportResult> importTxtFolder(String folderPath, String userId) async {
    if (kIsWeb) return ImportResult(success: false, message: 'Not supported on web', imported: 0, skipped: 0);
    return importTxtFolderImpl(folderPath, userId, _storage, _uuid, supportedExtensions);
  }

  Future<ImportResult> importFiles(List<String> paths, String userId) async {
    if (kIsWeb) return ImportResult(success: false, message: 'Not supported on web', imported: 0, skipped: 0);
    return importFilesImpl(paths, userId, _storage, _uuid, supportedExtensions);
  }
}

class ImportResult {
  final bool success;
  final int imported;
  final int skipped;
  final String message;

  ImportResult({required this.success, this.imported = 0, this.skipped = 0, required this.message});
}
