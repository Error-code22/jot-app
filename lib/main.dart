import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'config.dart';
import 'core/app_bootstrapper.dart';
import 'models/auth_state.dart';
import 'screens/login_screen.dart';
import 'screens/responsive_notes_screen.dart';
import 'services/supabase_service.dart';
import 'services/i_auth_service.dart';
import 'services/i_local_storage_service.dart';
import 'services/sync_engine.dart';
import 'services/sync_scheduler.dart';
import 'services/note_service.dart';
import 'services/cloudinary_service.dart';
import 'services/image_compress_service.dart';
import 'services/backup_service.dart';
import 'services/todo_service.dart';
import 'services/notification_service.dart';
import 'services/background_sync_service.dart';
import 'services/feedback_service.dart';
import 'utils/platform_theme.dart';
import 'utils/theme_provider.dart';
import 'utils/view_mode_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('SUPABASE_URL: ${AppConfig.supabaseUrl}');
  
  runApp(const JotApp());
}

class JotApp extends StatefulWidget {
  const JotApp({super.key});

  @override
  State<JotApp> createState() => _JotAppState();
}

class _JotAppState extends State<JotApp> {
  late Future<Map<String, dynamic>> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = AppBootstrapper.initialize();
  }

  void _setupAuthStateListener(BuildContext context) {
    final authService = Provider.of<SupabaseService>(context, listen: false);
    final syncEngine = Provider.of<SyncEngine>(context, listen: false);
    final syncScheduler = Provider.of<SyncScheduler>(context, listen: false);
    final notificationService = Provider.of<NotificationService>(context, listen: false);
    final backgroundSync = Provider.of<BackgroundSyncService>(context, listen: false);
    final todoService = Provider.of<TodoService>(context, listen: false);

    authService.authStateChanges.listen((authState) async {
      if (authState.isAuthenticated && authState.user != null) {
        try {
          await syncEngine.start(authState.user!.uid);
          syncScheduler.start(authState.user!.uid);
          await notificationService.requestPermission();
          await backgroundSync.schedulePeriodicSync();
          // Check todo due dates on login
          await notificationService.checkTodoDueDates(todoService);
        } catch (e) {
          debugPrint('Auth state listener error: $e');
        }
      } else {
        try {
          await syncEngine.stop();
          syncScheduler.stop();
          await backgroundSync.cancelAll();
        } catch (e) {
          debugPrint('Auth state listener error: $e');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Directionality(
            textDirection: TextDirection.ltr,
            child: MaterialApp(
              home: Scaffold(
                body: Center(child: CircularProgressIndicator()),
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          return Directionality(
            textDirection: TextDirection.ltr,
            child: MaterialApp(
              home: Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: SingleChildScrollView(
                      child: Text(
                        'Startup error:\n${snapshot.error}\n\n${snapshot.stackTrace}',
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        final providers = snapshot.data!;
        return MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider(create: (_) => ViewModeProvider()),
            ChangeNotifierProvider(create: (_) {
              final todoService = TodoService();
              final auth = providers['authService'] as SupabaseService;
              final localStorage = providers['localStorage'] as ILocalStorageService;
              final user = auth.getCurrentUser();
              if (user != null) todoService.initialize(user.uid, localStorage);
              return todoService;
            }),
            Provider.value(value: providers['authService'] as SupabaseService),
            Provider<IAuthService>.value(
              value: providers['authService'] as SupabaseService,
            ),
            Provider.value(value: providers['localStorage'] as ILocalStorageService),
            Provider.value(value: providers['supabaseService'] as SupabaseService),
            Provider.value(value: providers['syncEngine'] as SyncEngine),
            Provider.value(value: providers['syncScheduler'] as SyncScheduler),
            Provider.value(value: providers['noteService'] as NoteService),
            Provider.value(value: providers['cloudinary'] as CloudinaryService),
            Provider.value(value: providers['imageCompressor'] as ImageCompressService),
            Provider.value(value: providers['backupService'] as BackupService),
            Provider.value(value: providers['notificationService'] as NotificationService),
            Provider.value(value: providers['backgroundSync'] as BackgroundSyncService),
            Provider.value(value: providers['feedbackService'] as FeedbackService),
            StreamProvider<AuthState>.value(
              value: (providers['authService'] as SupabaseService).authStateChanges,
              initialData: AuthState(
                status: (providers['authService'] as SupabaseService).isAuthenticated()
                    ? AuthStatus.authenticated
                    : AuthStatus.unauthenticated,
                user: (providers['authService'] as SupabaseService).getCurrentUser(),
              ),
            ),
          ],
          child: const _JotAppShell(),
        );
      },
    );
  }
}

class _JotAppShell extends StatelessWidget {
  const _JotAppShell();

  @override
  Widget build(BuildContext context) {
    final authState = Provider.of<AuthState>(context, listen: false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.findAncestorStateOfType<_JotAppState>();
      state?._setupAuthStateListener(context);
    });

    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final isDark = themeProvider.isDark;
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ));
        return MaterialApp(
          title: 'Jot?',
          debugShowCheckedModeBanner: false,
          theme: PlatformTheme.getTheme(Theme.of(context).platform),
          darkTheme: PlatformTheme.getDarkTheme(Theme.of(context).platform),
          themeMode: themeProvider.themeMode,
          initialRoute: '/',
          onGenerateRoute: (settings) {
            Widget builder;
            switch (settings.name) {
              case '/':
                builder = authState.isAuthenticated
                    ? const ResponsiveNotesScreen()
                    : const LoginScreen();
                break;
              case '/notes':
                builder = const ResponsiveNotesScreen();
                break;
              case '/login':
                builder = const LoginScreen();
                break;
              default:
                builder = const LoginScreen();
            }
            return MaterialPageRoute(builder: (context) => builder, settings: settings);
          },
        );
      },
    );
  }
}
