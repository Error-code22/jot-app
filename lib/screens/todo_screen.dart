import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/todo_model.dart';
import '../services/todo_service.dart';

// ─── Color palette for lists ────────────────────────────────────────────────
const _kListColors = [
  null, '#FFCDD2', '#FFE0B2', '#FFF9C4',
  '#C8E6C9', '#B2EBF2', '#BBDEFB', '#E1BEE7', '#F8BBD0',
];

const _kListIcons = [
  '📋', '🛒', '💼', '🏠', '🎯', '📚', '💪', '✈️', '🎉', '❤️',
];

// ─── Helpers ─────────────────────────────────────────────────────────────────
Color? _hexToColor(String? hex) {
  if (hex == null) return null;
  return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
}

Color _priorityColor(TodoPriority p) {
  switch (p) {
    case TodoPriority.high:   return Colors.red.shade400;
    case TodoPriority.medium: return Colors.orange.shade400;
    case TodoPriority.low:    return Colors.blue.shade300;
    case TodoPriority.none:   return Colors.transparent;
  }
}

String _priorityLabel(TodoPriority p) {
  switch (p) {
    case TodoPriority.high:   return 'High';
    case TodoPriority.medium: return 'Medium';
    case TodoPriority.low:    return 'Low';
    case TodoPriority.none:   return 'None';
  }
}

String _formatDue(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final due   = DateTime(d.year, d.month, d.day);
  final diff  = due.difference(today).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff == -1) return 'Yesterday';
  if (diff < 0) return '${-diff}d overdue';
  return '${d.day}/${d.month}/${d.year}';
}

// ─── TodoScreen (list of lists) ──────────────────────────────────────────────
class TodoScreen extends StatelessWidget {
  const TodoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final todoService = Provider.of<TodoService>(context);
    final lists = todoService.lists;
    final theme = Theme.of(context);

    if (lists.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.checklist_rounded, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('No to-do lists yet',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Tap + to create one', style: TextStyle(color: Colors.grey.shade400)),
          ],
        ),
      );
    }

    // Summary row
    final totalItems = lists.fold<int>(0, (s, l) => s + l.totalCount);
    final doneItems  = lists.fold<int>(0, (s, l) => s + l.doneCount);
    final overdue    = lists.fold<int>(0, (s, l) => s + l.overdueCount);

    return Column(
      children: [
        // ── Summary banner ──
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _SummaryChip(label: 'Lists', value: '${lists.length}', icon: Icons.list_rounded),
              _SummaryChip(label: 'Tasks', value: '$totalItems', icon: Icons.task_alt_rounded),
              _SummaryChip(label: 'Done', value: '$doneItems', icon: Icons.check_circle_outline_rounded,
                  color: Colors.green),
              if (overdue > 0)
                _SummaryChip(label: 'Overdue', value: '$overdue', icon: Icons.warning_amber_rounded,
                    color: Colors.red),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
            itemCount: lists.length,
            itemBuilder: (context, i) => _TodoListCard(list: lists[i]),
          ),
        ),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  const _SummaryChip({required this.label, required this.value, required this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: c),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: c)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}

// ─── List card on the home tab ───────────────────────────────────────────────
class _TodoListCard extends StatelessWidget {
  final TodoList list;
  const _TodoListCard({required this.list});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = _hexToColor(list.color) ?? (isDark ? const Color(0xFF1E1E2E) : Colors.white);

    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => TodoDetailScreen(list: list))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: isDark ? Border.all(color: const Color(0xFF313244)) : null,
          boxShadow: isDark ? [] : [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (list.icon != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(list.icon!, style: const TextStyle(fontSize: 20)),
                  ),
                Expanded(
                  child: Text(list.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                if (list.overdueCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${list.overdueCount} overdue',
                        style: TextStyle(fontSize: 11, color: Colors.red.shade600,
                            fontWeight: FontWeight.w600)),
                  ),
                const SizedBox(width: 8),
                Text('${list.doneCount}/${list.totalCount}',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              ],
            ),
            if (list.totalCount > 0) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: list.progress,
                  backgroundColor: Colors.grey.shade200,
                  color: list.progress == 1.0 ? Colors.green : theme.colorScheme.primary,
                  minHeight: 6,
                ),
              ),
            ],
            if (list.items.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...list.items.where((i) => !i.isDone).take(3).map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    if (item.priority != TodoPriority.none)
                      Container(
                        width: 8, height: 8,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: _priorityColor(item.priority),
                          shape: BoxShape.circle,
                        ),
                      ),
                    Icon(Icons.radio_button_unchecked_rounded,
                        size: 14, color: Colors.grey.shade400),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(item.text,
                          style: const TextStyle(fontSize: 13),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    if (item.dueDate != null)
                      Text(_formatDue(item.dueDate!),
                          style: TextStyle(
                              fontSize: 10,
                              color: item.isOverdue ? Colors.red : Colors.grey.shade400)),
                  ],
                ),
              )),
              if (list.items.where((i) => !i.isDone).length > 3)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '+${list.items.where((i) => !i.isDone).length - 3} more',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                  ),
                ),
              if (list.progress == 1.0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 14, color: Colors.green),
                      const SizedBox(width: 4),
                      Text('All done!',
                          style: TextStyle(fontSize: 12, color: Colors.green.shade600,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Detail screen ───────────────────────────────────────────────────────────
class TodoDetailScreen extends StatefulWidget {
  final TodoList list;
  const TodoDetailScreen({super.key, required this.list});

  @override
  State<TodoDetailScreen> createState() => _TodoDetailScreenState();
}

enum _SortMode { manual, priority, dueDate, alphabetical }

class _TodoDetailScreenState extends State<TodoDetailScreen> {
  late TodoList _list;
  final _addController = TextEditingController();
  bool _showDone = true;
  _SortMode _sortMode = _SortMode.manual;

  @override
  void initState() {
    super.initState();
    _list = widget.list;
  }

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  TodoList _current(TodoService svc) =>
      svc.lists.firstWhere((l) => l.id == _list.id, orElse: () => _list);

  List<TodoItem> _sorted(List<TodoItem> items) {
    final pending = items.where((i) => !i.isDone).toList();
    final done    = items.where((i) => i.isDone).toList();
    switch (_sortMode) {
      case _SortMode.priority:
        pending.sort((a, b) => b.priority.index.compareTo(a.priority.index));
      case _SortMode.dueDate:
        pending.sort((a, b) {
          if (a.dueDate == null && b.dueDate == null) return 0;
          if (a.dueDate == null) return 1;
          if (b.dueDate == null) return -1;
          return a.dueDate!.compareTo(b.dueDate!);
        });
      case _SortMode.alphabetical:
        pending.sort((a, b) => a.text.compareTo(b.text));
      case _SortMode.manual:
        break;
    }
    return _showDone ? [...pending, ...done] : pending;
  }

  Future<void> _addItem() async {
    final text = _addController.text.trim();
    if (text.isEmpty) return;
    final svc = Provider.of<TodoService>(context, listen: false);
    _list = await svc.addItem(_list.id, text);
    _addController.clear();
    setState(() {});
  }

  void _showAddItemSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _AddItemSheet(listId: _list.id),
    );
  }

  void _showEditItem(BuildContext context, TodoItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _EditItemSheet(listId: _list.id, item: item),
    );
  }

  void _showListOptions(BuildContext context, TodoList current) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _ListOptionsSheet(list: current),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final svc = Provider.of<TodoService>(context);
    final current = _current(svc);
    final sorted = _sorted(current.items);
    final bg = _hexToColor(current.color);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Row(
          children: [
            if (current.icon != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(current.icon!, style: const TextStyle(fontSize: 22)),
              ),
            Expanded(
              child: Text(current.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: () => _showListOptions(context, current),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Progress bar ──
          if (current.totalCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: current.progress,
                        backgroundColor: Colors.grey.shade200,
                        color: current.progress == 1.0
                            ? Colors.green
                            : theme.colorScheme.primary,
                        minHeight: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('${current.doneCount}/${current.totalCount}',
                      style: TextStyle(
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ],
              ),
            ),
          // ── Filter / sort bar ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Sort picker
                PopupMenuButton<_SortMode>(
                  initialValue: _sortMode,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (m) => setState(() => _sortMode = m),
                  child: Chip(
                    avatar: const Icon(Icons.sort_rounded, size: 16),
                    label: Text(_sortLabel(_sortMode),
                        style: const TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                  ),
                  itemBuilder: (_) => [
                    _sortMenuItem(_SortMode.manual, 'Manual', Icons.drag_handle_rounded),
                    _sortMenuItem(_SortMode.priority, 'Priority', Icons.flag_rounded),
                    _sortMenuItem(_SortMode.dueDate, 'Due date', Icons.calendar_today_rounded),
                    _sortMenuItem(_SortMode.alphabetical, 'A–Z', Icons.sort_by_alpha_rounded),
                  ],
                ),
                const SizedBox(width: 8),
                // Show/hide done
                if (current.doneCount > 0)
                  GestureDetector(
                    onTap: () => setState(() => _showDone = !_showDone),
                    child: Chip(
                      avatar: Icon(
                        _showDone ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                        size: 16,
                      ),
                      label: Text(
                        _showDone ? 'Hide done' : 'Show done (${current.doneCount})',
                        style: const TextStyle(fontSize: 12),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ),
          // ── Items list ──
          Expanded(
            child: sorted.isEmpty
                ? Center(
                    child: Text(
                      current.items.isEmpty
                          ? 'No tasks yet.\nTap + to add one!'
                          : 'All tasks done! 🎉',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                    onReorderItem: _sortMode == _SortMode.manual
                        ? (oldIdx, newIdx) {
                            svc.reorderItems(_list.id, oldIdx, newIdx);
                          }
                        : (_, __) {},
                    itemCount: sorted.length,
                    itemBuilder: (ctx, i) {
                      final item = sorted[i];
                      return _TodoItemTile(
                        key: ValueKey(item.id),
                        item: item,
                        listId: _list.id,
                        canReorder: _sortMode == _SortMode.manual,
                        onEdit: () => _showEditItem(context, item),
                      );
                    },
                  ),
          ),
          // ── Quick-add bar ──
          Container(
            padding: EdgeInsets.only(
                left: 16,
                right: 8,
                top: 8,
                bottom: MediaQuery.of(context).viewInsets.bottom + 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _addController,
                    decoration: const InputDecoration(
                        hintText: 'Quick add task...', border: InputBorder.none),
                    onSubmitted: (_) => _addItem(),
                    textInputAction: TextInputAction.done,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.tune_rounded),
                  tooltip: 'Add with details',
                  onPressed: _showAddItemSheet,
                ),
                IconButton(
                  icon: Icon(Icons.add_circle_rounded,
                      color: theme.colorScheme.primary, size: 32),
                  onPressed: _addItem,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _sortLabel(_SortMode m) {
    switch (m) {
      case _SortMode.manual:      return 'Manual';
      case _SortMode.priority:    return 'Priority';
      case _SortMode.dueDate:     return 'Due date';
      case _SortMode.alphabetical: return 'A–Z';
    }
  }

  PopupMenuItem<_SortMode> _sortMenuItem(_SortMode m, String label, IconData icon) =>
      PopupMenuItem(
        value: m,
        child: Row(children: [
          Icon(icon, size: 18),
          const SizedBox(width: 10),
          Text(label),
          if (_sortMode == m) ...[
            const Spacer(),
            const Icon(Icons.check, size: 16),
          ],
        ]),
      );
}

// ─── Individual item tile ─────────────────────────────────────────────────────
class _TodoItemTile extends StatelessWidget {
  final TodoItem item;
  final String listId;
  final bool canReorder;
  final VoidCallback onEdit;
  const _TodoItemTile({
    super.key,
    required this.item,
    required this.listId,
    required this.canReorder,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final svc = Provider.of<TodoService>(context, listen: false);

    return Dismissible(
      key: ValueKey('dismiss_${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      onDismissed: (_) => svc.deleteItem(listId, item.id),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        decoration: BoxDecoration(
          color: item.isDone
              ? Colors.grey.withValues(alpha: 0.06)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: item.isOverdue
              ? Border.all(color: Colors.red.shade300, width: 1)
              : null,
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          leading: GestureDetector(
            onTap: () => svc.toggleItem(listId, item.id),
            child: Icon(
              item.isDone
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: item.isDone ? Colors.green : Colors.grey.shade400,
              size: 26,
            ),
          ),
          title: Text(
            item.text,
            style: TextStyle(
              decoration: item.isDone ? TextDecoration.lineThrough : null,
              color: item.isDone ? Colors.grey : null,
              fontSize: 15,
            ),
          ),
          subtitle: _buildSubtitle(context),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.priority != TodoPriority.none)
                Container(
                  width: 10, height: 10,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: _priorityColor(item.priority),
                    shape: BoxShape.circle,
                  ),
                ),
              if (canReorder)
                const Icon(Icons.drag_handle_rounded, color: Colors.grey, size: 20),
            ],
          ),
          onTap: onEdit,
        ),
      ),
    );
  }

  Widget? _buildSubtitle(BuildContext context) {
    final parts = <Widget>[];
    if (item.dueDate != null) {
      parts.add(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_today_rounded,
              size: 11,
              color: item.isOverdue ? Colors.red : Colors.grey.shade500),
          const SizedBox(width: 3),
          Text(
            _formatDue(item.dueDate!),
            style: TextStyle(
              fontSize: 11,
              color: item.isOverdue ? Colors.red : Colors.grey.shade500,
              fontWeight: item.isOverdue ? FontWeight.w600 : null,
            ),
          ),
        ],
      ));
    }
    if (item.priority != TodoPriority.none) {
      parts.add(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flag_rounded, size: 11, color: _priorityColor(item.priority)),
          const SizedBox(width: 3),
          Text(_priorityLabel(item.priority),
              style: TextStyle(fontSize: 11, color: _priorityColor(item.priority))),
        ],
      ));
    }
    if (item.note != null && item.note!.isNotEmpty) {
      parts.add(Text(item.note!,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis));
    }
    if (parts.isEmpty) return null;
    return Wrap(spacing: 10, children: parts);
  }
}

// ─── Add item sheet (with details) ───────────────────────────────────────────
class _AddItemSheet extends StatefulWidget {
  final String listId;
  const _AddItemSheet({required this.listId});

  @override
  State<_AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<_AddItemSheet> {
  final _textCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  TodoPriority _priority = TodoPriority.none;
  DateTime? _dueDate;

  @override
  void dispose() {
    _textCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _submit() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    final svc = Provider.of<TodoService>(context, listen: false);
    await svc.addItem(widget.listId, text,
        dueDate: _dueDate,
        priority: _priority,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim());
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('New Task', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 16),
          TextField(
            controller: _textCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Task name',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(
              hintText: 'Note (optional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          // Priority row
          const Text('Priority', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: TodoPriority.values.map((p) {
              final selected = _priority == p;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(_priorityLabel(p)),
                  selected: selected,
                  selectedColor: p == TodoPriority.none
                      ? Colors.grey.shade200
                      : _priorityColor(p).withValues(alpha: 0.25),
                  avatar: p != TodoPriority.none
                      ? Icon(Icons.flag_rounded, size: 14, color: _priorityColor(p))
                      : null,
                  onSelected: (_) => setState(() => _priority = p),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          // Due date row
          Row(
            children: [
              const Text('Due date', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const Spacer(),
              if (_dueDate != null)
                TextButton(
                  onPressed: () => setState(() => _dueDate = null),
                  child: const Text('Clear'),
                ),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today_rounded, size: 16),
                label: Text(_dueDate != null ? _formatDue(_dueDate!) : 'Pick date'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submit,
              child: const Text('Add Task'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Edit item sheet ──────────────────────────────────────────────────────────
class _EditItemSheet extends StatefulWidget {
  final String listId;
  final TodoItem item;
  const _EditItemSheet({required this.listId, required this.item});

  @override
  State<_EditItemSheet> createState() => _EditItemSheetState();
}

class _EditItemSheetState extends State<_EditItemSheet> {
  late TextEditingController _textCtrl;
  late TextEditingController _noteCtrl;
  late TodoPriority _priority;
  DateTime? _dueDate;

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController(text: widget.item.text);
    _noteCtrl = TextEditingController(text: widget.item.note ?? '');
    _priority = widget.item.priority;
    _dueDate = widget.item.dueDate;
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _save() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    final svc = Provider.of<TodoService>(context, listen: false);
    await svc.updateItem(
      widget.listId, widget.item.id,
      text: text,
      dueDate: _dueDate,
      clearDueDate: _dueDate == null && widget.item.dueDate != null,
      priority: _priority,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Edit Task', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 16),
          TextField(
            controller: _textCtrl,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Task name', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(hintText: 'Note (optional)', border: OutlineInputBorder()),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          const Text('Priority', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: TodoPriority.values.map((p) {
              final selected = _priority == p;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(_priorityLabel(p)),
                  selected: selected,
                  selectedColor: p == TodoPriority.none
                      ? Colors.grey.shade200
                      : _priorityColor(p).withValues(alpha: 0.25),
                  avatar: p != TodoPriority.none
                      ? Icon(Icons.flag_rounded, size: 14, color: _priorityColor(p))
                      : null,
                  onSelected: (_) => setState(() => _priority = p),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Due date', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const Spacer(),
              if (_dueDate != null)
                TextButton(onPressed: () => setState(() => _dueDate = null), child: const Text('Clear')),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today_rounded, size: 16),
                label: Text(_dueDate != null ? _formatDue(_dueDate!) : 'Pick date'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: _save, child: const Text('Save')),
          ),
        ],
      ),
    );
  }
}

// ─── List options sheet (rename, color, icon, clear completed, delete) ────────
class _ListOptionsSheet extends StatefulWidget {
  final TodoList list;
  const _ListOptionsSheet({required this.list});

  @override
  State<_ListOptionsSheet> createState() => _ListOptionsSheetState();
}

class _ListOptionsSheetState extends State<_ListOptionsSheet> {
  late TextEditingController _titleCtrl;
  late String? _color;
  late String? _icon;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.list.title);
    _color = widget.list.color;
    _icon = widget.list.icon;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final svc = Provider.of<TodoService>(context, listen: false);
    await svc.updateList(widget.list.id,
        title: _titleCtrl.text.trim().isEmpty ? widget.list.title : _titleCtrl.text.trim(),
        color: _color,
        icon: _icon);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final svc = Provider.of<TodoService>(context, listen: false);

    return Padding(
      padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('List Options', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'List name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            // Icon picker
            const Text('Icon', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _kListIcons.map((ic) {
                final selected = _icon == ic;
                return GestureDetector(
                  onTap: () => setState(() => _icon = selected ? null : ic),
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: selected
                          ? theme.colorScheme.primary.withValues(alpha: 0.15)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: selected
                          ? Border.all(color: theme.colorScheme.primary, width: 2)
                          : null,
                    ),
                    child: Center(child: Text(ic, style: const TextStyle(fontSize: 22))),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            // Color picker
            const Text('Color', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _kListColors.map((hex) {
                final col = _hexToColor(hex) ?? Colors.white;
                final selected = _color == hex;
                return GestureDetector(
                  onTap: () => setState(() => _color = hex),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: col,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? theme.colorScheme.primary
                            : Colors.grey.shade300,
                        width: selected ? 3 : 1,
                      ),
                    ),
                    child: selected
                        ? const Icon(Icons.check, size: 16)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: _save, child: const Text('Save')),
            ),
            const SizedBox(height: 8),
            if (widget.list.doneCount > 0)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.cleaning_services_rounded),
                  label: Text('Clear ${widget.list.doneCount} completed'),
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    await svc.clearCompleted(widget.list.id);
                    navigator.pop();
                  },
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                label: const Text('Delete list', style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete list'),
                      content: const Text('This will permanently delete the list and all its tasks.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Delete', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true && mounted) {
                    await svc.deleteList(widget.list.id);
                    navigator.pop();       // close sheet
                    navigator.pop();       // go back to list screen
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
