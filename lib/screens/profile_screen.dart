import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/i_auth_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<IAuthService>(context, listen: false);
    final user = authService.getCurrentUser();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Avatar + name
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                  backgroundImage: user?.photoUrl != null
                      ? NetworkImage(user!.photoUrl!)
                      : null,
                  child: user?.photoUrl == null
                      ? Icon(Icons.person_rounded, size: 48, color: theme.colorScheme.primary)
                      : null,
                ),
                const SizedBox(height: 16),
                Text(
                  user?.displayName ?? 'User',
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? '',
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Account info section
          Text('Account', style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          )),
          const SizedBox(height: 12),
          _InfoTile(icon: Icons.person_outline_rounded, label: 'Name', value: user?.displayName ?? '—'),
          const SizedBox(height: 8),
          _InfoTile(icon: Icons.email_outlined, label: 'Email', value: user?.email ?? '—'),
          const SizedBox(height: 8),
          _InfoTile(icon: Icons.badge_outlined, label: 'User ID', value: user?.uid ?? '—', mono: true),
          const SizedBox(height: 8),
          _InfoTile(
            icon: Icons.calendar_today_outlined,
            label: 'Member since',
            value: user?.createdAt != null
                ? '${user!.createdAt.day}/${user.createdAt.month}/${user.createdAt.year}'
                : '—',
          ),
          const SizedBox(height: 32),

          // Sign out
          OutlinedButton.icon(
            onPressed: () => _confirmSignOut(context, authService),
            icon: const Icon(Icons.logout_rounded, color: Colors.red),
            label: const Text('Sign out', style: TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, IAuthService authService) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await authService.signOut();
      if (!context.mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    }
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool mono;

  const _InfoTile({required this.icon, required this.label, required this.value, this.mono = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontFamily: mono ? 'monospace' : null,
                  fontSize: mono ? 11 : 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
