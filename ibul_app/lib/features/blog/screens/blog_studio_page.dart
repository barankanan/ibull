import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/web_boot_loader.dart';
import '../../../core/web_seo.dart';
import '../admin/blog_admin_section.dart';
import '../blog_paths.dart';
import '../widgets/blog_inline_text.dart';
import '../widgets/blog_theme.dart';

/// `/blog/yazar` — writing desk for authors without admin panel access.
class BlogStudioPage extends StatefulWidget {
  const BlogStudioPage({super.key});

  @override
  State<BlogStudioPage> createState() => _BlogStudioPageState();
}

class _BlogStudioPageState extends State<BlogStudioPage> {
  @override
  void initState() {
    super.initState();
    setSeoMeta(
      title: 'Yazar paneli | İBUL Blog',
      canonicalPath: BlogPaths.studio,
      noIndex: true,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => dismissWebBootLoader());
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = Supabase.instance.client.auth.currentUser != null;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text('İBUL Blog · Yazar paneli'),
        actions: [
          TextButton(
            onPressed: () => openBlogLink(context, BlogPaths.root),
            child: const Text('Bloga git'),
          ),
        ],
      ),
      body: signedIn
          ? const BlogAdminSection(view: BlogAdminView.posts)
          : Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Yazı yazmak için giriş yapın.'),
                  const SizedBox(height: 12),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: BlogTheme.accent),
                    onPressed: () => openBlogLink(
                      context,
                      '/login?next=${Uri.encodeComponent(BlogPaths.studio)}',
                    ),
                    child: const Text('Giriş yap'),
                  ),
                ],
              ),
            ),
    );
  }
}
