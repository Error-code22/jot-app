import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../core/app_info.dart';
import '../services/app_settings.dart';
import '../services/backup_service.dart';
import '../services/biometric_service.dart';
import '../services/feedback_service.dart';
import '../services/i_auth_service.dart';
import '../services/note_service.dart';
import '../services/notification_service.dart';
import '../services/sync_engine.dart';
import '../services/todo_service.dart';
import '../services/update_service.dart';
import '../utils/theme_provider.dart';
import '../utils/view_mode_provider.dart';
import 'feedback_screen.dart';
import 'import_screen.dart';
import 'support_screen.dart';
import 'terms_screen.dart';
import 'update_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final viewProvider = Provider.of<ViewModeProvider>(context);
    final settings = Provider.of<AppSettings>(context);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomInset),
        children: [
          // ── Appearance ────────────────────────────────────────────────────
          const _SectionHeader('Appearance'),
          const SizedBox(height: 8),
          _ChoiceTile(
            label: 'System default',
            icon: Icons.brightness_auto_rounded,
            selected: themeProvider.mode == AppThemeMode.system,
            onTap: () => themeProvider.setMode(AppThemeMode.system),
          ),
          const SizedBox(height: 6),
          _ChoiceTile(
            label: 'Light',
            icon: Icons.light_mode_rounded,
            selected: themeProvider.mode == AppThemeMode.light,
            onTap: () => themeProvider.setMode(AppThemeMode.light),
          ),
          const SizedBox(height: 6),
          _ChoiceTile(
            label: 'Dark',
            icon: Icons.dark_mode_rounded,
            selected: themeProvider.mode == AppThemeMode.dark,
            onTap: () => themeProvider.setMode(AppThemeMode.dark),
          ),
          const SizedBox(height: 24),

          // ── Notes view ────────────────────────────────────────────────────
          const _SectionHeader('Notes view'),
          const SizedBox(height: 8),
          _ChoiceTile(
            label: 'Grid (tiles)',
            icon: Icons.grid_view_rounded,
            selected: viewProvider.mode == ViewMode.grid,
            onTap: () => viewProvider.setMode(ViewMode.grid),
          ),
          const SizedBox(height: 6),
          _ChoiceTile(
            label: 'List (detailed)',
            icon: Icons.view_list_rounded,
            selected: viewProvider.mode == ViewMode.list,
            onTap: () => viewProvider.setMode(ViewMode.list),
          ),
          const SizedBox(height: 6),
          _ChoiceTile(
            label: 'Compact',
            icon: Icons.density_small_rounded,
            selected: viewProvider.mode == ViewMode.compact,
            onTap: () => viewProvider.setMode(ViewMode.compact),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.format_size_rounded, size: 20),
                    const SizedBox(width: 12),
                    const Text('Editor font size'),
                    const Spacer(),
                    Text('${viewProvider.fontSize.round()} px',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary)),
                  ],
                ),
                Slider(
                  value: viewProvider.fontSize.clamp(12, 24),
                  min: 12,
                  max: 24,
                  divisions: 6,
                  label: '${viewProvider.fontSize.round()} px',
                  onChanged: (v) => viewProvider.setFontSize(v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Privacy ───────────────────────────────────────────────────────
          const _SectionHeader('Privacy & Security'),
          const SizedBox(height: 8),
          _SwitchTile(
            icon: Icons.visibility_off_outlined,
            title: 'Hide note previews',
            subtitle:
                'Never show note text, images, or tags in lists. Titles remain visible.',
            value: settings.hideNotePreviews,
            onChanged: (value) => settings.setHideNotePreviews(value),
          ),
          const SizedBox(height: 6),
          _SwitchTile(
            icon: Icons.fingerprint_rounded,
            title: 'Biometric unlock',
            subtitle:
                'Use fingerprint, face, or device PIN for locked notes. Your app PIN always works as a fallback.',
            value: settings.biometricUnlock,
            onChanged: (value) => _setBiometricUnlock(context, value),
          ),
          const SizedBox(height: 24),

          // ── Notifications ─────────────────────────────────────────────────
          const _SectionHeader('Notifications'),
          const SizedBox(height: 8),
          _SwitchTile(
            icon: Icons.alarm_rounded,
            title: 'To-do reminders',
            subtitle: 'Schedule reminders for tasks that have one enabled.',
            value: settings.todoReminders,
            onChanged: (value) => _setTodoReminders(context, value),
          ),
          const SizedBox(height: 6),
          _SwitchTile(
            icon: Icons.event_note_rounded,
            title: 'Due-date alerts',
            subtitle:
                'Show a daily alert for overdue tasks and tasks due today or tomorrow.',
            value: settings.dueDateNotifications,
            onChanged: settings.setDueDateNotifications,
          ),
          const SizedBox(height: 6),
          _SettingsTile(
            icon: Icons.notifications_active_outlined,
            title: 'Send test notification',
            subtitle: 'Check that notifications are allowed on this device',
            onTap: () => _sendTestNotification(context),
          ),
          const SizedBox(height: 24),

          // ── Updates ───────────────────────────────────────────────────────
          const _SectionHeader('App updates'),
          const SizedBox(height: 8),
          _SwitchTile(
            icon: Icons.update_rounded,
            title: 'Check automatically',
            subtitle: 'Look for a new release once a day when you sign in.',
            value: settings.autoCheckUpdates,
            onChanged: settings.setAutoCheckUpdates,
          ),
          const SizedBox(height: 6),
          _SettingsTile(
            icon: Icons.system_update_alt_rounded,
            title: 'Check for updates now',
            subtitle: 'Current version ${AppInfo.versionLabel}',
            onTap: () async {
              await checkForUpdatesWithUi(
                  context, Provider.of<UpdateService>(context, listen: false));
              await settings.markUpdateChecked();
            },
          ),
          const SizedBox(height: 24),

          // ── Data ──────────────────────────────────────────────────────────
          const _SectionHeader('Data'),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.upload_file_outlined,
            title: 'Import notes',
            subtitle: 'Import .txt, .md, or .json files',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ImportScreen())),
          ),
          const SizedBox(height: 6),
          _SettingsTile(
            icon: Icons.download_rounded,
            title: 'Restore from backup',
            subtitle: 'Restore notes from a Jot? .zip or .json backup',
            onTap: () => _restoreBackup(context),
          ),
          const SizedBox(height: 6),
          _SettingsTile(
            icon: Icons.data_object_rounded,
            title: 'Export as JSON',
            subtitle: 'Save all notes to a JSON file',
            onTap: () => _exportJson(context),
          ),
          const SizedBox(height: 6),
          _SettingsTile(
            icon: Icons.archive_outlined,
            title: 'Export as ZIP',
            subtitle: 'Save a complete backup to the app documents folder',
            onTap: () => _exportZip(context),
          ),
          const SizedBox(height: 6),
          _SettingsTile(
            icon: Icons.share_outlined,
            title: 'Share backup',
            subtitle: 'Send a complete ZIP backup to another app',
            onTap: () => _shareBackup(context),
          ),
          const SizedBox(height: 24),

          // ── Help & about ──────────────────────────────────────────────────
          const _SectionHeader('Help & About'),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.help_outline_rounded,
            title: 'Support',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SupportScreen())),
          ),
          const SizedBox(height: 6),
          _SettingsTile(
            icon: Icons.bug_report_outlined,
            title: 'Report a bug',
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        const FeedbackScreen(initialType: FeedbackType.bug))),
          ),
          const SizedBox(height: 6),
          _SettingsTile(
            icon: Icons.lightbulb_outline_rounded,
            title: 'Request a feature',
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const FeedbackScreen(
                        initialType: FeedbackType.feature))),
          ),
          const SizedBox(height: 6),
          _SettingsTile(
            icon: Icons.description_outlined,
            title: 'Terms of Service',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const TermsScreen())),
          ),
          const SizedBox(height: 6),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const PrivacyScreen())),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'Jot? ${AppInfo.versionLabel}',
              style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _setBiometricUnlock(BuildContext context, bool value) async {
    final settings = Provider.of<AppSettings>(context, listen: false);
    if (value) {
      final biometric = Provider.of<BiometricService>(context, listen: false);
      final available = await biometric.canUseDeviceAuth;
      if (!available) {
        if (context.mounted) {
          _snack(context,
              'No biometric or device authentication is available on this device.');
        }
        return;
      }
    }
    await settings.setBiometricUnlock(value);
  }

  Future<void> _setTodoReminders(BuildContext context, bool value) async {
    final settings = Provider.of<AppSettings>(context, listen: false);
    final notifications =
        Provider.of<NotificationService>(context, listen: false);
    final todos = Provider.of<TodoService>(context, listen: false);
    await settings.setTodoReminders(value);
    if (value) {
      await notifications.requestPermission();
      await notifications.rescheduleAll(todos);
    } else {
      await notifications.cancelAll();
    }
  }

  Future<void> _sendTestNotification(BuildContext context) async {
    final notifications =
        Provider.of<NotificationService>(context, listen: false);
    final granted = await notifications.requestPermission();
    if (!context.mounted) return;
    if (!granted) {
      _snack(context,
          'Notifications are blocked. Enable them in system settings.');
      return;
    }
    await notifications.showTestNotification();
    if (context.mounted) _snack(context, 'Test notification sent.');
  }

  Future<void> _exportJson(BuildContext context) async {
    final backup = Provider.of<BackupService>(context, listen: false);
    final user =
        Provider.of<IAuthService>(context, listen: false).getCurrentUser();
    if (user == null) return;
    try {
      final json = await backup.exportNotesAsJson(user.uid);
      final file = await _backupFile('jot_notes_${_timestamp()}.json');
      await file.writeAsString(json);
      if (context.mounted) _snack(context, 'Exported to ${file.path}');
    } catch (e) {
      if (context.mounted) _snack(context, 'Export failed: $e');
    }
  }

  Future<void> _exportZip(BuildContext context) async {
    final backup = Provider.of<BackupService>(context, listen: false);
    final user =
        Provider.of<IAuthService>(context, listen: false).getCurrentUser();
    if (user == null) return;
    try {
      final path = await backup.createLocalBackup(user.uid);
      if (context.mounted) _snack(context, 'Backup saved to $path');
    } catch (e) {
      if (context.mounted) _snack(context, 'Export failed: $e');
    }
  }

  Future<void> _shareBackup(BuildContext context) async {
    final backup = Provider.of<BackupService>(context, listen: false);
    final user =
        Provider.of<IAuthService>(context, listen: false).getCurrentUser();
    if (user == null) return;
    try {
      await backup.shareNotesAsZip(user.uid);
    } catch (e) {
      if (context.mounted) _snack(context, 'Could not share backup: $e');
    }
  }

  Future<void> _restoreBackup(BuildContext context) async {
    final backup = Provider.of<BackupService>(context, listen: false);
    final noteService = Provider.of<NoteService>(context, listen: false);
    final syncEngine = Provider.of<SyncEngine>(context, listen: false);
    final user =
        Provider.of<IAuthService>(context, listen: false).getCurrentUser();
    if (user == null) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'zip'],
        withData: true,
      );
      if (result == null) return;
      final picked = result.files.single;
      final bytes = picked.bytes ??
          (picked.path == null ? null : await File(picked.path!).readAsBytes());
      if (bytes == null) {
        if (context.mounted) _snack(context, 'Could not read that file.');
        return;
      }

      int count;
      final name = picked.name.toLowerCase();
      if (name.endsWith('.zip')) {
        final temp = await _backupFile('restore_${_timestamp()}.zip');
        await temp.writeAsBytes(bytes);
        count = await backup.importNotesFromZip(user.uid, temp);
        await temp.delete();
      } else {
        count = await backup.importNotesFromJson(user.uid, utf8.decode(bytes));
      }

      await noteService.notifyExternalChange(user.uid);
      unawaited(syncEngine.syncNow(user.uid));
      if (context.mounted) {
        _snack(context,
            count == 0 ? 'No new notes to restore.' : 'Restored $count notes.');
      }
    } catch (e) {
      if (context.mounted) _snack(context, 'Restore failed: $e');
    }
  }

  Future<File> _backupFile(String name) async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory('${documents.path}/jot_backups');
    if (!await directory.exists()) await directory.create(recursive: true);
    return File('${directory.path}/$name');
  }

  String _timestamp() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}_'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

// ── Shared settings widgets ─────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                  letterSpacing: 0.4,
                )),
      );
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      secondary: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor:
          theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor:
          theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.1)
              : theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.4),
          border: Border.all(
              color: selected ? theme.colorScheme.primary : Colors.transparent,
              width: 1.5),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.iconTheme.color),
            const SizedBox(width: 16),
            Text(label,
                style: TextStyle(
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    color: selected ? theme.colorScheme.primary : null)),
            const Spacer(),
            if (selected)
              Icon(Icons.check_circle_rounded,
                  color: theme.colorScheme.primary, size: 20),
          ],
        ),
      ),
    );
  }
}
