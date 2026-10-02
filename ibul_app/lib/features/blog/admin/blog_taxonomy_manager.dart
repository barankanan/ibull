import 'package:flutter/material.dart';

import '../blog_paths.dart';
import '../data/blog_repository.dart';
import '../models/blog_models.dart';
import '../widgets/blog_theme.dart';

/// Blog categories and tags (independent from product categories).
class BlogTaxonomyManager extends StatefulWidget {
  const BlogTaxonomyManager({super.key, this.repository});

  final BlogRepository? repository;

  @override
  State<BlogTaxonomyManager> createState() => _BlogTaxonomyManagerState();
}

class _BlogTaxonomyManagerState extends State<BlogTaxonomyManager> {
  late final BlogRepository _repo = widget.repository ?? BlogRepository.instance;
  List<BlogCategory> _categories = const [];
  List<BlogTag> _tags = const [];
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
      final results = await Future.wait([_repo.listAllCategories(), _repo.listTags()]);
      if (!mounted) return;
      setState(() {
        _categories = results[0] as List<BlogCategory>;
        _tags = results[1] as List<BlogTag>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is BlogException ? error.message : 'Liste yüklenemedi.';
      });
    }
  }

  void _toast(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFFC62828),
        content: Text(error is BlogException ? error.message : 'İşlem başarısız.'),
      ),
    );
  }

  Future<void> _editCategory([BlogCategory? category]) async {
    final name = TextEditingController(text: category?.name ?? '');
    final slug = TextEditingController(text: category?.slug ?? '');
    final description = TextEditingController(text: category?.description ?? '');
    final order = TextEditingController(text: '${category?.sortOrder ?? _categories.length}');
    var active = category?.isActive ?? true;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(category == null ? 'Yeni blog kategorisi' : 'Kategoriyi düzenle'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Ad')),
                TextField(
                  controller: slug,
                  decoration: const InputDecoration(
                    labelText: 'Adres (boşsa addan üretilir)',
                  ),
                ),
                TextField(
                  controller: description,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Açıklama'),
                ),
                TextField(
                  controller: order,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Sıra'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Okuyucu menüsünde göster'),
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
      final slugValue = BlogPaths.slugify(slug.text.trim().isEmpty ? name.text : slug.text);
      if (name.text.trim().isEmpty || slugValue.isEmpty) {
        _toast(const BlogException('Ad zorunludur.'));
      } else {
        try {
          await _repo.saveCategory(
            id: category?.id,
            name: name.text,
            slug: slugValue,
            description: description.text,
            sortOrder: int.tryParse(order.text.trim()) ?? 0,
            isActive: active,
          );
          await _reload();
        } catch (error) {
          _toast(error);
        }
      }
    }
    for (final c in [name, slug, description, order]) {
      c.dispose();
    }
  }

  Future<void> _editTag([BlogTag? tag]) async {
    final name = TextEditingController(text: tag?.name ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tag == null ? 'Yeni etiket' : 'Etiketi düzenle'),
        content: TextField(
          controller: name,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Etiket'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () => Navigator.pop(context, name.text),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    name.dispose();
    if (value == null || BlogPaths.slugify(value).isEmpty) return;
    try {
      await _repo.saveTag(id: tag?.id, name: value, slug: BlogPaths.slugify(value));
      await _reload();
    } catch (error) {
      _toast(error);
    }
  }

  Future<void> _deleteTag(BlogTag tag) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Etiket silinsin mi?'),
        content: Text('"${tag.name}" etiketi yazılardan da kaldırılır.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sil')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.deleteTag(tag.id);
      await _reload();
    } catch (error) {
      _toast(error);
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
              child: Text('Kategoriler', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: BlogTheme.accent),
              onPressed: () => _editCategory(),
              icon: const Icon(Icons.add),
              label: const Text('Kategori ekle'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Blog kategorileri ürün kategorilerinden bağımsızdır.',
          style: BlogTheme.metaStyle,
        ),
        const SizedBox(height: 12),
        if (_categories.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Henüz blog kategorisi yok.'),
          ),
        for (final category in _categories)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: BlogTheme.line),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ListTile(
              title: Text(category.name),
              subtitle: Text(
                '/blog?kategori=${category.slug} · sıra ${category.sortOrder}'
                '${category.isActive ? '' : ' · gizli'}',
              ),
              trailing: IconButton(
                tooltip: 'Düzenle',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _editCategory(category),
              ),
            ),
          ),
        const SizedBox(height: 28),
        Row(
          children: [
            const Expanded(
              child: Text('Etiketler', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ),
            OutlinedButton.icon(
              onPressed: () => _editTag(),
              icon: const Icon(Icons.add),
              label: const Text('Etiket ekle'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (_tags.isEmpty) const Text('Henüz etiket yok.'),
            for (final tag in _tags)
              InputChip(
                label: Text(tag.name),
                onPressed: () => _editTag(tag),
                onDeleted: () => _deleteTag(tag),
              ),
          ],
        ),
      ],
    );
  }
}
