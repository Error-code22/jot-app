import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms of Service', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: _LegalContent(
          title: 'Terms of Service',
          lastUpdated: 'April 16, 2026',
          sections: [
            _Section('1. Acceptance of Terms',
              'By using Jot?, you agree to these Terms of Service. If you do not agree, please do not use the app.'),
            _Section('2. Description of Service',
              'Jot? is a cross-platform notes application that allows you to create, edit, and sync notes across your devices. '
              'The service includes local storage, cloud synchronization via Firebase, and Google account authentication.'),
            _Section('3. User Accounts',
              'You must sign in with a valid Google account to use cloud sync features. You are responsible for maintaining '
              'the security of your account. You must not share your account credentials with others.'),
            _Section('4. Your Content',
              'You retain full ownership of all notes and content you create in Jot?. We do not claim any ownership over '
              'your content. You grant us a limited license to store and sync your content solely to provide the service.'),
            _Section('5. Acceptable Use',
              'You agree not to use Jot? to store or transmit illegal content, malware, or content that violates the rights '
              'of others. You agree not to attempt to reverse engineer, hack, or disrupt the service.'),
            _Section('6. Data Storage',
              'Your notes are stored locally on your device and optionally synced to Firebase Firestore. '
              'You can delete your data at any time by deleting your notes or your account.'),
            _Section('7. Service Availability',
              'We strive to keep Jot? available at all times but do not guarantee uninterrupted access. '
              'We may update, modify, or discontinue features with reasonable notice.'),
            _Section('8. Limitation of Liability',
              'Jot? is provided "as is" without warranties of any kind. We are not liable for any loss of data, '
              'indirect damages, or consequential losses arising from your use of the app.'),
            _Section('9. Changes to Terms',
              'We may update these terms from time to time. Continued use of Jot? after changes constitutes acceptance '
              'of the new terms.'),
            _Section('10. Contact',
              'For questions about these terms, contact us at reueldroner22@gmail.com'),
          ],
        ),
      ),
    );
  }
}

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: _LegalContent(
          title: 'Privacy Policy',
          lastUpdated: 'April 16, 2026',
          sections: [
            _Section('1. Information We Collect',
              'We collect the following information when you use Jot?:\n\n'
              '• Google account information (name, email, profile photo) when you sign in\n'
              '• Notes content you create and store in the app\n'
              '• Device information for app functionality\n'
              '• Usage data to improve the app'),
            _Section('2. How We Use Your Information',
              'We use your information to:\n\n'
              '• Provide and maintain the Jot? service\n'
              '• Sync your notes across devices\n'
              '• Authenticate your identity\n'
              '• Improve app performance and features\n'
              '• Respond to support requests'),
            _Section('3. Data Storage',
              'Your notes are stored:\n\n'
              '• Locally on your device using SQLite\n'
              '• In Firebase Firestore (Google Cloud) when cloud sync is enabled\n\n'
              'Firebase Firestore is hosted in europe-west1 and complies with GDPR.'),
            _Section('4. Data Sharing',
              'We do not sell, trade, or share your personal data with third parties except:\n\n'
              '• Firebase/Google Cloud for storage and authentication (see Google\'s Privacy Policy)\n'
              '• When required by law'),
            _Section('5. Data Security',
              'We implement security measures including:\n\n'
              '• Firestore security rules ensuring only you can access your notes\n'
              '• Secure credential storage using platform keychain\n'
              '• HTTPS/TLS for all data transmission'),
            _Section('6. Your Rights',
              'You have the right to:\n\n'
              '• Access your data at any time\n'
              '• Delete your notes and account data\n'
              '• Export your notes\n'
              '• Opt out of cloud sync (notes remain local only)'),
            _Section('7. Data Retention',
              'We retain your data as long as your account is active. '
              'When you delete a note, it is removed from both local storage and the cloud. '
              'You can request complete account deletion by contacting us.'),
            _Section('8. Children\'s Privacy',
              'Jot? is not intended for children under 13. We do not knowingly collect '
              'personal information from children under 13.'),
            _Section('9. Changes to This Policy',
              'We may update this privacy policy periodically. We will notify you of significant '
              'changes through the app.'),
            _Section('10. Contact Us',
              'For privacy concerns or data requests, contact us at:\nreueldroner22@gmail.com'),
          ],
        ),
      ),
    );
  }
}

class _LegalContent extends StatelessWidget {
  final String title;
  final String lastUpdated;
  final List<_Section> sections;

  const _LegalContent({required this.title, required this.lastUpdated, required this.sections});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('Last updated: $lastUpdated', style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 24),
        ...sections.map((s) => Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.heading, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(s.body, style: const TextStyle(height: 1.6)),
            ],
          ),
        )),
      ],
    );
  }
}

class _Section {
  final String heading;
  final String body;
  const _Section(this.heading, this.body);
}
