# Task 12.2: File Watching for Config Changes

## Overview

Implemented file system watching for the `.ide-collaboration.json` configuration file. This enables the ConfigService to detect and react to external modifications made by other IDEs (Kiro, Antigravity, Cursor) or other processes.

## Implementation Details

### Core Features

1. **File System Monitoring**
   - Uses Dart's built-in `FileSystemEntity.watch()` API
   - Monitors for file modifications, deletions, and creations
   - No external dependencies required

2. **Event Handling**
   - `FileSystemModifyEvent`: Reads updated config and emits through stream
   - `FileSystemDeleteEvent`: Emits error through stream
   - `FileSystemCreateEvent`: Reads new config and emits through stream

3. **Stream Management**
   - Broadcast stream allows multiple listeners
   - Proper error propagation through stream
   - Clean resource disposal

### API Changes

#### New Methods

```dart
/// Start watching the config file for changes
Future<void> startWatching([String? directory]) async

/// Stop watching the config file
Future<void> stopWatching() async

/// Check if currently watching a file
bool get isWatching
```

#### Modified Behavior

- `writeConfig()`: No longer emits to stream when file watching is active (prevents duplicate emissions)
- `dispose()`: Now also cancels file watch subscription

### Usage Example

```dart
// Create service
final service = ConfigService();

// Create initial config
final config = IDEConfig(
  projectName: 'Jot?',
  flutterVersion: '3.16.0',
  supportedPlatforms: ['android', 'windows'],
  sharedState: {'lastEditor': 'Kiro'},
  lastModified: DateTime.now(),
);
await service.writeConfig(config);

// Start watching for external changes
await service.startWatching();

// Listen to changes
service.watchConfig().listen(
  (updatedConfig) {
    print('Config changed: ${updatedConfig.sharedState}');
  },
  onError: (error) {
    print('Error: $error');
  },
);

// External IDE modifies the file...
// The listener will automatically receive the update

// Stop watching when done
await service.stopWatching();
service.dispose();
```

## Testing

### Test Coverage

Implemented comprehensive tests covering:

1. **Basic Functionality**
   - Starting watch on existing file
   - Throwing error when file doesn't exist
   - Stopping watch
   - Checking watch status

2. **Change Detection**
   - External file modifications
   - Multiple rapid changes
   - File deletion
   - File recreation after deletion

3. **Stream Behavior**
   - Events emitted for modifications
   - Errors emitted for deletions
   - No duplicate emissions when watching
   - Backward compatibility when not watching

4. **Error Handling**
   - Corrupted JSON during watch
   - File system errors
   - Stream error propagation

### Test Files

- `test/unit/services/config_service_test.dart`: Main test suite with file watching tests
- `test/unit/services/config_service_file_watch_example_test.dart`: Example usage tests

### Running Tests

```bash
# Run all config service tests
flutter test test/unit/services/config_service_test.dart

# Run example tests
flutter test test/unit/services/config_service_file_watch_example_test.dart
```

## Design Decisions

### 1. Using Built-in File Watching

**Decision**: Use Dart's `dart:io` FileSystemEntity.watch() instead of external packages.

**Rationale**:
- No additional dependencies
- Cross-platform support (Windows, Linux, macOS, Android)
- Sufficient for our use case
- Simpler maintenance

### 2. Preventing Duplicate Emissions

**Decision**: Don't emit from `writeConfig()` when file watching is active.

**Rationale**:
- File watcher will detect the write and emit
- Prevents duplicate events for the same change
- Maintains backward compatibility when not watching

### 3. Error Propagation Through Stream

**Decision**: Emit errors through the watchConfig() stream instead of throwing.

**Rationale**:
- Consistent with stream-based API
- Allows listeners to handle errors gracefully
- Doesn't crash the watch subscription on errors

### 4. Broadcast Stream

**Decision**: Use broadcast stream controller.

**Rationale**:
- Multiple parts of the app can listen simultaneously
- Common pattern for event streams
- Matches typical IDE collaboration scenarios

## Use Cases

### 1. Multi-IDE Collaboration

When multiple IDEs (Kiro, Antigravity, Cursor) work on the same project:
- Each IDE can watch the config file
- Changes made by one IDE are immediately visible to others
- Shared state synchronization across IDEs

### 2. External Tool Integration

When external tools modify the config:
- Build scripts updating project metadata
- CI/CD pipelines modifying configuration
- Manual edits by developers

### 3. Real-time Configuration Updates

When configuration needs to be reactive:
- Feature flags toggled externally
- Environment switches
- Shared development state

## Limitations and Considerations

### 1. File System Event Timing

- File system events may be delayed on some platforms
- Multiple rapid writes may coalesce into fewer events
- Tests include appropriate delays to handle timing

### 2. Platform Differences

- Event behavior may vary slightly across platforms
- Windows, Linux, and macOS have different file system notification mechanisms
- Implementation uses platform-agnostic API

### 3. Resource Management

- File watching consumes system resources
- Important to call `stopWatching()` when done
- `dispose()` automatically stops watching

### 4. Large Files

- Reading config on every change may be expensive for large files
- Current implementation is suitable for small config files
- Consider debouncing for larger files if needed

## Future Enhancements

Potential improvements for future iterations:

1. **Debouncing**: Add configurable debounce to handle rapid changes
2. **Selective Watching**: Watch only specific fields in the config
3. **Change Diffing**: Emit only the changed fields instead of full config
4. **Retry Logic**: Automatic retry on transient read errors
5. **Conflict Resolution**: Handle concurrent writes from multiple sources

## Requirements Validation

This implementation validates:

- **Requirement 8.3**: Project uses .ide-collaboration.json for metadata (reactive updates)
  - ✅ File watching enables reactive updates
  - ✅ External changes are detected and propagated
  - ✅ Multiple IDEs can collaborate through shared file

## Related Tasks

- **Task 12.1**: Implement ConfigService with read/write operations (completed)
- **Task 12.3**: Write property test for config file format (pending)
- **Task 12.4**: Write unit tests for ConfigService (completed)

## Conclusion

File watching functionality is fully implemented and tested. The ConfigService can now detect external modifications to the `.ide-collaboration.json` file, enabling true multi-IDE collaboration. The implementation is robust, well-tested, and ready for integration with the rest of the application.
