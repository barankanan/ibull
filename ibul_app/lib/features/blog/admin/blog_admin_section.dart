import 'package:flutter/material.dart';

import '../data/blog_repository.dart';
import '../models/blog_models.dart';
import 'blog_authors_manager.dart';
import 'blog_posts_manager.dart';
import 'blog_taxonomy_manager.dart';

enum BlogAdminView {
  posts('Blog Yazıları', 'Taslak, inceleme ve yayın akışı'),
  taxonomy('Blog Kategorileri & Etiketler', 'Okuyucu konu menüsü ve etiketler'),
  authors('Blog Yazarları', 'Yazar profilleri ve yazma yetkisi');

  const BlogAdminView(this.title, this.subtitle);

  final String title;
  final String subtitle;
}

/// Admin panel › Blog content area. Also used by the author studio for posts.
class BlogAdminSection extends StatefulWidget {
  const BlogAdminSection({super.key, required this.view, this.repository});

  final BlogAdminView view;
  final BlogRepository? repository;

  @override
  State<BlogAdminSection> createState() => _BlogAdminSectionState();
}

class _BlogAdminSectionState extends State<BlogAdminSection> {
  late final BlogRepository _repo = widget.repository ?? BlogRepository.instance;
  late Future<BlogAccess> _access = _repo.myAccess();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: FutureBuilder<BlogAccess>(
        future: _access,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    snapshot.error is BlogException
                        ? (snapshot.error as BlogException).message
                        : 'Blog yetkisi okunamadı.',
                    textAlign: TextAlign.center,
                  ),
                  TextButton(
                    onPressed: () => setState(() => _access = _repo.myAccess()),
                    child: const Text('Tekrar dene'),
                  ),
                ],
              ),
            );
          }
          final access = snapshot.data!;
          final allowed = widget.view == BlogAdminView.posts
              ? access.canWrite
              : access.isAdmin;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.view.title,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(widget.view.subtitle, style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 20),
                if (!allowed)
                  const Text('Bu bölüm için blog yetkiniz yok.')
                else
                  switch (widget.view) {
                    BlogAdminView.posts => BlogPostsManager(access: access),
                    BlogAdminView.taxonomy => const BlogTaxonomyManager(),
                    BlogAdminView.authors => const BlogAuthorsManager(),
                  },
              ],
            ),
          );
        },
      ),
    );
  }
}
