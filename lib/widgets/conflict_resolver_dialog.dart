import 'package:flutter/material.dart';
import '../models/note_model.dart';
import '../services/sync_engine.dart';

/// Dialog that shows conflicting note versions and lets user choose.
class ConflictResolverDialog extends StatefulWidget {
  final SyncConflict conflict;
  final Function(bool keepLocal) onResolve;
  final Function() onMerge;

  const ConflictResolverDialog({
    super.key,
    required this.conflict,
    required this.onResolve,
    required this.onMerge,
  });

  @override
  State<ConflictResolverDialog> createState() => _ConflictResolverDialogState();
}

class _ConflictResolverDialogState extends State<ConflictResolverDialog> {
  int _selectedVersion = 0; // 0 = local, 1 = remote, 2 = merge

  @override
  Widget build(BuildContext context) {
    final local = widget.conflict.localVersion;
    final remote = widget.conflict.remoteVersion;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.sync_problem,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sync Conflict',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onErrorContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'This note was edited on multiple devices',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onErrorContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Note title
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Icon(Icons.note, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      local.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Version comparison
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _buildVersionCard(
                      context,
                      title: 'Local Version',
                      subtitle: 'Edited ${_formatTime(local.modifiedAt)}',
                      note: local,
                      isSelected: _selectedVersion == 0,
                      onTap: () => setState(() => _selectedVersion = 0),
                      color: Theme.of(context).colorScheme.primaryContainer,
                    ),
                    const SizedBox(height: 12),
                    _buildVersionCard(
                      context,
                      title: 'Cloud Version',
                      subtitle: 'Edited ${_formatTime(remote.modifiedAt)}',
                      note: remote,
                      isSelected: _selectedVersion == 1,
                      onTap: () => setState(() => _selectedVersion = 1),
                      color: Theme.of(context).colorScheme.secondaryContainer,
                    ),
                    const SizedBox(height: 12),
                    _buildMergeCard(context),
                  ],
                ),
              ),
            ),

            // Actions
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        widget.onMerge();
                        Navigator.of(context).pop();
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Merge Both'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        widget.onResolve(_selectedVersion == 0);
                        Navigator.of(context).pop();
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(_selectedVersion == 0 ? 'Keep Local' : 'Keep Cloud'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVersionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Note note,
    required bool isSelected,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                note.content.isEmpty ? '(empty)' : note.content,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMergeCard(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _selectedVersion = 2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _selectedVersion == 2
              ? Theme.of(context).colorScheme.tertiaryContainer
              : Theme.of(context).colorScheme.tertiaryContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _selectedVersion == 2
                ? Theme.of(context).colorScheme.tertiary
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            width: _selectedVersion == 2 ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              _selectedVersion == 2 ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: Theme.of(context).colorScheme.tertiary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Icon(Icons.merge_type, color: Theme.of(context).colorScheme.tertiary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Merge Both Versions',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Combine content from both devices',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
