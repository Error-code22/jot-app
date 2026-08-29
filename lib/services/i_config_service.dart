import '../models/ide_config.dart';

/// Interface for IDE collaboration configuration service
/// Manages the shared configuration file for multi-IDE collaboration
abstract class IConfigService {
  /// Read IDE collaboration configuration from .ide-collaboration.json
  /// Optional [directory] overrides the default config directory
  Future<IDEConfig> readConfig([String? directory]);

  /// Write IDE collaboration configuration to .ide-collaboration.json
  /// Optional [directory] overrides the default config directory
  Future<void> writeConfig(IDEConfig config, [String? directory]);

  /// Watch for configuration changes
  Stream<IDEConfig> watchConfig();
}
