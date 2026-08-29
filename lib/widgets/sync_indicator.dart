import 'package:flutter/material.dart';
import '../models/sync_state.dart';

/// Refined Sync status indicator for the premium app bar
class SyncIndicator extends StatelessWidget {
  final SyncState syncState;

  const SyncIndicator({
    super.key,
    required this.syncState,
  });

  IconData _getIcon() {
    switch (syncState.status) {
      case SyncStatus.idle:
      case SyncStatus.success:
        return Icons.cloud_done_rounded;
      case SyncStatus.syncing:
        return Icons.sync_rounded;
      case SyncStatus.error:
        return Icons.cloud_off_rounded;
      case SyncStatus.offline:
        return Icons.cloud_off_rounded;
    }
  }

  Color _getColor(BuildContext context) {
    final theme = Theme.of(context);
    switch (syncState.status) {
      case SyncStatus.idle:
      case SyncStatus.success:
        return Colors.green.shade400;
      case SyncStatus.syncing:
        return theme.colorScheme.primary;
      case SyncStatus.error:
        return theme.colorScheme.error;
      case SyncStatus.offline:
        return Colors.grey.shade400;
    }
  }

  String _getTooltip() {
    switch (syncState.status) {
      case SyncStatus.idle:
        return 'All notes synced';
      case SyncStatus.success:
        return 'Sync complete';
      case SyncStatus.syncing:
        return 'Syncing changes...';
      case SyncStatus.error:
        return 'Sync error: ${syncState.errorMessage ?? "Unknown"}';
      case SyncStatus.offline:
        return 'Offline mode';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor(context);
    final hasPending = syncState.hasPendingChanges && syncState.status != SyncStatus.syncing;

    Widget icon = syncState.status == SyncStatus.syncing
        ? _RotatingIcon(color: color)
        : Icon(_getIcon(), color: color, size: 20);

    return Tooltip(
      message: _getTooltip(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            if (hasPending) ...[
              const SizedBox(width: 6),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RotatingIcon extends StatefulWidget {
  final Color color;
  const _RotatingIcon({required this.color});

  @override
  State<_RotatingIcon> createState() => _RotatingIconState();
}

class _RotatingIconState extends State<_RotatingIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(seconds: 2), vsync: this)..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Icon(Icons.sync_rounded, color: widget.color, size: 20),
    );
  }
}
