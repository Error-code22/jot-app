# Task 12.1: ConfigService Implementation

## Overview
Implemented ConfigService for managing the `.ide-collaboration.json` file, which contains project metadata and shared state for IDE collaboration.

## Files Created

### 1. Model: `lib/models/ide_config.dart`
- **IDEConfig** class representing the configuration structure
- Fields:
  - `projectName`: Name of the project
  - `flutterVersion`: Flutter SDK version
  - `supportedPlatforms`: List of supported platforms (android, windows, linux, macos)
  - `sharedState`: Map for arbitrary shared state data
  - `lastModified`: Timestamp of last modification
- Methods:
  - `toJson()`: Serialize to JSON for file storage
  - `fromJson()`: Deserialize from JSON
  - `copyWith()`: Create modified copies

### 2. Interface: `lib/services/i_config_service.dart`
- **IConfigService** interface defining the contract
- Methods:
  - `readConfig()`: Read configuration from file
  - `writeConfig()`: Write configuration to file
  - `watchConfig()`: Stream of configuration changes

### 3. Implementation: `lib/services/config_service.dart`
- **ConfigService** class implementing IConfigService
- Features:
  - Reads and parses `.ide-collaboration.json` from project root
  - Writes configuration with pretty-printed JSON (2-space indentation)
  - Broadcasts configuration changes via stream
  - Comprehensive error handling:
    - FileSystemException for missing files
    - FormatException for corrupted JSON
    - Generic Exception for other errors
  - Supports custom directory paths for testing

### 4. Tests: `test/unit/services/config_service_test.dart`
Comprehensive unit test suite covering:

#### Read Operations
- ✓ Reads valid config file successfully
- ✓ Throws FileSystemException when file does not exist
- ✓ Throws FormatException when JSON is corrupted
- ✓ Throws exception when required fields are missing
- ✓ Handles empty sharedState correctly
- ✓ Handles special characters in strings

#### Write Operations
- ✓ Writes config file successfully
- ✓ Overwrites existing config file
- ✓ Formats JSON with proper indentation
- ✓ Handles complex nested sharedState

#### Round Trip
- ✓ Write and read preserves all data

#### Stream Watching
- ✓ Emits config when written
- ✓ Emits multiple configs on multiple writes

#### Error Handling
- ✓ Handles permission denied gracefully (platform-specific)
- ✓ Handles invalid directory path

**Total: 17 test cases, all passing**

## Requirements Validated
- **8.3**: Project uses .ide-collaboration.json for metadata
- **8.5**: Config file includes project name, Flutter version, supported platforms

## Usage Example

```dart
// Create service
final configService = ConfigService();

// Read configuration
try {
  final config = await configService.readConfig();
  print('Project: ${config.projectName}');
  print('Flutter: ${config.flutterVersion}');
} on FileSystemException {
  print('Config file not found');
} on FormatException {
  print('Config file is corrupted');
}

// Write configuration
final newConfig = IDEConfig(
  projectName: 'Jot?',
  flutterVersion: '3.16.0',
  supportedPlatforms: ['android', 'windows', 'linux', 'macos'],
  sharedState: {
    'lastSync': DateTime.now().toIso8601String(),
    'activeFeature': 'sync-engine',
  },
  lastModified: DateTime.now(),
);

await configService.writeConfig(newConfig);

// Watch for changes
configService.watchConfig().listen((config) {
  print('Config updated: ${config.projectName}');
});

// Clean up
configService.dispose();
```

## File Format

The `.ide-collaboration.json` file uses the following structure:

```json
{
  "projectName": "Jot?",
  "flutterVersion": "3.16.0",
  "supportedPlatforms": [
    "android",
    "windows",
    "linux",
    "macos"
  ],
  "sharedState": {
    "lastSync": "2024-01-15T10:30:00.000Z",
    "activeFeature": "sync-engine"
  },
  "lastModified": "2024-01-15T10:30:00.000Z"
}
```

## Error Handling

The service provides clear error messages for common failure scenarios:

1. **File Not Found**: `FileSystemException: Configuration file not found`
2. **Corrupted JSON**: `FormatException: Corrupted JSON in configuration file`
3. **Missing Fields**: `Exception: Failed to read configuration file`
4. **Write Failures**: `Exception: Failed to write configuration file`

## Testing Strategy

All tests use temporary directories to avoid interfering with the actual project configuration. The test suite covers:
- Happy path scenarios (read, write, round-trip)
- Error conditions (missing file, corrupted data, invalid paths)
- Edge cases (empty state, special characters, nested data)
- Stream functionality (single and multiple emissions)

## Next Steps

Task 12.2 will implement file watching to detect external changes to the configuration file and emit updates through the `watchConfig()` stream.
