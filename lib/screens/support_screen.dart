import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'feedback_screen.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Support', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Get Help', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('We\'re here to help you get the most out of Jot?', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          
          _SupportTile(
            icon: Icons.email_outlined,
            title: 'Email Support',
            subtitle: 'reueldroner22@gmail.com',
            onTap: () => launchUrl(Uri.parse('mailto:reueldroner22@gmail.com?subject=Jot%3F%20Support')),
          ),
          const SizedBox(height: 12),
          _SupportTile(
            icon: Icons.bug_report_outlined,
            title: 'Report a Bug',
            subtitle: 'Help us improve Jot?',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FeedbackScreen())),
          ),
          const SizedBox(height: 12),
          _SupportTile(
            icon: Icons.lightbulb_outline_rounded,
            title: 'Feature Request',
            subtitle: 'Suggest new features',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FeedbackScreen())),
          ),
          const SizedBox(height: 32),
          
          Text('About Jot?', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text(
            'Jot? is a privacy-focused, cross-platform notes app designed to capture your thoughts elegantly. '
            'Your notes are stored locally and synced securely to the cloud via Supabase.',
            style: TextStyle(height: 1.6),
          ),
          const SizedBox(height: 16),
          const Text('Version 2.0.0', style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}

class _SupportTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SupportTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
    );
  }
}
