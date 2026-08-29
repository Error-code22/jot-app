import 'package:mockito/annotations.dart';
import 'package:jot_app/services/i_local_storage_service.dart';
import 'package:jot_app/services/i_sync_engine.dart';
import 'package:jot_app/services/i_remote_storage_service.dart';
import 'package:jot_app/services/i_auth_service.dart';
import 'package:jot_app/services/i_note_service.dart';

@GenerateMocks([
  ILocalStorageService,
  ISyncEngine,
  IRemoteStorageService,
  IAuthService,
  INoteService,
])
void main() {}
