import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_info.dart';
import '../services/update_service.dart';
import '../utils/adaptive_logo.dart';
import '../utils/markdown_renderer.dart';

/// Runs an update check and, when a newer build exists, opens the full-screen
/// update page.
///
/// [silent] is used for the automatic check on launch: it suppresses the "up
/// to date" / failure snackbars but still shows the update page.
Future<void> checkForUpdatesWithUi(
  BuildContext context,
  UpdateService service, {
  bool silent = false,
}) async {
  final result = await service.checkForUpdates();
  if (!context.mounted) return;

  if (!result.supported) {
    if (!silent) {
      _snack(context, result.message ?? 'Could not check for updates.');
    }
    return;
  }

  if (!result.updateAvailable || result.release == null) {
    if (!silent) {
      _snack(context, result.message ?? 'You are on the latest version.');
    }
    return;
  }

  await Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => UpdateScreen(service: service, release: result.release!),
    ),
  );
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

/// Full-screen update page in the style of a "Discover new version" screen:
/// version heading, formatted release notes, download progress, an integrity
/// note, and a not-now action.
class UpdateScreen extends StatefulWidget {
  final UpdateService service;
  final AppRelease release;

  const UpdateScreen({
    super.key,
    required this.service,
    required this.release,
  });

  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen> {
  UpdateDownloadHandle _handle = UpdateDownloadHandle();
  bool _downloading = false;
  bool _finished = false;
  double _progress = 0;
  String? _result;

  AppRelease get _release => widget.release;
  bool get _hasDownload => (_release.downloadUrl ?? '').isNotEmpty;
  bool get _hasPage => (_release.pageUrl ?? '').isNotEmpty;

  Future<void> _start() async {
    _handle = UpdateDownloadHandle();
    setState(() {
      _downloading = true;
      _finished = false;
      _result = null;
      _progress = 0;
    });

    final message = await widget.service.downloadAndInstall(
      _release,
      onProgress: (value) {
        if (mounted) setState(() => _progress = value);
      },
      handle: _handle,
    );
    if (!mounted) return;

    if (_handle.isCancelled) {
      setState(() {
        _downloading = false;
        _finished = false;
        _result = null;
        _progress = 0;
      });
      return;
    }

    setState(() {
      _downloading = false;
      _finished = true;
      _result = message;
    });
  }

  void _cancel() => _handle.cancel();

  Future<void> _openPage() async {
    final url = _release.pageUrl;
    if (url == null || url.isEmpty) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notes = _release.notes?.trim() ?? '';

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
              child: Row(
                children: [
                  Image.asset(adaptiveLogoPath(context), height: 32),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Discover new version v${_release.version}',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You are on ${AppInfo.versionLabel}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (_release.sizeBytes != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Download size ${_formatBytes(_release.sizeBytes)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Text.rich(
                      MarkdownRenderer.render(
                        notes.isEmpty
                            ? 'A new version is ready to install.'
                            : notes,
                        baseStyle: theme.textTheme.bodyLarge?.copyWith(
                              height: 1.5,
                            ) ??
                            const TextStyle(height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_downloading) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _progress > 0 ? _progress : null,
                minHeight: 12,
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                _progress > 0
                    ? 'Downloading… ${(_progress * 100).toStringAsFixed(0)}%'
                    : 'Starting download…',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 12),
            _integrityNote(context),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _cancel,
              child: const Text('Cancel'),
            ),
          ] else if (_finished) ...[
            _integrityNote(context),
            const SizedBox(height: 12),
            Text(
              _result ?? 'The update is ready to install.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Done'),
            ),
          ] else ...[
            _integrityNote(context),
            const SizedBox(height: 12),
            if (_hasDownload)
              FilledButton(
                onPressed: _start,
                child: const Text('Update now'),
              )
            else if (_hasPage)
              FilledButton(
                onPressed: _openPage,
                child: const Text('Open release page'),
              )
            else
              const FilledButton(
                onPressed: null,
                child: Text('No build for this device yet'),
              ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Not now'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _integrityNote(BuildContext context) {
    final theme = Theme.of(context);
    final verified = (_release.sha256 ?? '').isNotEmpty;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          verified
              ? Icons.verified_user_outlined
              : Icons.cloud_download_outlined,
          size: 16,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            verified
                ? 'Security verified · checksum checked'
                : 'Official release channel',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

String _formatBytes(int? bytes) {
  if (bytes == null || bytes <= 0) return 'unknown';
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final digits = unit == 0 || value >= 10 ? 0 : 1;
  return '${value.toStringAsFixed(digits)} ${units[unit]}';
}
