import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/note_model.dart';
import '../services/note_service.dart';
import '../services/i_auth_service.dart';
import '../services/cloudinary_service.dart';
import '../services/image_compress_service.dart';
import '../utils/view_mode_provider.dart';
import '../utils/color_utils.dart';

// Note color palette
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
  const NoteEditorScreen({super.key, this.note});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late NoteType _noteType;
  List<ChecklistItem> _checklistItems = [];
  List<String> _tags = [];
  String? _color;

  List<String> _imageIds = [];
  final Map<String, String?> _imageUrls = {};

  Timer? _debounceTimer;
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;
  Note? _currentNote;
  String? _errorMessage;
  final _uuid = const Uuid();
  final _tagController = TextEditingController();
  bool _isUnlocked = false;
  final _contentFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _currentNote = widget.note;
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(text: widget.note?.content ?? '');
    _noteType = widget.note?.type ?? NoteType.text;
    _tags = List<String>.from(widget.note?.tags ?? []);
    _color = widget.note?.color;
    _imageIds = List<String>.from(widget.note?.imageIds ?? []);

    if (_noteType == NoteType.checklist && widget.note != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(widget.note!.content);
        _checklistItems = jsonList.map((item) => ChecklistItem.fromJson(item)).toList();
      } catch (e) {
        _checklistItems = [];
      }
    }

    _titleController.addListener(_onTextChanged);
    _contentController.addListener(_onTextChanged);

    // Load image URLs if there are existing image attachments
    if (_imageIds.isNotEmpty) {
      _loadImageUrls();
    }

    // If note is locked, prompt for PIN after first frame
    if (widget.note?.isLocked == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _promptUnlockOnOpen());
    } else {
      _isUnlocked = true;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _titleController.dispose();
    _contentController.dispose();
    _tagController.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (!mounted) return;
    setState(() { _hasUnsavedChanges = true; _errorMessage = null; });
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 1000), _autoSave);
  }

  Future<void> _loadImageUrls() async {
    final cloudinary = Provider.of<CloudinaryService>(context, listen: false);
    for (final fileId in _imageIds) {
      try {
        final url = cloudinary.getDirectUrl(fileId);
        if (mounted) {
          setState(() { _imageUrls[fileId] = url; });
        }
      } catch (_) {
        if (mounted) {
          setState(() { _imageUrls[fileId] = null; });
        }
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    final cloudinary = Provider.of<CloudinaryService>(context, listen: false);
    final imageCompressor = Provider.of<ImageCompressService>(context, listen: false);

    XFile? pickedFile;
    final picker = ImagePicker();

    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux)) {
      pickedFile = await picker.pickImage(source: ImageSource.gallery);
    } else {
      // Mobile: show dialog to choose camera or gallery
      final source = await showDialog<ImageSource>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Select image source'),
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
      pickedFile = await picker.pickImage(source: source);
    }

    if (pickedFile == null) return;

    final bytes = await pickedFile.readAsBytes();

    if (bytes.length > 10 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image too large (max 10 MB)')),
        );
      }
      return;
    }

    try {
      final filename = pickedFile.name;
      
      // Compress image before upload
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$filename');
      await tempFile.writeAsBytes(bytes);
      
      final compressed = await imageCompressor.compressImage(
        imageFile: tempFile,
        quality: 80,
      );
      
      final compressedBytes = await compressed.file.readAsBytes();
      final result = await cloudinary.uploadImage(
        imageBytes: compressedBytes,
        fileName: filename,
        folder: 'notes',
      );
      
      if (mounted) {
        setState(() {
          _imageIds.add(result.publicId);
          _imageUrls[result.publicId] = result.url;
        });
        await _autoSave();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image upload failed: $e')),
        );
      }
    }
  }

  Future<void> _autoSave() async {
    if (!_hasUnsavedChanges || !mounted) return;
    final title = _titleController.text.trim();
    final content = _noteType == NoteType.text
        ? _contentController.text
        : jsonEncode(_checklistItems.map((e) => e.toJson()).toList());
    if (title.isEmpty && content.isEmpty) return;

    setState(() { _isSaving = true; _errorMessage = null; });
    try {
      final noteService = Provider.of<NoteService>(context, listen: false);
      final authService = Provider.of<IAuthService>(context, listen: false);
      final user = authService.getCurrentUser();
      if (user == null) throw Exception('No user');

      if (_currentNote == null) {
        final newNote = await noteService.createNote(
          userId: user.uid,
          title: title.isEmpty ? 'Untitled' : title,
          content: content,
          type: _noteType,
          tags: _tags,
          color: _color,
          imageIds: _imageIds,
        );
        if (mounted) setState(() { _currentNote = newNote; _hasUnsavedChanges = false; _isSaving = false; });
      } else {
        final updatedNote = await noteService.updateNote(
          _currentNote!,
          title: title.isEmpty ? 'Untitled' : title,
          content: content,
          type: _noteType,
          tags: _tags,
          color: _color,
          imageIds: _imageIds,
        );
        if (mounted) setState(() { _currentNote = updatedNote; _hasUnsavedChanges = false; _isSaving = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _errorMessage = 'Save failed'; _isSaving = false; });
    }
  }

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
        if (_checklistItems.isEmpty) _checklistItems.add(ChecklistItem(id: _uuid.v4(), text: ''));
      } else {
        _noteType = NoteType.text;
        _contentController.text = _checklistItems.map((e) => e.text).join('\n');
      }
      _hasUnsavedChanges = true;
    });
    _autoSave();
  }

  void _addChecklistItem() {
    setState(() {
      _checklistItems.add(ChecklistItem(id: _uuid.v4(), text: ''));
      _hasUnsavedChanges = true;
    });
  }

  void _updateChecklistItem(int index, String text, bool? isChecked) {
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
    setState(() {
      _checklistItems.removeAt(index);
      if (_checklistItems.isEmpty) _checklistItems.add(ChecklistItem(id: _uuid.v4(), text: ''));
      _hasUnsavedChanges = true;
    });
    _onTextChanged();
  }

  void _addTag(String tag) {
    final t = tag.trim().toLowerCase();
    if (t.isNotEmpty && !_tags.contains(t)) {
      setState(() { _tags.add(t); _hasUnsavedChanges = true; });
      _autoSave();
    }
    _tagController.clear();
  }

  void _removeTag(String tag) {
    setState(() { _tags.remove(tag); _hasUnsavedChanges = true; });
    _autoSave();
  }

  Future<void> _promptUnlockOnOpen() async {
    if (!mounted) return;
    final pin = await _showPinInput(verify: true);
    if (!mounted) return;
    if (pin == null || !(_currentNote?.verifyPin(pin) ?? false)) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _isUnlocked = true);
  }

  Future<void> _toggleLock() async {
    if (_currentNote == null) return;
    final noteService = Provider.of<NoteService>(context, listen: false);
    if (_currentNote!.isLocked) {
      // Unlock — verify PIN
      final pin = await _showPinInput(verify: true);
      if (pin == null) return; // cancelled
      if (!_currentNote!.verifyPin(pin)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Incorrect PIN'), backgroundColor: Colors.red),
        );
        return;
      }
      final unlocked = await noteService.toggleLock(_currentNote!);
      if (mounted) setState(() { _currentNote = unlocked; _isUnlocked = true; }); // unlocked
    } else {
      // Lock — collect a new PIN
      final pin = await _showPinInput(verify: false);
      if (pin == null) return; // cancelled
      final locked = await noteService.toggleLock(_currentNote!, pin: pin);
      if (mounted) setState(() => _currentNote = locked);
    }
  }

  /// Shows a PIN input dialog. Returns the entered PIN string, or null if cancelled.
  Future<String?> _showPinInput({required bool verify}) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(verify ? 'Enter PIN to unlock' : 'Set a PIN to lock'),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(hintText: '4-6 digit PIN'),
          onSubmitted: (_) => Navigator.pop(dialogContext, true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(verify ? 'Unlock' : 'Lock'),
          ),
        ],
      ),
    );
    if (confirmed != true || controller.text.length < 4) return null;
    return controller.text;
  }

  void _showColorPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Note color', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: kNoteColors.map((c) {
                final hex = c['color'] as String?;
                final col = _hexToColor(hex) ?? Theme.of(context).colorScheme.surface;
                final isSelected = _color == hex;
                return GestureDetector(
                  onTap: () {
                    setState(() { _color = hex; _hasUnsavedChanges = true; });
                    _autoSave();
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: col,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                    child: isSelected ? const Icon(Icons.check, size: 20) : null,
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tags', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              if (_tags.isNotEmpty)
                Wrap(
                  spacing: 8,
                  children: _tags.map((tag) => Chip(
                    label: Text('#$tag'),
                    onDeleted: () {
                      _removeTag(tag);
                      setModalState(() {});
                    },
                  )).toList(),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = ColorUtils.noteBackground(_color, theme.brightness == Brightness.dark, context);
    final textColor = ColorUtils.textColor(bgColor);
    final fontSize = Provider.of<ViewModeProvider>(context).fontSize;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        // Re-lock the note when leaving if it's locked
        if (didPop && _currentNote?.isLocked == true && _isUnlocked) {
          setState(() => _isUnlocked = false);
        }
      },
      child: Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        title: _buildSaveStatus(),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _currentNote?.isPinned == true ? Icons.push_pin_rounded : Icons.push_pin_outlined,
              color: _currentNote?.isPinned == true ? theme.colorScheme.primary : null,
            ),
            tooltip: _currentNote?.isPinned == true ? 'Unpin' : 'Pin note',
            onPressed: _currentNote == null ? null : () async {
              final noteService = Provider.of<NoteService>(context, listen: false);
              final updated = await noteService.togglePin(_currentNote!);
              setState(() => _currentNote = updated);
            },
          ),
          IconButton(
            icon: Icon(
              _currentNote?.isLocked == true ? Icons.lock_rounded : Icons.lock_outline_rounded,
              color: _currentNote?.isLocked == true ? Colors.orange : null,
            ),
            tooltip: _currentNote?.isLocked == true ? 'Unlock note' : 'Lock note',
            onPressed: _currentNote == null ? null : () => _toggleLock(),
          ),
          IconButton(icon: const Icon(Icons.palette_outlined), onPressed: _showColorPicker, tooltip: 'Note color'),
          IconButton(icon: const Icon(Icons.label_outline_rounded), onPressed: _showTagDialog, tooltip: 'Tags'),
          if (_currentNote != null)
            IconButton(icon: const Icon(Icons.delete_outline_rounded), onPressed: _deleteNote),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        color: bgColor,
        child: Column(
          children: [
            if (_tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                child: Wrap(
                  spacing: 6,
                  children: _tags.map((tag) => Chip(
                    label: Text('#$tag', style: TextStyle(fontSize: 11, color: textColor)),
                    visualDensity: VisualDensity.compact,
                    onDeleted: () => _removeTag(tag),
                  )).toList(),
                ),
              ),
            Expanded(
              child: _isUnlocked
                  ? SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _titleController,
                          decoration: InputDecoration(hintText: 'Title', border: InputBorder.none,
                            hintStyle: TextStyle(color: textColor.withValues(alpha: 0.4))),
                          style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: textColor),
                          maxLines: 1,
                        ),
                        if (_noteType == NoteType.text)
                          TextField(
                            controller: _contentController,
                            focusNode: _contentFocusNode,
                            decoration: InputDecoration(hintText: 'Start writing...', border: InputBorder.none,
                              hintStyle: TextStyle(color: textColor.withValues(alpha: 0.4))),
                            style: theme.textTheme.bodyLarge?.copyWith(height: 1.6, fontSize: fontSize, color: textColor),
                            maxLines: null,
                            keyboardType: TextInputType.multiline,
                          )
                        else
                          _buildChecklistMode(),
                        if (_imageIds.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _imageIds.take(10).map((fileId) {
                              final url = _imageUrls[fileId];
                              if (url != null) {
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    url,
                                    width: 200,
                                    height: 150,
                                    cacheWidth: 400,
                                    cacheHeight: 300,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
                                  ),
                                );
                              } else {
                                return const SizedBox(
                                  width: 200,
                                  height: 150,
                                  child: Center(child: CircularProgressIndicator()),
                                );
                              }
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              )
                  : Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_rounded, size: 64, color: textColor.withValues(alpha: 0.3)),
                      const SizedBox(height: 16),
                      Text('This note is locked', style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 16)),
                    ],
                  ),
                ),
            ),
            _buildToolbar(),
          ],
        ),
      ),
      ), // PopScope
    );
  }

  Widget _buildChecklistMode() {
    return Column(
      children: [
        ..._checklistItems.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Checkbox(
                  value: item.isChecked,
                  onChanged: (val) => _updateChecklistItem(index, item.text, val),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: item.text)
                      ..selection = TextSelection.collapsed(offset: item.text.length),
                    onChanged: (val) => _updateChecklistItem(index, val, item.isChecked),
                    decoration: const InputDecoration(border: InputBorder.none, hintText: 'List item'),
                    style: TextStyle(
                      fontSize: 18,
                      decoration: item.isChecked ? TextDecoration.lineThrough : null,
                      color: item.isChecked ? Colors.grey : null,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Colors.grey),
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

  Widget _buildSaveStatus() {
    if (_isSaving) return const Text('Saving...', style: TextStyle(fontSize: 14, color: Colors.grey));
    if (_errorMessage != null) return const Text('Error', style: TextStyle(fontSize: 14, color: Colors.red));
    if (!_hasUnsavedChanges && _currentNote != null) return const Text('Saved ✓', style: TextStyle(fontSize: 14, color: Colors.green));
    return const SizedBox();
  }

  Widget _buildToolbar() {
    final theme = Theme.of(context);
    final bgColor = ColorUtils.noteBackground(_color, theme.brightness == Brightness.dark, context);
    final textColor = ColorUtils.textColor(bgColor);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(top: BorderSide(color: textColor.withValues(alpha: 0.1))),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  _noteType == NoteType.checklist ? Icons.format_list_bulleted_rounded : Icons.text_fields_rounded,
                  color: _noteType == NoteType.checklist ? theme.primaryColor : textColor.withValues(alpha: 0.5),
                ),
                onPressed: _toggleNoteType,
                tooltip: 'Toggle checklist',
              ),
              const VerticalDivider(width: 16, indent: 8, endIndent: 8),
              IconButton(
                icon: Icon(Icons.attach_file_rounded, color: textColor.withValues(alpha: 0.5)),
                tooltip: 'Attach image',
                onPressed: _pickAndUploadImage,
              ),
              const VerticalDivider(width: 16, indent: 8, endIndent: 8),
              Text(
                '${_contentController.text.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length} words',
                style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.5)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteNote() async {
    if (_currentNote == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text('This will remove the note from all your devices.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade400, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await Provider.of<NoteService>(context, listen: false).deleteNote(_currentNote!);
      if (mounted) Navigator.pop(context);
    }
  }
}
