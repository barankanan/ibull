import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/blog_content.dart';
import 'blog_theme.dart';

/// Opens a validated blog link: in-app paths through the router, others in a
/// new tab / external app. Unsafe targets are ignored.
Future<void> openBlogLink(
  BuildContext context,
  String target, {
  bool newTab = false,
}) async {
  final value = target.trim();
  if (value.isEmpty || !BlogUrlPolicy.isSafe(value)) return;
  if (value.startsWith('/') && newTab && kIsWeb) {
    await launchUrl(Uri.base.resolve(value), webOnlyWindowName: '_blank');
    return;
  }
  if (value.startsWith('/') && newTab) {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      unawaited(router.push(value));
    } else {
      unawaited(Navigator.of(context).pushNamed(value));
    }
    return;
  }
  if (value.startsWith('/')) {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.go(value);
    } else {
      Navigator.of(context).pushNamed(value);
    }
    return;
  }
  final uri = Uri.tryParse(value);
  if (uri == null) return;
  await launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
    webOnlyWindowName: '_blank',
  );
}

class BlogInlineText extends StatefulWidget {
  const BlogInlineText(
    this.source, {
    super.key,
    required this.style,
    this.textAlign,
  });

  final String source;
  final TextStyle style;
  final TextAlign? textAlign;

  @override
  State<BlogInlineText> createState() => _BlogInlineTextState();
}

class _BlogInlineTextState extends State<BlogInlineText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final spans = <InlineSpan>[];
    for (final segment in BlogInlineMarkup.parse(widget.source)) {
      TapGestureRecognizer? recognizer;
      final link = segment.link;
      if (link != null) {
        recognizer = TapGestureRecognizer()
          ..onTap = () => openBlogLink(context, link);
        _recognizers.add(recognizer);
      }
      spans.add(
        TextSpan(
          text: segment.text,
          recognizer: recognizer,
          mouseCursor: link != null ? SystemMouseCursors.click : null,
          style: TextStyle(
            fontWeight: segment.bold ? FontWeight.w700 : null,
            fontStyle: segment.italic ? FontStyle.italic : null,
            color: link != null ? BlogTheme.accent : null,
            decoration: link != null ? TextDecoration.underline : null,
            decorationColor: BlogTheme.accent.withValues(alpha: 0.4),
          ),
        ),
      );
    }
    return SelectableText.rich(
      TextSpan(style: widget.style, children: spans),
      textAlign: widget.textAlign,
    );
  }
}
