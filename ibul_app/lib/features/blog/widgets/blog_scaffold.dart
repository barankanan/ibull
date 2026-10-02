import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../core/web_boot_loader.dart';
import '../blog_paths.dart';
import 'blog_inline_text.dart';
import 'blog_theme.dart';

/// Light page chrome shared by blog reader pages.
class BlogScaffold extends StatefulWidget {
  const BlogScaffold({super.key, required this.slivers, this.controller});

  final List<Widget> slivers;
  final ScrollController? controller;

  @override
  State<BlogScaffold> createState() => _BlogScaffoldState();
}

class _BlogScaffoldState extends State<BlogScaffold> {
  @override
  void initState() {
    super.initState();
    // Direct /blog URLs never mount home, which normally removes the loader.
    WidgetsBinding.instance.addPostFrameCallback((_) => dismissWebBootLoader());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BlogTheme.surface,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          controller: widget.controller,
          slivers: [
            const SliverToBoxAdapter(child: _BlogTopBar()),
            ...widget.slivers,
            const SliverToBoxAdapter(child: _BlogFooter()),
          ],
        ),
      ),
    );
  }
}

class _BlogTopBar extends StatelessWidget {
  const _BlogTopBar();

  @override
  Widget build(BuildContext context) {
    final gutter = BlogTheme.gutter(context);
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: BlogTheme.line)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: BlogTheme.pageWidth),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: gutter, vertical: 14),
            child: Row(
              children: [
                InkWell(
                  onTap: () => openBlogLink(context, '/'),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        AppAssets.ibulLogo,
                        width: 30,
                        height: 30,
                        errorBuilder: (_, _, _) => const SizedBox(width: 30),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'İBUL',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 19,
                          color: BlogTheme.ink,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 20,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  color: BlogTheme.line,
                ),
                InkWell(
                  onTap: () => openBlogLink(context, BlogPaths.root),
                  child: const Text(
                    'Blog',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      color: BlogTheme.accent,
                    ),
                  ),
                ),
                const Spacer(),
                if (MediaQuery.sizeOf(context).width >= 480)
                  TextButton(
                    onPressed: () => openBlogLink(context, '/'),
                    style: TextButton.styleFrom(foregroundColor: BlogTheme.body),
                    child: const Text('Alışverişe dön'),
                  )
                else
                  IconButton(
                    tooltip: 'Alışverişe dön',
                    onPressed: () => openBlogLink(context, '/'),
                    color: BlogTheme.body,
                    icon: const Icon(Icons.storefront_outlined),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BlogFooter extends StatelessWidget {
  const _BlogFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 64),
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 18),
      decoration: const BoxDecoration(
        color: Color(0xFFFBFAFE),
        border: Border(top: BorderSide(color: BlogTheme.line)),
      ),
      child: Center(
        child: Wrap(
          spacing: 18,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            Text('© ${DateTime.now().year} İBUL', style: BlogTheme.metaStyle),
            InkWell(
              onTap: () => openBlogLink(context, BlogPaths.root),
              child: const Text('Tüm yazılar', style: BlogTheme.metaStyle),
            ),
            InkWell(
              onTap: () => openBlogLink(context, '/'),
              child: const Text('ibul.com.tr', style: BlogTheme.metaStyle),
            ),
          ],
        ),
      ),
    );
  }
}

/// Loading / empty / error block used across blog pages.
class BlogStateMessage extends StatelessWidget {
  const BlogStateMessage({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 72, horizontal: 24),
      child: Column(
        children: [
          Icon(icon, size: 44, color: BlogTheme.accent),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: BlogTheme.ink,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: BlogTheme.metaStyle.copyWith(fontSize: 15),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                foregroundColor: BlogTheme.accent,
                side: const BorderSide(color: BlogTheme.accent),
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
