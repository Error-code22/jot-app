import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';

// Conditional native-only imports
import 'app_bootstrapper_stub.dart'
    if (dart.library.io) 'app_bootstrapper_native.dart' as native;

import '../services/supabase_service.dart';
import '../services/sync_engine.dart';
import '../services/sync_scheduler.dart';
import '../services/note_service.dart';
import '../services/cloudinary_service.dart';
import '../services/image_compress_service.dart';
import '../services/backup_service.dart';
import '../services/todo_service.dart';
import '../services/notification_service.dart';
import '../services/background_sync_service.dart';
import '../services/feedback_service.dart';

class AppBootstrapper {
  static Future<Map<String, dynamic>> initialize() async {
    // 1. Initialize platform services (sqflite FFI, etc.)
    await native.initPlatformServices('');

    // 2. Initialize Supabase with embedded config
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
    );

    // 3. Initialize Local Storage
    final localStorage = native.createLocalStorage();
    await localStorage.initialize();

    // 3. Initialize Core Services
    final supabaseService = SupabaseService();

    try {
      await supabaseService.restoreSession();
    } catch (e) {
      debugPrint('Session restore error: $e');
    }

    // 4. Initialize Cloudinary (talks to Edge Function)
    final cloudinary = CloudinaryService(
      edgeFunctionBaseUrl: AppConfig.edgeFunctionBaseUrl,
    );

    // 5. Initialize Image Compression
    final imageCompressor = ImageCompressService();

    // 6. Initialize Sync Engine
    final syncEngine = SyncEngine(localStorage, supabaseService);

    // 7. Initialize Sync Scheduler
    final syncScheduler = SyncScheduler(syncEngine);

    // 8. Initialize Note Service
    final noteService = NoteService(localStorage, syncEngine);

    // 9. Initialize Backup Service
    final backupService = BackupService(localStorage);

    // 10. Initialize Todo Service
    final todoService = TodoService();

    // 11. Initialize Notification Service
    final notificationService = NotificationService();
    await notificationService.initialize();

    // 12. Initialize Background Sync Service
    final backgroundSync = BackgroundSyncService(
      notificationService: notificationService,
    );
    await backgroundSync.initialize();

    // 13. Initialize Feedback Service
    final feedbackService = FeedbackService();

    return {
      'authService': supabaseService,
      'localStorage': localStorage,
      'supabaseService': supabaseService,
      'syncEngine': syncEngine,
      'syncScheduler': syncScheduler,
      'noteService': noteService,
      'cloudinary': cloudinary,
      'imageCompressor': imageCompressor,
      'backupService': backupService,
      'todoService': todoService,
      'notificationService': notificationService,
      'backgroundSync': backgroundSync,
      'feedbackService': feedbackService,
    };
  }
}
