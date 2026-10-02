import 'package:flutter/material.dart';

import '../data/blog_repository.dart';
import '../models/blog_models.dart';
import '../widgets/blog_theme.dart';

/// Author profiles. Linking an e-mail grants that user the writer role
/// (create/edit own posts, submit for review) enforced by the blog RPCs.
class BlogAuthorsManager extends StatefulWidget {
  const BlogAuthorsManager({super.key, this.repository});

  final BlogRepository? repository;

  @override
  State<BlogAuthorsManager> createState() => _BlogAuthorsManagerState();
}

class _BlogAuthorsManagerState extends State<BlogAuthorsManager> {
  late final BlogRepository _repo = widget.repository ?? BlogRepository.instance;
  List<BlogAuthor> _authors = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final authors = await _repo.listAuthors();
      if (!mounted) return;
      setState(() {
        _authors = authors;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is BlogException ? error.message : 'Yazarlar yüklenemedi.';
      });
    }
  }

  Future<void> _edit([BlogAuthor? author]) async {
    final name = TextEditingController(text: author?.displayName ?? '');
    final email = TextEditingController(text: author?.userEmail ?? '');
    final bio = TextEditingController(text: author?.bio ?? '');
    final avatar = TextEditingController(text: author?.avatarUrl ?? '');
    var active = author?.isActive ?? true;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(author == null ? 'Yeni yazar' : 'Yazarı düzenle'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Görünen ad'),
                ),
                TextField(
                  controller: email,
                  decoration: const InputDecoration(
                    labelText: 'Kullanıcı e-postası',
                    helperText:
                        'Bu e-postayla giriş yapan kullanıcı kendi yazılarını '
                        'oluşturabilir. Boşsa yalnızca yöneticiler bu yazar adına yazar.',
                    helperMaxLines: 3,
                  ),
                ),
                TextField(
                  controller: bio,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Kısa biyografi'),
                ),
                TextField(
                  controller: avatar,
                  decoration: const InputDecoration(labelText: 'Profil görseli adresi'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Aktif'),
                  subtitle: const Text('Pasif yazar yeni yazı oluşturamaz.'),
                  value: active,
                  onChanged: (value) => setState(() => active = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Kaydet')),
          ],
        ),
      ),
    );
    if (saved == true) {
      try {
        await _repo.saveAuthor(
          id: author?.id,
          displayName: name.text,
          slug: author?.slug,
          bio: bio.text,
          avatarUrl: avatar.text,
          userEmail: email.text,
          isActive: active,
        );
        await _reload();
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFFC62828),
              content: Text(error is BlogException ? error.message : 'Kaydedilemedi.'),
            ),
          );
        }
      }
    }
    for (final c in [name, email, bio, avatar]) {
      c.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            TextButton(onPressed: _reload, child: const Text('Tekrar dene')),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Yazarlar', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: BlogTheme.accent),
              onPressed: () => _edit(),
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Yazar ekle'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_authors.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Henüz yazar yok. Yazı oluşturmak için önce bir yazar ekleyin.'),
          ),
        for (final author in _authors)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: BlogTheme.line),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: BlogTheme.accentSoft,
                child: Text(
                  author.displayName.isEmpty ? '?' : author.displayName.characters.first,
                  style: const TextStyle(color: BlogTheme.accent),
                ),
              ),
              title: Text(author.displayName),
              subtitle: Text(
                [
                  author.userEmail ?? 'Kullanıcıya bağlı değil',
                  '${author.postCount} yazı',
                  if (!author.isActive) 'pasif',
                ].join(' · '),
              ),
              trailing: IconButton(
                tooltip: 'Düzenle',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _edit(author),
              ),
            ),
          ),
      ],
    );
  }
}
