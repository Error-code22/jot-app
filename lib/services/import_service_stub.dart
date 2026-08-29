import 'package:uuid/uuid.dart';
import 'i_local_storage_service.dart';
import 'import_service.dart';

Future<ImportResult> importTxtFolderImpl(String folderPath, String userId,
    ILocalStorageService storage, Uuid uuid, List<String> exts) async {
  return ImportResult(success: false, message: 'Not supported on this platform', imported: 0, skipped: 0);
}

Future<ImportResult> importFilesImpl(List<String> paths, String userId,
    ILocalStorageService storage, Uuid uuid, List<String> exts) async {
  return ImportResult(success: false, message: 'Not supported on this platform', imported: 0, skipped: 0);
}
