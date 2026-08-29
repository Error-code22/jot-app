import '../services/i_local_storage_service.dart';
import '../services/web_storage_service.dart';

/// Web stub — no native platform initialization needed.
Future<void> initPlatformServices(String projectId) async {
  // Web: nothing to initialize natively.
}

ILocalStorageService createLocalStorage() => WebStorageService();
