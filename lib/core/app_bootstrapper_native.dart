import 'dart:ffi';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../services/i_local_storage_service.dart';
import '../services/local_storage_service.dart';

/// Native (desktop/mobile) platform initialization.
Future<void> initPlatformServices(String projectId) async {
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    // Manually load sqlite3.dll before sqfliteFfiInit
    // This bypasses the broken native asset resolver in AOT builds
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final dllPath = '$exeDir${Platform.pathSeparator}sqlite3.dll';

    if (await File(dllPath).exists()) {
      DynamicLibrary.open(dllPath);
    }

    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  } else if (Platform.isAndroid || Platform.isIOS) {
    // Mobile platform init
  }
}

ILocalStorageService createLocalStorage() => LocalStorageService();
