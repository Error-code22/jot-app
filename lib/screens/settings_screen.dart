import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/theme_provider.dart';
import '../utils/view_mode_provider.dart';
import '../services/backup_service.dart';
import '../services/i_auth_service.dart';
import 'import_screen.dart';
import 'support_screen.dart';
import 'terms_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final viewProvider = Provider.of<ViewModeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Appearance
          const _SectionHeader('Appearance'),
          const SizedBox(height: 12),
          _ThemeTile(label: 'Light', icon: Icons.light_mode_rounded,
            selected: themeProvider.mode == AppThemeMode.light,
            onTap: () => themeProvider.setMode(AppThemeMode.light)),
          const SizedBox(height: 8),
          _ThemeTile(label: 'Dark', icon: Icons.dark_mode_rounded,
            selected: themeProvider.mode == AppThemeMode.dark,
            onTap: () => themeProvider.setMode(AppThemeMode.dark)),
          const SizedBox(height: 8),
          _ThemeTile(label: 'System default', icon: Icons.brightness_auto_rounded,
            selected: themeProvider.mode == AppThemeMode.system,
            onTap: () => themeProvider.setMode(AppThemeMode.system)),
          const SizedBox(height: 32),

          // View Mode
          const _SectionHeader('Notes View'),
          const SizedBox(height: 12),
          _ThemeTile(label: 'Grid (Tiles)', icon: Icons.grid_view_rounded,
            selected: viewProvider.mode == ViewMode.grid,
            onTap: () => viewProvider.setMode(ViewMode.grid)),
          const SizedBox(height: 8),
          _ThemeTile(label: 'List (Detailed)', icon: Icons.view_list_rounded,
            selected: viewProvider.mode == ViewMode.list,
            onTap: () => viewProvider.setMode(ViewMode.list)),
          const SizedBox(height: 8),
          _ThemeTile(label: 'Compact', icon: Icons.density_small_rounded,
            selected: viewProvider.mode == ViewMode.compact,
            onTap: () => viewProvider.setMode(ViewMode.compact)),
          const SizedBox(height: 32),

          // Font size
          const _SectionHeader('Editor Font Size'),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Small', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text('${viewProvider.fontSize.round()}px', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                    const Text('Large', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                Slider(
                  value: viewProvider.fontSize,
                  min: 12, max: 24, divisions: 6,
                  onChanged: (v) => viewProvider.setFontSize(v),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [12.0, 14.0, 16.0, 18.0, 20.0, 22.0, 24.0].map((s) =>
                    GestureDetector(
                      onTap: () => viewProvider.setFontSize(s),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: viewProvider.fontSize == s ? theme.colorScheme.primary.withValues(alpha: 0.15) : Colors.transparent,
                          border: Border.all(color: viewProvider.fontSize == s ? theme.colorScheme.primary : Colors.transparent),
                        ),
                        child: Text('${s.round()}', style: TextStyle(fontSize: 12, color: viewProvider.fontSize == s ? theme.colorScheme.primary : Colors.grey)),
                      ),
                    )
                  ).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Import
          const _SectionHeader('Import'),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.upload_file_outlined,
            title: 'Import Notes',
            subtitle: 'Import .txt, .md files or entire folders',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ImportScreen())),
          ),
          const SizedBox(height: 32),

          // Backup & Export
          const _SectionHeader('Backup & Export'),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.backup_outlined,
            title: 'Export as JSON',
            subtitle: 'Export all notes as a JSON file',
            onTap: () async {
              final backup = Provider.of<BackupService>(context, listen: false);
              final auth = Provider.of<IAuthService>(context, listen: false);
              final user = auth.getCurrentUser();
              if (user == null) return;
              try {
                await backup.exportNotesAsJson(user.uid);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Notes exported as JSON')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Export failed: $e')),
                  );
                }
              }
            },
          ),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.archive_outlined,
            title: 'Export as ZIP',
            subtitle: 'Export all notes as a compressed archive',
            onTap: () async {
              final backup = Provider.of<BackupService>(context, listen: false);
              final auth = Provider.of<IAuthService>(context, listen: false);
              final user = auth.getCurrentUser();
              if (user == null) return;
              try {
                final file = await backup.exportNotesAsZip(user.uid);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Backup saved to ${file.path}')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Export failed: $e')),
                  );
                }
              }
            },
          ),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.share_outlined,
            title: 'Share Backup',
            subtitle: 'Share notes backup with other apps',
            onTap: () async {
              final backup = Provider.of<BackupService>(context, listen: false);
              final auth = Provider.of<IAuthService>(context, listen: false);
              final user = auth.getCurrentUser();
              if (user == null) return;
              await backup.shareNotesAsJson(user.uid);
            },
          ),
          const SizedBox(height: 32),

          // About
          const _SectionHeader('About'),
          const SizedBox(height: 12),
          const _SettingsTile(icon: Icons.info_outline_rounded, title: 'Version', trailing: Text('2.0.0', style: TextStyle(color: Colors.grey))),
          const SizedBox(height: 8),
          _SettingsTile(icon: Icons.help_outline_rounded, title: 'Support',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportScreen()))),
          const SizedBox(height: 8),
          _SettingsTile(icon: Icons.description_outlined, title: 'Terms of Service',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsScreen()))),
          const SizedBox(height: 8),
          _SettingsTile(icon: Icons.privacy_tip_outlined, title: 'Privacy Policy',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyScreen()))),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) => Text(title,
    style: Theme.of(context).textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary));
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  const _SettingsTile({required this.icon, required this.title, this.subtitle, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: trailing ?? (onTap != null ? const Icon(Icons.arrow_forward_ios_rounded, size: 16) : null),
      onTap: onTap,
    );
  }
}

class _ThemeTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _ThemeTile({required this.label, required this.icon, required this.selected, required this.onTap});

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
          color: selected ? theme.colorScheme.primary.withValues(alpha: 0.1) : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          border: Border.all(color: selected ? theme.colorScheme.primary : Colors.transparent, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? theme.colorScheme.primary : theme.iconTheme.color),
            const SizedBox(width: 16),
            Text(label, style: TextStyle(fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              color: selected ? theme.colorScheme.primary : null)),
            const Spacer(),
            if (selected) Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary, size: 20),
          ],
        ),
      ),
    );
  }
}
