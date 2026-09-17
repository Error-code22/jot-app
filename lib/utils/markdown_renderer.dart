import 'package:flutter/material.dart';

/// Renders markdown-like syntax as styled TextSpans.
/// Supports: **bold**, _italic_, ~~strikethrough~~, # headings, • bullets, - lists
class MarkdownRenderer {
  static TextSpan render(String text, {required TextStyle baseStyle}) {
    final spans = <TextSpan>[];
    final lines = text.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Headings
      if (line.startsWith('### ')) {
        spans.add(TextSpan(
          text: line.substring(4),
          style: baseStyle.copyWith(fontSize: baseStyle.fontSize != null ? baseStyle.fontSize! * 0.9 : 14, fontWeight: FontWeight.w600),
        ));
      } else if (line.startsWith('## ')) {
        spans.add(TextSpan(
          text: line.substring(3),
          style: baseStyle.copyWith(fontSize: baseStyle.fontSize != null ? baseStyle.fontSize! * 1.1 : 18, fontWeight: FontWeight.w700),
        ));
      } else if (line.startsWith('# ')) {
        spans.add(TextSpan(
          text: line.substring(2),
          style: baseStyle.copyWith(fontSize: baseStyle.fontSize != null ? baseStyle.fontSize! * 1.3 : 22, fontWeight: FontWeight.w800),
        ));
      }
      // Bullet lists
      else if (line.startsWith('• ') || line.startsWith('- ')) {
        spans.add(TextSpan(
          children: [
            TextSpan(text: '  •  ', style: baseStyle.copyWith(color: baseStyle.color?.withValues(alpha: 0.5))),
            ..._parseInline(line.substring(2), baseStyle),
          ],
        ));
      }
      // Numbered lists
      else if (RegExp(r'^\d+\.\s').hasMatch(line)) {
        final match = RegExp(r'^(\d+\.\s)(.*)').firstMatch(line)!;
        spans.add(TextSpan(
          children: [
            TextSpan(text: '  ${match.group(1)}', style: baseStyle.copyWith(color: baseStyle.color?.withValues(alpha: 0.5))),
            ..._parseInline(match.group(2)!, baseStyle),
          ],
        ));
      }
      // Horizontal rule
      else if (line.trim() == '---' || line.trim() == '***') {
        spans.add(TextSpan(
          text: '─────────────────────',
          style: baseStyle.copyWith(color: baseStyle.color?.withValues(alpha: 0.2)),
        ));
      }
      // Regular text with inline formatting
      else {
        spans.addAll(_parseInline(line, baseStyle));
      }

      // Add line break between lines (except last)
      if (i < lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }

    return TextSpan(children: spans);
  }

  /// Parse inline formatting: **bold**, _italic_, ~~strikethrough~~
  static List<TextSpan> _parseInline(String text, TextStyle baseStyle) {
    final spans = <TextSpan>[];
    final pattern = RegExp(
      r'(\*\*(.+?)\*\*)|(_(.+?)_)|(\~\~(.+?)\~\~)',
    );

    int lastEnd = 0;
    for (final match in pattern.allMatches(text)) {
      // Add text before the match
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }

      if (match.group(2) != null) {
        // **bold**
        spans.add(TextSpan(
          text: match.group(2),
          style: baseStyle.copyWith(fontWeight: FontWeight.bold),
        ));
      } else if (match.group(4) != null) {
        // _italic_
        spans.add(TextSpan(
          text: match.group(4),
          style: baseStyle.copyWith(fontStyle: FontStyle.italic),
        ));
      } else if (match.group(6) != null) {
        // ~~strikethrough~~
        spans.add(TextSpan(
          text: match.group(6),
          style: baseStyle.copyWith(decoration: TextDecoration.lineThrough),
        ));
      }

      lastEnd = match.end;
    }

    // Add remaining text
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    if (spans.isEmpty) {
      spans.add(TextSpan(text: text));
    }

    return spans;
  }
}
