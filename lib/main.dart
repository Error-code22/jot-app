import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'config.dart';
import 'core/app_bootstrapper.dart';
import 'models/auth_state.dart';
import 'screens/login_screen.dart';
import 'screens/responsive_notes_screen.dart';
import 'screens/update_screen.dart';
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
import 'services/app_settings.dart';
import 'services/biometric_service.dart';
import 'services/audio_service.dart';
import 'services/update_service.dart';
import 'services/share_link_service.dart';
import 'utils/platform_theme.dart';
import 'utils/theme_provider.dart';
import 'utils/view_mode_provider.dart';
import 'widgets/conflict_resolver_dialog.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('Jot starting: ${AppConfig.supabaseUrl}');
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
        final authService = providers['authService'] as SupabaseService;
        final settings = providers['settings'] as AppSettings;

        return MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider(create: (_) => ViewModeProvider()),
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(
              value: providers['todoService'] as TodoService,
            ),
            Provider.value(value: authService),
            Provider<IAuthService>.value(value: authService),
            Provider.value(
                value: providers['localStorage'] as ILocalStorageService),
            Provider.value(
                value: providers['supabaseService'] as SupabaseService),
            Provider.value(value: providers['syncEngine'] as SyncEngine),
            Provider.value(value: providers['syncScheduler'] as SyncScheduler),
            Provider.value(value: providers['noteService'] as NoteService),
            Provider.value(value: providers['cloudinary'] as CloudinaryService),
            Provider.value(
                value: providers['imageCompressor'] as ImageCompressService),
            Provider.value(value: providers['backupService'] as BackupService),
            Provider.value(
                value: providers['notificationService'] as NotificationService),
            Provider.value(
                value: providers['backgroundSync'] as BackgroundSyncService),
            Provider.value(
                value: providers['feedbackService'] as FeedbackService),
            Provider.value(
                value: providers['biometricService'] as BiometricService),
            Provider.value(value: providers['audioService'] as AudioService),
            Provider.value(value: providers['updateService'] as UpdateService),
            Provider.value(
                value: providers['shareLinkService'] as ShareLinkService),
            StreamProvider<AuthState>.value(
              value: authService.authStateChanges,
              initialData: AuthState(
                status: authService.isAuthenticated()
                    ? AuthStatus.authenticated
                    : AuthStatus.unauthenticated,
                user: authService.getCurrentUser(),
              ),
            ),
          ],
          child: const _JotAppShell(),
        );
      },
    );
  }
}

class _JotAppShell extends StatefulWidget {
  const _JotAppShell();

  @override
  State<_JotAppShell> createState() => _JotAppShellState();
}

class _JotAppShellState extends State<_JotAppShell> {
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<List<SyncConflict>>? _conflictSubscription;
  String? _activeUserId;
  bool _servicesSubscribed = false;
  bool _permissionRequested = false;
  bool _conflictDialogOpen = false;
  bool _updateCheckStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_servicesSubscribed) return;
    _servicesSubscribed = true;

    final authService = context.read<SupabaseService>();
    final syncEngine = context.read<SyncEngine>();

    _authSubscription = authService.authStateChanges.listen(_handleAuthState);
    _conflictSubscription = syncEngine.conflicts.listen(_handleConflicts);

    // The initial auth event may have been emitted before this widget mounted.
    final user = authService.getCurrentUser();
    if (user != null) {
      _handleAuthState(AuthState(status: AuthStatus.authenticated, user: user));
    }
  }

  Future<void> _handleAuthState(AuthState state) async {
    if (!mounted) return;

    final syncEngine = context.read<SyncEngine>();
    final scheduler = context.read<SyncScheduler>();
    final notificationService = context.read<NotificationService>();
    final backgroundSync = context.read<BackgroundSyncService>();
    final todoService = context.read<TodoService>();
    final localStorage = context.read<ILocalStorageService>();
    final settings = context.read<AppSettings>();

    if (state.isAuthenticated && state.user != null) {
      final userId = state.user!.uid;
      if (_activeUserId == userId) return;
      _activeUserId = userId;

      try {
        await todoService.initialize(userId, localStorage);
        await syncEngine.start(userId);
        await scheduler.start(userId);
        if (!_permissionRequested &&
            (settings.todoReminders || settings.dueDateNotifications)) {
          _permissionRequested = true;
          await notificationService.requestPermission();
        }
        if (settings.dueDateNotifications) {
          await notificationService.checkTodoDueDates(todoService);
        }
        if (settings.todoReminders) {
          await notificationService.rescheduleAll(todoService);
        } else {
          await notificationService.cancelAll();
        }
        await backgroundSync.schedulePeriodicSync();
        _maybeCheckForUpdates(settings);
      } catch (e) {
        debugPrint('Auth state setup error: $e');
      }
    } else {
      _activeUserId = null;
      try {
        await syncEngine.stop();
        scheduler.stop();
        await backgroundSync.cancelAll();
        todoService.clear();
      } catch (e) {
        debugPrint('Auth state teardown error: $e');
      }
    }
  }

  Future<void> _maybeCheckForUpdates(AppSettings settings) async {
    if (_updateCheckStarted || !mounted) return;
    if (!settings.shouldCheckForUpdates) return;
    _updateCheckStarted = true;
    final updateService = context.read<UpdateService>();
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    await checkForUpdatesWithUi(context, updateService, silent: true);
    await settings.markUpdateChecked();
  }

  Future<void> _handleConflicts(List<SyncConflict> conflicts) async {
    if (!mounted || conflicts.isEmpty || _conflictDialogOpen) return;
    final syncEngine = context.read<SyncEngine>();
    final conflict = conflicts.first;
    _conflictDialogOpen = true;
    try {
      await showDialog<void>(
        context: appNavigatorKey.currentContext ?? context,
        barrierDismissible: false,
        builder: (dialogContext) => ConflictResolverDialog(
          conflict: conflict,
          onResolve: (keepLocal) => syncEngine.resolveConflict(
            conflict.noteId,
            keepLocal: keepLocal,
          ),
          onMerge: () => syncEngine.mergeConflict(conflict.noteId),
        ),
      );
    } finally {
      _conflictDialogOpen = false;
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _conflictSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final isDark = themeProvider.isDark;
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          systemNavigationBarColor:
              isDark ? const Color(0xFF1E1E2E) : Colors.white,
          systemNavigationBarIconBrightness:
              isDark ? Brightness.light : Brightness.dark,
        ));
        return MaterialApp(
          title: 'Jot?',
          debugShowCheckedModeBanner: false,
          navigatorKey: appNavigatorKey,
          theme: PlatformTheme.getTheme(Theme.of(context).platform),
          darkTheme: PlatformTheme.getDarkTheme(Theme.of(context).platform),
          themeMode: themeProvider.themeMode,
          home: const _AuthGate(),
          onGenerateRoute: (settings) {
            Widget builder;
            switch (settings.name) {
              case '/notes':
                builder = const ResponsiveNotesScreen();
                break;
              case '/login':
                builder = const LoginScreen();
                break;
              default:
                builder = const _AuthGate();
            }
            return MaterialPageRoute(
                builder: (context) => builder, settings: settings);
          },
        );
      },
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthState>();
    return authState.isAuthenticated
        ? const ResponsiveNotesScreen()
        : const LoginScreen();
  }
}
