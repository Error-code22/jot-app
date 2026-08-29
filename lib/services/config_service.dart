import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:path/path.dart' as path;
import '../models/ide_config.dart';
import 'i_config_service.dart';

/// Implementation of IDE collaboration configuration service
/// Manages reading and writing .ide-collaboration.json file
class ConfigService implements IConfigService {
  final String _configFileName = '.ide-collaboration.json';
  final StreamController<IDEConfig> _configController =
      StreamController<IDEConfig>.broadcast();
  
  StreamSubscription<FileSystemEvent>? _fileWatchSubscription;
  String? _watchedDirectory;

  /// Get the config file path
  /// In a real app, this would be the project root
  /// For testing, we can inject the directory
  String getConfigFilePath([String? directory]) {
    final dir = directory ?? Directory.current.path;
    return path.join(dir, _configFileName);
  }

  @override
  Future<IDEConfig> readConfig([String? directory]) async {
    final filePath = getConfigFilePath(directory);
    final file = File(filePath);

    // Handle file not found
    if (!await file.exists()) {
      throw FileSystemException(
        'Configuration file not found',
        filePath,
      );
    }

    try {
      // Read file content
      final content = await file.readAsString();

      // Parse JSON
      final json = jsonDecode(content) as Map<String, dynamic>;

      // Create IDEConfig from JSON
      return IDEConfig.fromJson(json);
    } on FormatException catch (e) {
      throw FormatException(
        'Corrupted JSON in configuration file: ${e.message}',
        e.source,
        e.offset,
      );
    } catch (e) {
      throw Exception('Failed to read configuration file: $e');
    }
  }

  @override
  Future<void> writeConfig(IDEConfig config, [String? directory]) async {
    final filePath = getConfigFilePath(directory);
    final file = File(filePath);

    try {
      // Convert config to JSON
      final json = config.toJson();

      // Write to file with pretty formatting
      final content = const JsonEncoder.withIndent('  ').convert(json);
      await file.writeAsString(content);

      // Note: We don't emit here anymore - the file watcher will detect
      // the change and emit. This prevents duplicate emissions.
      // If not watching, we still emit for backward compatibility.
      if (!isWatching) {
        _configController.add(config);
      }
    } catch (e) {
      throw Exception('Failed to write configuration file: $e');
    }
  }

  @override
  Stream<IDEConfig> watchConfig() {
    return _configController.stream;
  }

  /// Start watching the config file for changes
  /// [directory] - Optional directory path, defaults to current directory
  Future<void> startWatching([String? directory]) async {
    // Stop any existing watch
    await stopWatching();

    final filePath = getConfigFilePath(directory);
    final file = File(filePath);

    // Store the directory being watched
    _watchedDirectory = directory;

    // Check if file exists before watching
    if (!await file.exists()) {
      throw FileSystemException(
        'Cannot watch non-existent configuration file',
        filePath,
      );
    }

    // Watch the file for changes
    _fileWatchSubscription = file.watch(events: FileSystemEvent.all).listen(
      (event) async {
        // Handle different file system events
        if (event is FileSystemModifyEvent) {
          // File was modified - read and emit new config
          try {
            final config = await readConfig(_watchedDirectory);
            _configController.add(config);
          } catch (e) {
            // If read fails, emit error through stream
            _configController.addError(e);
          }
        } else if (event is FileSystemDeleteEvent) {
          // File was deleted - emit error
          _configController.addError(
            FileSystemException(
              'Configuration file was deleted',
              filePath,
            ),
          );
        } else if (event is FileSystemCreateEvent) {
          // File was created (after being deleted) - read and emit
          try {
            final config = await readConfig(_watchedDirectory);
            _configController.add(config);
          } catch (e) {
            _configController.addError(e);
          }
        }
      },
      onError: (error) {
        // Forward any watch errors to the stream
        _configController.addError(error);
      },
    );
  }

  /// Stop watching the config file
  Future<void> stopWatching() async {
    await _fileWatchSubscription?.cancel();
    _fileWatchSubscription = null;
    _watchedDirectory = null;
  }

  /// Check if currently watching a file
  bool get isWatching => _fileWatchSubscription != null;

  /// Dispose resources
  void dispose() {
    _fileWatchSubscription?.cancel();
    _configController.close();
  }
}
