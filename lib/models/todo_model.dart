enum TodoPriority { none, low, medium, high }

class TodoItem {
  final String id;
  final String text;
  final bool isDone;
  final DateTime createdAt;
  final DateTime? dueDate;
  final TodoPriority priority;
  final String? note;

  TodoItem({
    required this.id,
    required this.text,
    this.isDone = false,
    required this.createdAt,
    this.dueDate,
    this.priority = TodoPriority.none,
    this.note,
  });

  TodoItem copyWith({
    String? text,
    bool? isDone,
    DateTime? dueDate,
    bool clearDueDate = false,
    TodoPriority? priority,
    String? note,
  }) => TodoItem(
    id: id,
    text: text ?? this.text,
    isDone: isDone ?? this.isDone,
    createdAt: createdAt,
    dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
    priority: priority ?? this.priority,
    note: note ?? this.note,
  );

  bool get isOverdue =>
      !isDone && dueDate != null && dueDate!.isBefore(DateTime.now());

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'isDone': isDone,
    'createdAt': createdAt.toIso8601String(),
    'dueDate': dueDate?.toIso8601String(),
    'priority': priority.name,
    'note': note,
  };

  factory TodoItem.fromJson(Map<String, dynamic> j) => TodoItem(
    id: j['id'],
    text: j['text'],
    isDone: j['isDone'] ?? false,
    createdAt: DateTime.parse(j['createdAt']),
    dueDate: j['dueDate'] != null ? DateTime.parse(j['dueDate']) : null,
    priority: TodoPriority.values.firstWhere(
      (p) => p.name == (j['priority'] ?? 'none'),
      orElse: () => TodoPriority.none,
    ),
    note: j['note'] as String?,
  );
}

class TodoList {
  final String id;
  final String userId;
  final String title;
  final List<TodoItem> items;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final String? color;
  final String? icon;

  TodoList({
    required this.id,
    required this.userId,
    required this.title,
    this.items = const [],
    required this.createdAt,
    required this.modifiedAt,
    this.color,
    this.icon,
  });

  int get doneCount => items.where((i) => i.isDone).length;
  int get totalCount => items.length;
  int get overdueCount => items.where((i) => i.isOverdue).length;
  double get progress => totalCount == 0 ? 0 : doneCount / totalCount;

  TodoList copyWith({
    String? title,
    List<TodoItem>? items,
    String? color,
    String? icon,
  }) => TodoList(
    id: id,
    userId: userId,
    title: title ?? this.title,
    items: items ?? this.items,
    createdAt: createdAt,
    modifiedAt: DateTime.now(),
    color: color ?? this.color,
    icon: icon ?? this.icon,
  );
}
