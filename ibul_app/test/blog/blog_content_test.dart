import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/blog/blog_paths.dart';
import 'package:ibul_app/features/blog/models/blog_content.dart';
import 'package:ibul_app/features/blog/models/blog_post_draft.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> sampleContent() => {
  'version': 1,
  'blocks': [
    {'id': 'h1', 'type': 'heading', 'level': 2, 'text': 'Giriş'},
    {'id': 'p1', 'type': 'paragraph', 'text': 'Bu **kalın** [link](https://ibul.com.tr)'},
    {'id': 'i1', 'type': 'image', 'url': 'https://x.supabase.co/a.jpg', 'alt': 'Kapak', 'caption': ''},
    {'id': 'v1', 'type': 'video', 'source': 'youtube', 'url': 'https://youtu.be/dQw4w9WgXcQ'},
    {'id': 'b1', 'type': 'button', 'label': 'Al', 'url': '/kategori/1/2'},
    {
      'id': 'c1',
      'type': 'columns',
      'columns': [
        {'blocks': [{'id': 'cp', 'type': 'paragraph', 'text': 'Sol'}]},
        {
          'blocks': [
            {'id': 'cl', 'type': 'list', 'ordered': true, 'items': ['bir', 'iki']},
            {'id': 'nested', 'type': 'columns', 'columns': []},
          ],
        },
      ],
    },
    {'id': 'd1', 'type': 'divider'},
  ],
};

void main() {
  group('BlogDocument', () {
    test('round-trips block order and drops nested column sections', () {
      final doc = BlogDocument.fromJson(sampleContent());
      expect(doc.blocks.map((b) => b.id), ['h1', 'p1', 'i1', 'v1', 'b1', 'c1', 'd1']);
      expect(doc.blocks[5].columns[1].blocks.map((b) => b.id), ['cl']);
      final again = BlogDocument.fromJson(doc.toJson());
      expect(again.toJson(), doc.toJson());
      expect(again.validate(), isNull);
      expect(doc.plainText, contains('kalın link'));
      expect(doc.plainText, contains('bir iki'));
    });

    test('rejects unsafe urls, missing alt text and foreign video hosts', () {
      BlogDocument one(Map<String, dynamic> block) =>
          BlogDocument.fromJson({'version': 1, 'blocks': [block]});
      expect(one({'id': 'x', 'type': 'button', 'label': 'a', 'url': 'javascript:alert(1)'}).validate(), isNotNull);
      expect(one({'id': 'x', 'type': 'button', 'label': 'a', 'url': '//evil.com'}).validate(), isNotNull);
      expect(one({'id': 'x', 'type': 'paragraph', 'text': '[a](javascript:x)'}).validate(), isNotNull);
      expect(one({'id': 'x', 'type': 'image', 'url': 'https://a/b.jpg', 'alt': ''}).validate(), isNotNull);
      expect(one({'id': 'x', 'type': 'video', 'source': 'youtube', 'url': 'https://evil.com/v'}).validate(), isNotNull);
      expect(BlogDocument.fromJson({'blocks': [{'id': 'x', 'type': 'script'}]}).blocks, isEmpty);
    });

    test('inline markup never links unsafe targets', () {
      final segments = BlogInlineMarkup.parse('a **b** *c* [d](javascript:x) [e](/blog)');
      expect(segments.where((s) => s.text == 'b').single.bold, isTrue);
      expect(segments.where((s) => s.text == 'c').single.italic, isTrue);
      expect(segments.where((s) => s.text == 'd').single.link, isNull);
      expect(segments.where((s) => s.text == 'e').single.link, '/blog');
    });

    test('video links resolve only YouTube and Vimeo', () {
      expect(BlogVideoLink.parse('https://www.youtube.com/watch?v=dQw4w9WgXcQ')?.videoId, 'dQw4w9WgXcQ');
      expect(BlogVideoLink.parse('https://vimeo.com/123456789')?.source, BlogVideoSource.vimeo);
      expect(BlogVideoLink.parse('https://youtube.com.evil.com/watch?v=dQw4w9WgXcQ'), isNull);
    });
  });

  group('BlogPaths', () {
    test('slugify folds Turkish letters like the SQL helper', () {
      expect(BlogPaths.slugify('İstanbul Çocuk Ürünleri Şöleni!'), 'istanbul-cocuk-urunleri-soleni');
      expect(BlogPaths.slugify('  --  '), '');
    });

    test('parses blog paths', () {
      expect(BlogPaths.isBlogPath('/blog'), isTrue);
      expect(BlogPaths.isBlogPath('/bloglar'), isFalse);
      expect(BlogPaths.slugFrom('/blog/ilk-yazi'), 'ilk-yazi');
      expect(BlogPaths.slugFrom('/blog/yazar'), isNull);
      expect(BlogPaths.previewIdFrom('/blog/onizleme/abc'), 'abc');
      expect(BlogPaths.home(search: 'çay', categorySlug: 'teknoloji'), '/blog?q=%C3%A7ay&kategori=teknoloji');
    });

    test('route table and go_router register blog routes', () {
      final table = File('lib/app/app_route_table.dart').readAsStringSync();
      final router = File('lib/app/ibul_go_router.dart').readAsStringSync();
      expect(table, contains('deferred as blog_pages'));
      expect(table, contains('BlogPaths.isBlogPath'));
      expect(router, contains(r"'${BlogPaths.root}/:slug'"));
    });
  });

  group('BlogPostDraft', () {
    test('payload carries the block document and derived slug', () {
      final draft = BlogPostDraft(title: 'Yeni Ürün Rehberi', document: BlogDocument.fromJson(sampleContent()));
      final payload = draft.toPayload();
      expect(payload['slug'], 'yeni-urun-rehberi');
      expect((payload['content'] as Map)['version'], 1);
      expect(draft.validate(), isNull);
      expect((draft..coverUrl = 'https://a/b.jpg').validate(), contains('alternatif'));
    });

    test('local backup survives and restores', () async {
      SharedPreferences.setMockInitialValues({});
      final draft = BlogPostDraft(title: 'Yedek', document: BlogDocument.fromJson(sampleContent()));
      await draft.writeBackup();
      final restored = await BlogPostDraft.readBackup(null);
      expect(restored?.draft.fingerprint, draft.fingerprint);
      await BlogPostDraft.clearBackup(null);
      expect(await BlogPostDraft.readBackup(null), isNull);
    });
  });
}
