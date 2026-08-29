import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/i_auth_service.dart';
import '../services/i_local_storage_service.dart';
import '../services/import_service.dart';
import '../services/note_service.dart';
import '../services/sync_engine.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  bool _importing = false;
  bool _isDragOver = false;
  final List<String> _queuedPaths = [];
  final Set<String> _folderPaths = {};

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['txt', 'md', 'text', 'markdown'],
      );
      if (result == null) return;
      final paths = result.paths.whereType<String>().toList();
      if (paths.isEmpty) return;
      setState(() => _queuedPaths.addAll(paths));
    } catch (e) {
      _showSnack('Could not open file picker: $e', error: true);
    }
  }

  Future<void> _pickFolder() async {
    try {
      final path = await FilePicker.platform.getDirectoryPath();
      if (path == null) return;
      setState(() {
        _queuedPaths.add(path);
        _folderPaths.add(path);
      });
    } catch (e) {
      _showSnack('Could not open folder picker: $e', error: true);
    }
  }

  Future<void> _runImport() async {
    if (_queuedPaths.isEmpty) {
      _showSnack('Add files or a folder first', error: true);
      return;
    }

    final authService = Provider.of<IAuthService>(context, listen: false);
    final storage = Provider.of<ILocalStorageService>(context, listen: false);
    final noteService = Provider.of<NoteService>(context, listen: false);
    final syncEngine = Provider.of<SyncEngine>(context, listen: false);
    final user = authService.getCurrentUser();
    if (user == null) {
      _showSnack('Please sign in first', error: true);
      return;
    }

    setState(() => _importing = true);

    final importService = ImportService(storage);
    int totalImported = 0;
    int totalSkipped = 0;

    for (final path in _queuedPaths) {
      ImportResult result;
      if (_folderPaths.contains(path)) {
        result = await importService.importTxtFolder(path, user.uid);
      } else {
        result = await importService.importFiles([path], user.uid);
      }
      totalImported += result.imported;
      totalSkipped += result.skipped;
    }

    if (!mounted) return;

    // Refresh the notes stream so UI updates immediately
    await noteService.refreshNotes(user.uid);

    // Sync imported notes to the cloud
    unawaited(syncEngine.syncNow(user.uid));
    final msg = 'Imported $totalImported note${totalImported == 1 ? '' : 's'}'
        '${totalSkipped > 0 ? ', $totalSkipped failed' : ''}';

    if (!mounted) return;

    setState(() {
      _importing = false;
      _queuedPaths.clear();
      _folderPaths.clear();
    });
    _showSnack(msg, error: totalImported == 0);
  }

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red : Colors.green,
      duration: const Duration(seconds: 4),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Notes', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Supported formats: .txt  •  .md  •  .markdown',
              style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 20),

            // Drag & Drop zone
            DragTarget<Object>(
              onWillAcceptWithDetails: (details) {
                setState(() => _isDragOver = true);
                return true;
              },
              onLeave: (_) => setState(() => _isDragOver = false),
              onAcceptWithDetails: (details) {
                setState(() => _isDragOver = false);
                // On Windows, drag data comes as file paths
                final data = details.data;
                if (data is String) {
                  setState(() => _queuedPaths.add(data));
                }
              },
              builder: (context, candidateData, rejectedData) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 180,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isDragOver
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline.withValues(alpha: 0.4),
                      width: _isDragOver ? 2.5 : 1.5,
                      style: BorderStyle.solid,
                    ),
                    color: _isDragOver
                        ? theme.colorScheme.primary.withValues(alpha: 0.08)
                        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.upload_file_rounded,
                        size: 48,
                        color: _isDragOver
                            ? theme.colorScheme.primary
                            : Colors.grey,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Drag files or folders here',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _isDragOver ? theme.colorScheme.primary : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text('or use the buttons below',
                        style: TextStyle(color: Colors.grey, fontSize: 13)),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Pick buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.file_copy_outlined),
                    label: const Text('Pick Files'),
                    onPressed: _importing ? null : _pickFiles,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.folder_outlined),
                    label: const Text('Pick Folder'),
                    onPressed: _importing ? null : _pickFolder,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Queued paths
            if (_queuedPaths.isNotEmpty) ...[
              Text('Ready to import (${_queuedPaths.length}):',
                style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 160),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(8),
                  itemCount: _queuedPaths.length,
                  itemBuilder: (context, i) => ListTile(
                    dense: true,
                    leading: Icon(
                      _folderPaths.contains(_queuedPaths[i])
                          ? Icons.folder_outlined
                          : Icons.insert_drive_file_outlined,
                      size: 18,
                    ),
                    title: Text(
                      _queuedPaths[i].split('/').last.split('\\').last,
                      style: const TextStyle(fontSize: 13),
                    ),
                    subtitle: Text(_queuedPaths[i],
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                      overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () => setState(() => _queuedPaths.removeAt(i)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            const Spacer(),

            // Import button
            ElevatedButton.icon(
              icon: _importing
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.upload_rounded),
              label: Text(_importing ? 'Importing...' : 'Import Now'),
              onPressed: _importing ? null : _runImport,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
