import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../models/note_model.dart';
import '../services/app_settings.dart';
import '../services/audio_service.dart';
import '../services/biometric_service.dart';
import '../services/cloudinary_service.dart';
import '../services/i_auth_service.dart';
import '../services/image_compress_service.dart';
import '../services/note_service.dart';
import '../services/share_link_service.dart';
import '../utils/color_utils.dart';
import '../utils/markdown_renderer.dart';
import '../utils/view_mode_provider.dart';

const List<Map<String, dynamic>> kNoteColors = [
  {'label': 'Default', 'color': null},
  {'label': 'Red', 'color': '#FFCDD2'},
  {'label': 'Orange', 'color': '#FFE0B2'},
  {'label': 'Yellow', 'color': '#FFF9C4'},
  {'label': 'Green', 'color': '#C8E6C9'},
  {'label': 'Teal', 'color': '#B2EBF2'},
  {'label': 'Blue', 'color': '#BBDEFB'},
  {'label': 'Purple', 'color': '#E1BEE7'},
  {'label': 'Pink', 'color': '#F8BBD0'},
];

Color? _hexToColor(String? hex) {
  if (hex == null) return null;
  final h = hex.replaceAll('#', '');
  return Color(int.parse('FF$h', radix: 16));
}

class NoteEditorScreen extends StatefulWidget {
  final Note? note;

  /// When true the editor renders without its own Scaffold/AppBar so it can be
  /// embedded in the desktop split view.
  final bool embedded;

  /// Called instead of popping the route when the editor is embedded.
  final VoidCallback? onClose;

  const NoteEditorScreen({
    super.key,
    this.note,
    this.embedded = false,
    this.onClose,
  });

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen>
    with WidgetsBindingObserver {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late NoteType _noteType;
  List<ChecklistItem> _checklistItems = [];
  final Map<String, TextEditingController> _checklistControllers = {};
  List<String> _tags = [];
  String? _color;
  List<String> _imageIds = [];
  final Map<String, String> _imageUrls = {};
  List<String> _audioIds = [];

  Timer? _debounceTimer;
  bool _isSaving = false;
  bool _saveAgain = false;
  bool _hasUnsavedChanges = false;
  Note? _currentNote;
  String? _errorMessage;
  final _uuid = const Uuid();
  final _tagController = TextEditingController();
  bool _isUnlocked = false;
  final _contentFocusNode = FocusNode();
  bool _showPreview = false;
  bool _allowPop = false;
  bool _isUploadingImage = false;
  AudioPlayer? _audioPlayer;
  String? _playingReference;

  bool get _isLocked => _currentNote?.isLocked == true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentNote = widget.note;
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController =
        TextEditingController(text: widget.note?.content ?? '');
    _noteType = widget.note?.type ?? NoteType.text;
    _tags = List<String>.from(widget.note?.tags ?? []);
    _color = widget.note?.color;
    _imageIds = List<String>.from(widget.note?.imageIds ?? []);
    _audioIds = List<String>.from(widget.note?.audioIds ?? []);

    for (final reference in _imageIds) {
      _resolveImage(reference);
    }

    if (_noteType == NoteType.checklist && widget.note != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(widget.note!.content);
        _checklistItems = jsonList
            .map((item) => ChecklistItem.fromJson(item as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _checklistItems = [];
      }
    }
    for (final item in _checklistItems) {
      _checklistControllers[item.id] = TextEditingController(text: item.text);
    }

    _titleController.addListener(_onTextChanged);
    _contentController.addListener(_onTextChanged);

    if (widget.note?.isLocked == true) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _promptUnlockOnOpen());
    } else {
      _isUnlocked = true;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_flushSave());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounceTimer?.cancel();
    _titleController.dispose();
    _contentController.dispose();
    _tagController.dispose();
    _contentFocusNode.dispose();
    for (final controller in _checklistControllers.values) {
      controller.dispose();
    }
    _audioPlayer?.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (!mounted || !_isUnlocked) return;
    setState(() {
      _hasUnsavedChanges = true;
      _errorMessage = null;
    });
    _debounceTimer?.cancel();
    _debounceTimer =
        Timer(const Duration(milliseconds: 800), () => unawaited(_autoSave()));
  }

  void _resolveImage(String reference) {
    final cloudinary = Provider.of<CloudinaryService>(context, listen: false);
    _imageUrls[reference] = cloudinary.resolveUrl(reference);
  }

  // ── Unlock ────────────────────────────────────────────────────────────────

  Future<void> _promptUnlockOnOpen() async {
    if (!mounted) return;

    // Try biometrics / device credentials first, then fall back to the PIN.
    try {
      final settings = Provider.of<AppSettings>(context, listen: false);
      if (settings.biometricUnlock) {
        final biometric = Provider.of<BiometricService>(context, listen: false);
        if (await biometric.isAvailable) {
          final ok = await biometric.authenticate(
            reason: 'Unlock "${_currentNote?.title ?? 'note'}" in Jot?',
          );
          if (ok) {
            if (mounted) setState(() => _isUnlocked = true);
            return;
          }
        }
      }
    } catch (_) {
      // Biometrics unavailable — continue with the PIN.
    }

    if (!mounted) return;
    final pin = await _showPinInput(verify: true);
    if (!mounted) return;
    if (pin == null || !(_currentNote?.verifyPin(pin) ?? false)) {
      if (pin != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incorrect PIN'),
            backgroundColor: Colors.red,
          ),
        );
      }
      if (widget.embedded && widget.onClose != null) {
        widget.onClose!();
      } else {
        Navigator.of(context).pop();
      }
      return;
    }
    setState(() => _isUnlocked = true);
  }

  Future<String?> _showPinInput({
    required bool verify,
    bool confirm = false,
  }) async {
    final controller = TextEditingController();
    final confirmController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(verify ? 'Enter PIN to unlock' : 'Set a PIN to lock'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(hintText: '4-6 digit PIN'),
              onSubmitted: (_) => Navigator.pop(dialogContext, true),
            ),
            if (!verify && confirm)
              TextField(
                controller: confirmController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(hintText: 'Confirm PIN'),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(verify ? 'Unlock' : 'Lock'),
          ),
        ],
      ),
    );
    if (confirmed != true || controller.text.length < 4) return null;
    if (confirm && confirmController.text != controller.text) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PINs do not match')),
        );
      }
      return null;
    }
    return controller.text;
  }

  // ── Saving ────────────────────────────────────────────────────────────────

  Future<void> _flushSave() async {
    _debounceTimer?.cancel();
    if (!_hasUnsavedChanges || !_isUnlocked) return;
    await _autoSave();
  }

  Future<void> _autoSave() async {
    if (!_isUnlocked || !mounted) return;
    if (_isSaving) {
      _saveAgain = true;
      return;
    }

    final title = _titleController.text;
    final content = _noteType == NoteType.text
        ? _contentController.text
        : jsonEncode(_checklistItems.map((e) => e.toJson()).toList());

    final hasSomething = title.trim().isNotEmpty ||
        content.trim().isNotEmpty ||
        _imageIds.isNotEmpty ||
        _audioIds.isNotEmpty ||
        _checklistItems.any((item) => item.text.trim().isNotEmpty);
    if (_currentNote == null && !hasSomething) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final noteService = Provider.of<NoteService>(context, listen: false);
      final authService = Provider.of<IAuthService>(context, listen: false);
      final user = authService.getCurrentUser();
      if (user == null) throw Exception('No user');

      if (_currentNote == null) {
        final newNote = await noteService.createNote(
          userId: user.uid,
          title: title,
          content: content,
          type: _noteType,
          tags: _tags,
          color: _color,
          imageIds: _imageIds,
          audioIds: _audioIds,
        );
        if (mounted) {
          setState(() {
            _currentNote = newNote;
            _hasUnsavedChanges = false;
            _isSaving = false;
          });
        }
      } else {
        final updated = await noteService.updateNote(
          _currentNote!,
          title: title,
          content: content,
          type: _noteType,
          tags: _tags,
          color: _color,
          clearColor: _color == null,
          imageIds: _imageIds,
          audioIds: _audioIds,
        );
        if (mounted) {
          setState(() {
            _currentNote = updated;
            _hasUnsavedChanges = false;
            _isSaving = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Save failed';
          _isSaving = false;
        });
      }
    } finally {
      if (mounted && _isSaving) setState(() => _isSaving = false);
      if (_saveAgain) {
        _saveAgain = false;
        unawaited(_autoSave());
      }
    }
  }

  Future<bool> _handleBack() async {
    await _flushSave();
    if (!mounted) return false;
    setState(() => _allowPop = true);
    return true;
  }

  // ── Attachments ───────────────────────────────────────────────────────────

  Future<void> _pickAndUploadImage() async {
    if (_isUploadingImage) return;
    final cloudinary = Provider.of<CloudinaryService>(context, listen: false);
    final compressor =
        Provider.of<ImageCompressService>(context, listen: false);

    Uint8List bytes = Uint8List(0);
    String fileName = 'image.jpg';

    try {
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.windows ||
              defaultTargetPlatform == TargetPlatform.linux ||
              defaultTargetPlatform == TargetPlatform.macOS)) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          withData: false,
        );
        final path = result?.files.single.path;
        if (path == null) return;
        bytes = await File(path).readAsBytes();
        fileName = path.split(Platform.pathSeparator).last;
      } else {
        final source = await showDialog<ImageSource>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Add image'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
                child: const Text('Gallery'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, ImageSource.camera),
                child: const Text('Camera'),
              ),
            ],
          ),
        );
        if (source == null) return;
        final picked = await ImagePicker().pickImage(source: source);
        if (picked == null) return;
        bytes = await picked.readAsBytes();
        fileName = picked.name;
      }

      if (bytes.isEmpty) return;
      if (bytes.length > 10 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image too large (max 10 MB)')),
          );
        }
        return;
      }

      setState(() => _isUploadingImage = true);

      // Compression is only supported on the mobile plugins; desktop uses the
      // original bytes.
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)) {
        try {
          final tempDir = await getTemporaryDirectory();
          final tempFile = File('${tempDir.path}/$fileName');
          await tempFile.writeAsBytes(bytes);
          final compressed = await compressor.compressImage(
            imageFile: tempFile,
            quality: 80,
          );
          bytes = await compressed.file.readAsBytes();
        } catch (e) {
          debugPrint('Image compression skipped: $e');
        }
      }

      final result = await cloudinary.uploadImage(
        imageBytes: bytes,
        fileName: fileName,
        folder: 'notes',
      );

      if (!mounted) return;
      setState(() {
        _imageIds.add(result.url);
        _imageUrls[result.url] = result.url;
        _hasUnsavedChanges = true;
      });
      await _autoSave();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _recordAudio() async {
    final audioService = Provider.of<AudioService>(context, listen: false);
    final path = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AudioRecorderSheet(audioService: audioService),
    );
    if (path == null || !mounted) return;

    setState(() {
      _audioIds.add(path);
      _hasUnsavedChanges = true;
    });
    await _autoSave();
    if (!mounted) return;

    // Upload in the background and swap the local path for a public URL.
    final authService = Provider.of<IAuthService>(context, listen: false);
    final user = authService.getCurrentUser();
    if (user == null) return;
    final url = await audioService.upload(path, user.uid);
    if (url != null && mounted) {
      setState(() {
        final index = _audioIds.indexOf(path);
        if (index != -1) _audioIds[index] = url;
        _hasUnsavedChanges = true;
      });
      await _autoSave();
    }
  }

  Future<void> _toggleAudio(String reference) async {
    final player = _audioPlayer ??= AudioPlayer();
    try {
      if (_playingReference == reference) {
        await player.stop();
        setState(() => _playingReference = null);
        return;
      }
      await player.stop();
      if (reference.startsWith('http')) {
        await player.play(UrlSource(reference));
      } else {
        await player.play(DeviceFileSource(reference));
      }
      setState(() => _playingReference = reference);
      player.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _playingReference = null);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not play recording: $e')),
        );
      }
    }
  }

  Future<void> _removeAudio(String reference) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete recording?'),
        content: const Text('This removes the audio from this note.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (_playingReference == reference) {
      await _audioPlayer?.stop();
      _playingReference = null;
    }
    setState(() {
      _audioIds.remove(reference);
      _hasUnsavedChanges = true;
    });
    await _autoSave();
    if (mounted) {
      final audioService = Provider.of<AudioService>(context, listen: false);
      await audioService.delete(reference);
    }
  }

  // ── Note type / checklist ─────────────────────────────────────────────────

  void _toggleNoteType() {
    setState(() {
      if (_noteType == NoteType.text) {
        _noteType = NoteType.checklist;
        if (_contentController.text.trim().isNotEmpty) {
          _checklistItems = _contentController.text
              .split('\n')
              .where((line) => line.trim().isNotEmpty)
              .map((line) => ChecklistItem(id: _uuid.v4(), text: line))
              .toList();
        }
        if (_checklistItems.isEmpty) {
          _checklistItems.add(ChecklistItem(id: _uuid.v4(), text: ''));
        }
        for (final item in _checklistItems) {
          _checklistControllers.putIfAbsent(
            item.id,
            () => TextEditingController(text: item.text),
          );
        }
      } else {
        _noteType = NoteType.text;
        _contentController.text = _checklistItems.map((e) => e.text).join('\n');
      }
      _hasUnsavedChanges = true;
    });
    unawaited(_autoSave());
  }

  void _addChecklistItem() {
    final item = ChecklistItem(id: _uuid.v4(), text: '');
    setState(() {
      _checklistItems.add(item);
      _checklistControllers[item.id] = TextEditingController();
      _hasUnsavedChanges = true;
    });
    _onTextChanged();
  }

  void _updateChecklistItem(int index, String text, bool? isChecked) {
    if (index < 0 || index >= _checklistItems.length) return;
    setState(() {
      _checklistItems[index] = ChecklistItem(
        id: _checklistItems[index].id,
        text: text,
        isChecked: isChecked ?? _checklistItems[index].isChecked,
      );
      _hasUnsavedChanges = true;
    });
    _onTextChanged();
  }

  void _removeChecklistItem(int index) {
    if (index < 0 || index >= _checklistItems.length) return;
    final removed = _checklistItems[index];
    setState(() {
      _checklistItems.removeAt(index);
      _checklistControllers.remove(removed.id)?.dispose();
      if (_checklistItems.isEmpty) {
        final item = ChecklistItem(id: _uuid.v4(), text: '');
        _checklistItems.add(item);
        _checklistControllers[item.id] = TextEditingController();
      }
      _hasUnsavedChanges = true;
    });
    _onTextChanged();
  }

  // ── Tags / colour ─────────────────────────────────────────────────────────

  void _addTag(String tag) {
    final t = tag.trim().toLowerCase();
    if (t.isNotEmpty && !_tags.contains(t)) {
      setState(() {
        _tags.add(t);
        _hasUnsavedChanges = true;
      });
      unawaited(_autoSave());
    }
    _tagController.clear();
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
      _hasUnsavedChanges = true;
    });
    unawaited(_autoSave());
  }

  void _showColorPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Note colour',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: kNoteColors.map((c) {
                final hex = c['color'] as String?;
                final col = _hexToColor(hex) ??
                    Theme.of(sheetContext).colorScheme.surface;
                final isSelected = _color == hex;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _color = hex;
                      _hasUnsavedChanges = true;
                    });
                    unawaited(_autoSave());
                    Navigator.pop(sheetContext);
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: col,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(sheetContext).colorScheme.primary
                            : Colors.grey.shade300,
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                    child:
                        isSelected ? const Icon(Icons.check, size: 20) : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _showTagDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tags',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              if (_tags.isNotEmpty)
                Wrap(
                  spacing: 8,
                  children: _tags
                      .map((tag) => Chip(
                            label: Text('#$tag'),
                            onDeleted: () {
                              _removeTag(tag);
                              setModalState(() {});
                            },
                          ))
                      .toList(),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _tagController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Add a tag...',
                  prefixText: '# ',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      _addTag(_tagController.text);
                      setModalState(() {});
                    },
                  ),
                ),
                onSubmitted: (v) {
                  _addTag(v);
                  setModalState(() {});
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Markdown helpers ──────────────────────────────────────────────────────

  void _wrapSelection(String before, String after) {
    final text = _contentController.text;
    final selection = _contentController.selection;
    if (!selection.isValid) return;

    final selectedText = text.substring(selection.start, selection.end);
    final newText = text.replaceRange(
        selection.start, selection.end, '$before$selectedText$after');
    _contentController.text = newText;
    _contentController.selection = TextSelection.collapsed(
      offset: selection.end + before.length + after.length,
    );
    _onTextChanged();
  }

  void _insertHeading() {
    final text = _contentController.text;
    final selection = _contentController.selection;
    if (!selection.isValid) return;

    final lineStart = text.lastIndexOf('\n', selection.start - 1) + 1;
    final prefix = text.substring(lineStart, selection.start);

    String newPrefix;
    if (prefix.startsWith('### ')) {
      newPrefix = '';
    } else if (prefix.startsWith('## ')) {
      newPrefix = '### ';
    } else if (prefix.startsWith('# ')) {
      newPrefix = '## ';
    } else {
      newPrefix = '# ';
    }

    final newText = text.replaceRange(lineStart, selection.start, newPrefix);
    _contentController.text = newText;
    _contentController.selection = TextSelection.collapsed(
      offset: selection.start - prefix.length + newPrefix.length,
    );
    _onTextChanged();
  }

  void _insertBulletList() {
    final text = _contentController.text;
    final selection = _contentController.selection;
    if (!selection.isValid) return;

    final lineStart = text.lastIndexOf('\n', selection.start - 1) + 1;
    final newText = text.replaceRange(lineStart, lineStart, '• ');
    _contentController.text = newText;
    _contentController.selection =
        TextSelection.collapsed(offset: selection.start + 2);
    _onTextChanged();
  }

  // ── Lock / pin / share ────────────────────────────────────────────────────

  Future<void> _toggleLock() async {
    if (_currentNote == null) return;
    final noteService = Provider.of<NoteService>(context, listen: false);

    if (_currentNote!.isLocked) {
      final pin = await _showPinInput(verify: true);
      if (pin == null) return;
      if (!_currentNote!.verifyPin(pin)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incorrect PIN'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      final unlocked = await noteService.toggleLock(_currentNote!);
      if (mounted) {
        setState(() {
          _currentNote = unlocked;
          _isUnlocked = true;
        });
      }
    } else {
      final pin = await _showPinInput(verify: false, confirm: true);
      if (pin == null) return;
      final locked = await noteService.toggleLock(_currentNote!, pin: pin);
      if (mounted) setState(() => _currentNote = locked);
    }
  }

  Future<void> _shareNote() async {
    if (_isLocked && !_isUnlocked) {
      _showSnack('Unlock this note before sharing it.');
      return;
    }
    await _flushSave();
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.text_snippet_outlined),
              title: const Text('Share as text'),
              onTap: () {
                Navigator.pop(sheetContext);
                unawaited(_shareAsText());
              },
            ),
            ListTile(
              leading: const Icon(Icons.link_rounded),
              title: const Text('Create a public link'),
              subtitle: const Text('Anyone with the link can read a snapshot'),
              onTap: () {
                Navigator.pop(sheetContext);
                unawaited(_createShareLink());
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareAsText() async {
    final title = _titleController.text.trim();
    final content = _noteType == NoteType.text
        ? _contentController.text
        : _checklistItems
            .map((e) => '${e.isChecked ? '✅' : '⬜'} ${e.text}')
            .join('\n');
    final text = title.isEmpty ? content : '$title\n\n$content';
    if (text.trim().isEmpty) return;
    await Share.share(text, subject: title.isEmpty ? 'Jot? Note' : title);
  }

  Future<void> _createShareLink() async {
    final expiry = await showDialog<Duration?>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Link expiry'),
        children: [
          SimpleDialogOption(
            onPressed: () =>
                Navigator.pop(dialogContext, const Duration(days: 1)),
            child: const Text('1 day'),
          ),
          SimpleDialogOption(
            onPressed: () =>
                Navigator.pop(dialogContext, const Duration(days: 7)),
            child: const Text('7 days'),
          ),
          SimpleDialogOption(
            onPressed: () =>
                Navigator.pop(dialogContext, const Duration(days: 30)),
            child: const Text('30 days'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, null),
            child: const Text('No expiry'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    try {
      if (_currentNote == null) {
        await _autoSave();
        if (!mounted) return;
      }
      if (_currentNote == null) {
        _showSnack('Add something to the note before sharing it.');
        return;
      }
      final service = Provider.of<ShareLinkService>(context, listen: false);
      final link = await service.create(_currentNote!, expiresIn: expiry);
      await Clipboard.setData(ClipboardData(text: link.url));
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Link copied'),
          content: SelectableText(link.url),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Done'),
            ),
            FilledButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: link.url));
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Copy again'),
            ),
          ],
        ),
      );
    } catch (e) {
      _showSnack(
        'Could not create a link. The shared_notes migration may not be applied yet.',
      );
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _deleteNote() async {
    if (_currentNote == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text('This will remove the note from all your devices.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await Provider.of<NoteService>(context, listen: false)
          .deleteNote(_currentNote!);
      if (mounted) Navigator.pop(context);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final body = _buildEditorBody(context);

    if (widget.embedded) {
      return Column(
        children: [
          _buildEmbeddedHeader(context),
          Expanded(child: body),
          _buildToolbar(),
        ],
      );
    }

    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final canPop = await _handleBack();
        if (canPop && context.mounted) {
          Navigator.of(context).pop(result);
        }
      },
      child: Scaffold(
        appBar: _buildAppBar(context),
        body: body,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = ColorUtils.noteBackground(
      _color,
      theme.brightness == Brightness.dark,
      context,
    );

    return AppBar(
      backgroundColor: bgColor,
      title: _buildSaveStatus(),
      centerTitle: true,
      elevation: 0,
      actions: _buildActions(context),
    );
  }

  Widget _buildEmbeddedHeader(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = ColorUtils.noteBackground(
      _color,
      theme.brightness == Brightness.dark,
      context,
    );
    return Material(
      color: bgColor,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Expanded(child: _buildSaveStatus(alignStart: true)),
              ..._buildActions(context),
              if (widget.onClose != null)
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Close editor',
                  onPressed: widget.onClose,
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildActions(BuildContext context) {
    final theme = Theme.of(context);
    return [
      IconButton(
        icon: Icon(
          _currentNote?.isPinned == true
              ? Icons.push_pin_rounded
              : Icons.push_pin_outlined,
          color:
              _currentNote?.isPinned == true ? theme.colorScheme.primary : null,
        ),
        tooltip: _currentNote?.isPinned == true ? 'Unpin' : 'Pin note',
        onPressed: _currentNote == null
            ? null
            : () async {
                final noteService =
                    Provider.of<NoteService>(context, listen: false);
                final updated = await noteService.togglePin(_currentNote!);
                if (mounted) setState(() => _currentNote = updated);
              },
      ),
      IconButton(
        icon: Icon(
          _currentNote?.isLocked == true
              ? Icons.lock_rounded
              : Icons.lock_outline_rounded,
          color: _currentNote?.isLocked == true ? Colors.orange : null,
        ),
        tooltip: _currentNote?.isLocked == true ? 'Remove lock' : 'Lock note',
        onPressed: _currentNote == null ? null : _toggleLock,
      ),
      IconButton(
        icon: const Icon(Icons.palette_outlined),
        onPressed: _showColorPicker,
        tooltip: 'Note colour',
      ),
      IconButton(
        icon: const Icon(Icons.label_outline_rounded),
        onPressed: _showTagDialog,
        tooltip: 'Tags',
      ),
      IconButton(
        icon: const Icon(Icons.share_outlined),
        onPressed: _shareNote,
        tooltip: 'Share note',
      ),
      PopupMenuButton<String>(
        tooltip: 'More',
        onSelected: (value) {
          if (value == 'hide') {
            setState(() {
              _currentNote = _currentNote?.copyWith(
                hidePreview: !(_currentNote?.hidePreview ?? false),
                modifiedAt: DateTime.now(),
              );
              _hasUnsavedChanges = true;
            });
            unawaited(_autoSave());
          } else if (value == 'delete') {
            _deleteNote();
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'hide',
            child: Text(
              _currentNote?.hidePreview == true
                  ? 'Show preview in lists'
                  : 'Hide preview in lists',
            ),
          ),
          if (_currentNote != null)
            const PopupMenuItem(
              value: 'delete',
              child: Text('Delete note', style: TextStyle(color: Colors.red)),
            ),
        ],
      ),
    ];
  }

  Widget _buildEditorBody(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = ColorUtils.noteBackground(
      _color,
      theme.brightness == Brightness.dark,
      context,
    );
    final textColor = ColorUtils.textColor(bgColor);
    final fontSize = Provider.of<ViewModeProvider>(context).fontSize;

    return Column(
      children: [
        if (_tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            child: Wrap(
              spacing: 6,
              children: _tags
                  .map((tag) => Chip(
                        label: Text('#$tag',
                            style: TextStyle(fontSize: 11, color: textColor)),
                        visualDensity: VisualDensity.compact,
                        onDeleted: () => _removeTag(tag),
                      ))
                  .toList(),
            ),
          ),
        Expanded(
          child: _isUnlocked
              ? Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 16),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 800),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextField(
                                  controller: _titleController,
                                  decoration: InputDecoration(
                                    hintText: 'Title',
                                    border: InputBorder.none,
                                    hintStyle: TextStyle(
                                        color:
                                            textColor.withValues(alpha: 0.4)),
                                  ),
                                  style:
                                      theme.textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                  maxLines: 1,
                                ),
                                if (_noteType == NoteType.text)
                                  _showPreview
                                      ? Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 8),
                                          child: RichText(
                                            text: MarkdownRenderer.render(
                                              _contentController.text.isEmpty
                                                  ? 'Start writing...'
                                                  : _contentController.text,
                                              baseStyle: theme
                                                      .textTheme.bodyLarge
                                                      ?.copyWith(
                                                    height: 1.6,
                                                    fontSize: fontSize,
                                                    color: textColor,
                                                  ) ??
                                                  const TextStyle(),
                                            ),
                                          ),
                                        )
                                      : TextField(
                                          controller: _contentController,
                                          focusNode: _contentFocusNode,
                                          decoration: InputDecoration(
                                            hintText: 'Start writing...',
                                            border: InputBorder.none,
                                            hintStyle: TextStyle(
                                                color: textColor.withValues(
                                                    alpha: 0.4)),
                                          ),
                                          style: theme.textTheme.bodyLarge
                                              ?.copyWith(
                                            height: 1.6,
                                            fontSize: fontSize,
                                            color: textColor,
                                          ),
                                          maxLines: null,
                                          keyboardType: TextInputType.multiline,
                                        )
                                else
                                  _buildChecklistMode(),
                                if (_audioIds.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  _buildAudioList(textColor),
                                ],
                                if (_imageIds.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  _buildImageList(textColor),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              : Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_rounded,
                          size: 64, color: textColor.withValues(alpha: 0.3)),
                      const SizedBox(height: 16),
                      Text('This note is locked',
                          style: TextStyle(
                              color: textColor.withValues(alpha: 0.5),
                              fontSize: 16)),
                    ],
                  ),
                ),
        ),
        if (!widget.embedded) _buildToolbar(),
      ],
    );
  }

  Widget _buildChecklistMode() {
    return Column(
      children: [
        ..._checklistItems.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final controller = _checklistControllers.putIfAbsent(
            item.id,
            () => TextEditingController(text: item.text),
          );
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Checkbox(
                  value: item.isChecked,
                  onChanged: (val) =>
                      _updateChecklistItem(index, item.text, val),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    onChanged: (val) =>
                        _updateChecklistItem(index, val, item.isChecked),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'List item',
                    ),
                    style: TextStyle(
                      fontSize: 18,
                      decoration:
                          item.isChecked ? TextDecoration.lineThrough : null,
                      color: item.isChecked ? Colors.grey : null,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                  tooltip: 'Remove item',
                  onPressed: () => _removeChecklistItem(index),
                ),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: _addChecklistItem,
          icon: const Icon(Icons.add),
          label: const Text('Add item'),
          style: TextButton.styleFrom(foregroundColor: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildImageList(Color textColor) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _imageIds.map((reference) {
        final url = _imageUrls[reference];
        return Stack(
          children: [
            GestureDetector(
              onTap: url == null
                  ? null
                  : () => showDialog<void>(
                        context: context,
                        builder: (_) => Dialog(
                          child: InteractiveViewer(
                            child: Image.network(
                              url,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.broken_image, size: 48),
                            ),
                          ),
                        ),
                      ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: url == null
                    ? const SizedBox(
                        width: 200,
                        height: 150,
                        child: Center(child: Icon(Icons.broken_image)),
                      )
                    : Image.network(
                        url,
                        width: 200,
                        height: 150,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 200,
                          height: 150,
                          color: Colors.black12,
                          child: const Center(
                            child: Icon(Icons.broken_image, size: 32),
                          ),
                        ),
                      ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () async {
                  setState(() {
                    _imageIds.remove(reference);
                    _imageUrls.remove(reference);
                    _hasUnsavedChanges = true;
                  });
                  await _autoSave();
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildAudioList(Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _audioIds.map((reference) {
        final isPlaying = _playingReference == reference;
        return Card(
          margin: const EdgeInsets.only(bottom: 6),
          child: ListTile(
            dense: true,
            leading: IconButton(
              icon: Icon(isPlaying ? Icons.stop_circle : Icons.play_circle,
                  color: Theme.of(context).colorScheme.primary),
              tooltip: isPlaying ? 'Stop' : 'Play recording',
              onPressed: () => _toggleAudio(reference),
            ),
            title: Text(
              reference.startsWith('http')
                  ? 'Voice note'
                  : 'Voice note (local only)',
              style: TextStyle(fontSize: 13, color: textColor),
            ),
            subtitle: reference.startsWith('http')
                ? null
                : const Text('Will upload when a connection is available',
                    style: TextStyle(fontSize: 11)),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              tooltip: 'Delete recording',
              onPressed: () => _removeAudio(reference),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSaveStatus({bool alignStart = false}) {
    Widget child;
    if (_isSaving) {
      child = const Text('Saving...',
          style: TextStyle(fontSize: 13, color: Colors.grey));
    } else if (_errorMessage != null) {
      child = const Text('Save failed',
          style: TextStyle(fontSize: 13, color: Colors.red));
    } else if (!_hasUnsavedChanges && _currentNote != null) {
      child = const Text('Saved',
          style: TextStyle(fontSize: 13, color: Colors.green));
    } else {
      child = const SizedBox();
    }
    if (!alignStart) return child;
    return Align(alignment: Alignment.centerLeft, child: child);
  }

  Widget _buildToolbar() {
    final theme = Theme.of(context);
    final bgColor = ColorUtils.noteBackground(
      _color,
      theme.brightness == Brightness.dark,
      context,
    );
    final textColor = ColorUtils.textColor(bgColor);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        border:
            Border(top: BorderSide(color: textColor.withValues(alpha: 0.1))),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  _noteType == NoteType.checklist
                      ? Icons.format_list_bulleted_rounded
                      : Icons.text_fields_rounded,
                  color: _noteType == NoteType.checklist
                      ? theme.primaryColor
                      : textColor.withValues(alpha: 0.5),
                ),
                onPressed: _toggleNoteType,
                tooltip: 'Toggle checklist',
              ),
              const VerticalDivider(width: 16, indent: 8, endIndent: 8),
              IconButton(
                icon: Icon(Icons.attach_file_rounded,
                    color: textColor.withValues(alpha: 0.5)),
                tooltip: 'Attach image',
                onPressed: _isUploadingImage ? null : _pickAndUploadImage,
              ),
              IconButton(
                icon: Icon(Icons.mic_none_rounded,
                    color: textColor.withValues(alpha: 0.5)),
                tooltip: 'Record voice note',
                onPressed: _recordAudio,
              ),
              const VerticalDivider(width: 16, indent: 8, endIndent: 8),
              if (_noteType == NoteType.text) ...[
                IconButton(
                  icon: Icon(Icons.preview_rounded,
                      color: _showPreview
                          ? theme.primaryColor
                          : textColor.withValues(alpha: 0.5)),
                  tooltip: _showPreview ? 'Edit mode' : 'Preview',
                  onPressed: () => setState(() => _showPreview = !_showPreview),
                ),
                if (!_showPreview) ...[
                  IconButton(
                    icon: Icon(Icons.format_bold_rounded,
                        color: textColor.withValues(alpha: 0.5)),
                    tooltip: 'Bold',
                    onPressed: () => _wrapSelection('**', '**'),
                  ),
                  IconButton(
                    icon: Icon(Icons.format_italic_rounded,
                        color: textColor.withValues(alpha: 0.5)),
                    tooltip: 'Italic',
                    onPressed: () => _wrapSelection('_', '_'),
                  ),
                  IconButton(
                    icon: Icon(Icons.title_rounded,
                        color: textColor.withValues(alpha: 0.5)),
                    tooltip: 'Heading',
                    onPressed: _insertHeading,
                  ),
                  IconButton(
                    icon: Icon(Icons.format_list_bulleted_rounded,
                        color: textColor.withValues(alpha: 0.5)),
                    tooltip: 'Bullet list',
                    onPressed: _insertBulletList,
                  ),
                ],
                const VerticalDivider(width: 16, indent: 8, endIndent: 8),
              ],
              Text(
                '${_contentController.text.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length} words',
                style: TextStyle(
                    fontSize: 12, color: textColor.withValues(alpha: 0.5)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet that records a voice note and returns its local path.
class _AudioRecorderSheet extends StatefulWidget {
  final AudioService audioService;

  const _AudioRecorderSheet({required this.audioService});

  @override
  State<_AudioRecorderSheet> createState() => _AudioRecorderSheetState();
}

class _AudioRecorderSheetState extends State<_AudioRecorderSheet> {
  bool _recording = false;
  bool _busy = false;
  String? _error;
  Timer? _timer;
  int _seconds = 0;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.audioService.startRecording();
      if (!mounted) return;
      setState(() {
        _recording = true;
        _seconds = 0;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _seconds++);
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stop() async {
    setState(() => _busy = true);
    _timer?.cancel();
    try {
      final path = await widget.audioService.stopRecording();
      if (!mounted) return;
      if (path == null) {
        setState(() {
          _recording = false;
          _busy = false;
          _error = 'Recording was not saved.';
        });
        return;
      }
      Navigator.pop(context, path);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _recording = false;
          _error = '$e';
        });
      }
    }
  }

  Future<void> _cancel() async {
    _timer?.cancel();
    await widget.audioService.cancelRecording();
    if (mounted) Navigator.pop(context);
  }

  String get _elapsed {
    final minutes = (_seconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Record a voice note',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          const Text(
            'Audio is stored in your own Supabase project. No transcription or third-party AI is used.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          Text(_elapsed,
              style:
                  const TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : _cancel,
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : (_recording ? _stop : _start),
                  icon:
                      Icon(_recording ? Icons.stop_rounded : Icons.mic_rounded),
                  label: Text(_recording ? 'Stop & attach' : 'Start recording'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
