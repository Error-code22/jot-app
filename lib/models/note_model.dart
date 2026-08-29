import 'dart:convert';

import 'package:flutter/foundation.dart' show listEquals;

enum NoteType { text, checklist }

class Note {
  final String id;
  final String userId;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final bool isDeleted;
  final NoteType type;
  final String? telegramMessageId;
  final List<String> tags;
  final String? color;
  final bool isPinned;
  final bool isLocked;
  final String? pinHash;
  final List<String> imageIds;

  Note({
    required this.id,
    required this.userId,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.modifiedAt,
    this.isDeleted = false,
    this.type = NoteType.text,
    this.telegramMessageId,
    this.tags = const [],
    this.color,
    this.isPinned = false,
    this.isLocked = false,
    this.pinHash,
    this.imageIds = const [],
  });

  Note copyWith({
    String? title,
    String? content,
    DateTime? modifiedAt,
    bool? isDeleted,
    NoteType? type,
    String? telegramMessageId,
    List<String>? tags,
    String? color,
    bool? isPinned,
    bool? isLocked,
    String? pinHash,
    bool clearPinHash = false,
    List<String>? imageIds,
  }) {
    return Note(
      id: id,
      userId: userId,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      type: type ?? this.type,
      telegramMessageId: telegramMessageId ?? this.telegramMessageId,
      tags: tags ?? this.tags,
      color: color ?? this.color,
      isPinned: isPinned ?? this.isPinned,
      isLocked: isLocked ?? this.isLocked,
      pinHash: clearPinHash ? null : (pinHash ?? this.pinHash),
      imageIds: imageIds ?? this.imageIds,
    );
  }

  /// Returns a simple hash of the PIN for storage.
  static String hashPin(String pin) {
    final salted = 'jot_pin_salt_$pin';
    final bytes = utf8.encode(salted);
    // Simple but sufficient for local PIN: base64 of repeated XOR fold
    int hash = 0;
    for (final b in bytes) {
      hash = ((hash << 5) - hash + b) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  bool verifyPin(String pin) => pinHash != null && pinHash == hashPin(pin);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Note) return false;
    return other.id == id &&
        other.userId == userId &&
        other.title == title &&
        other.content == content &&
        other.createdAt == createdAt &&
        other.modifiedAt == modifiedAt &&
        other.isDeleted == isDeleted &&
        other.type == type &&
        other.telegramMessageId == telegramMessageId &&
        listEquals(other.tags, tags) &&
        other.color == color &&
        other.isPinned == isPinned &&
        other.isLocked == isLocked &&
        other.pinHash == pinHash &&
        listEquals(other.imageIds, imageIds);
  }

  @override
  int get hashCode => Object.hash(
        id,
        userId,
        title,
        content,
        createdAt,
        modifiedAt,
        isDeleted,
        type,
        telegramMessageId,
        Object.hashAll(tags),
        color,
        isPinned,
        isLocked,
        pinHash,
        Object.hashAll(imageIds),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'title': title,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
        'modifiedAt': modifiedAt.toIso8601String(),
        'isDeleted': isDeleted,
        'type': type.name,
        'telegramMessageId': telegramMessageId,
        'tags': tags,
        'color': color,
        'isPinned': isPinned,
        'isLocked': isLocked,
        'pinHash': pinHash,
        'imageIds': imageIds,
      };

  factory Note.fromJson(Map<String, dynamic> json) => Note(
        id: json['id'] as String,
        userId: json['userId'] as String,
        title: json['title'] as String,
        content: json['content'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        modifiedAt: DateTime.parse(json['modifiedAt'] as String),
        isDeleted: json['isDeleted'] as bool? ?? false,
        type: NoteType.values.firstWhere(
            (e) => e.name == (json['type'] ?? 'text'),
            orElse: () => NoteType.text),
        telegramMessageId: json['telegramMessageId'] as String?,
        tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
        color: json['color'] as String?,
        isPinned: json['isPinned'] as bool? ?? false,
        isLocked: json['isLocked'] as bool? ?? false,
        pinHash: json['pinHash'] as String?,
        imageIds: (json['imageIds'] as List<dynamic>?)?.cast<String>() ?? [],
      );

  /// Convert to Supabase format (snake_case)
  Map<String, dynamic> toSupabase() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'content': content,
        'created_at': createdAt.toIso8601String(),
        'modified_at': modifiedAt.toIso8601String(),
        'is_deleted': isDeleted,
        'type': type.name,
        'tags': tags,
        'color': color,
        'is_pinned': isPinned,
        'is_locked': isLocked,
        'pin_hash': pinHash,
        'image_ids': imageIds,
      };

  /// Create from Supabase format (snake_case)
  factory Note.fromSupabase(Map<String, dynamic> json) => Note(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        title: json['title'] as String,
        content: json['content'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        modifiedAt: DateTime.parse(json['modified_at'] as String),
        isDeleted: json['is_deleted'] as bool? ?? false,
        type: NoteType.values.firstWhere(
          (e) => e.name == (json['type'] ?? 'text'),
          orElse: () => NoteType.text,
        ),
        tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
        color: json['color'] as String?,
        isPinned: json['is_pinned'] as bool? ?? false,
        isLocked: json['is_locked'] as bool? ?? false,
        pinHash: json['pin_hash'] as String?,
        imageIds: (json['image_ids'] as List<dynamic>?)?.cast<String>() ?? [],
      );

  Map<String, dynamic> toSqlite() => {
        'id': id,
        'userId': userId,
        'title': title,
        'content': content,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'modifiedAt': modifiedAt.millisecondsSinceEpoch,
        'isDeleted': isDeleted ? 1 : 0,
        'type': type.name,
        'telegramMessageId': telegramMessageId,
        'tags': jsonEncode(tags),
        'color': color,
        'isPinned': isPinned ? 1 : 0,
        'isLocked': isLocked ? 1 : 0,
        'pinHash': pinHash,
        'imageIds': jsonEncode(imageIds),
      };

  factory Note.fromSqlite(Map<String, dynamic> map) {
    List<String> parsedTags = [];
    try {
      final tagsRaw = map['tags'];
      if (tagsRaw is String && tagsRaw.isNotEmpty) {
        parsedTags = (jsonDecode(tagsRaw) as List).cast<String>();
      }
    } catch (_) {}
    List<String> parsedImageIds = [];
    try {
      final imageIdsRaw = map['imageIds'];
      if (imageIdsRaw is String && imageIdsRaw.isNotEmpty) {
        parsedImageIds = (jsonDecode(imageIdsRaw) as List).cast<String>();
      }
    } catch (_) {}
    return Note(
      id: map['id'] as String,
      userId: map['userId'] as String,
      title: map['title'] as String,
      content: map['content'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      modifiedAt: DateTime.fromMillisecondsSinceEpoch(map['modifiedAt'] as int),
      isDeleted: (map['isDeleted'] as int) == 1,
      type: NoteType.values.firstWhere((e) => e.name == (map['type'] ?? 'text'),
          orElse: () => NoteType.text),
      telegramMessageId: map['telegramMessageId'] as String?,
      tags: parsedTags,
      color: map['color'] as String?,
      isPinned: (map['isPinned'] as int? ?? 0) == 1,
      isLocked: (map['isLocked'] as int? ?? 0) == 1,
      pinHash: map['pinHash'] as String?,
      imageIds: parsedImageIds,
    );
  }
}

class ChecklistItem {
  final String id;
  final String text;
  final bool isChecked;

  ChecklistItem({required this.id, required this.text, this.isChecked = false});

  Map<String, dynamic> toJson() =>
      {'id': id, 'text': text, 'isChecked': isChecked};

  factory ChecklistItem.fromJson(Map<String, dynamic> json) => ChecklistItem(
      id: json['id'],
      text: json['text'],
      isChecked: json['isChecked'] ?? false);
}
