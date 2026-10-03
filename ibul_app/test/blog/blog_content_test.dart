import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/blog/blog_paths.dart';
import 'package:ibul_app/features/blog/editor/blog_block_ops.dart';
import 'package:ibul_app/features/blog/models/blog_content.dart';
import 'package:ibul_app/features/blog/models/blog_image_frame.dart';
import 'package:ibul_app/features/blog/models/blog_post_draft.dart';
import 'package:ibul_app/features/blog/models/blog_models.dart';
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
      expect(one({'id': 'x', 'type': 'image', 'url': 'https://a/b.jpg', 'alt': ''}).validate(), isNull);
      expect(one({'id': 'x', 'type': 'image', 'url': 'https://a/b.jpg', 'alt': ''}).validate(publishing: true), isNotNull);
      expect(one({'id': 'x', 'type': 'video', 'source': 'youtube', 'url': 'https://evil.com/v'}).validate(publishing: true), isNotNull);
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

  group('BlogAccess', () {
    test('reads the admin flag and does not treat a bad payload as denial', () {
      expect(
        BlogAccess.fromJson({'is_admin': true, 'author_id': null}).isAdmin,
        isTrue,
      );
      expect(
        BlogAccess.fromJson('{"is_admin":"true","author_name":"Ada"}').canWrite,
        isTrue,
      );
      expect(
        BlogAccess.fromJson({'is_admin': false, 'author_id': 'a1'}).canWrite,
        isTrue,
      );
      expect(() => BlogAccess.fromJson('nope'), throwsFormatException);
      expect(BlogAccess.none.canWrite, isFalse);
    });
  });

  group('block editing', () {
    test('list and paragraph keep line order both ways', () {
      final list = BlogBlock(
        id: 'l',
        type: BlogBlockType.list,
        items: ['**bir**', 'iki [bağ](/blog)'],
      );
      final paragraph = convertBlock(list, BlogBlockType.paragraph);
      expect(paragraph.text, '**bir**\niki [bağ](/blog)');
      final back = convertBlock(paragraph, BlogBlockType.list);
      expect(back.items, ['**bir**', 'iki [bağ](/blog)']);
      expect(back.id, 'l');
    });

    test('shrinking columns keeps every block', () {
      final section = BlogBlock.create(BlogBlockType.columns, columnCount: 3);
      section.columns[0].blocks.add(BlogBlock(id: 'a', type: BlogBlockType.paragraph, text: 'A'));
      section.columns[2].blocks.add(BlogBlock(id: 'c', type: BlogBlockType.image, url: 'https://x/a.jpg', alt: 'A'));
      final removed = section.columns.removeLast();
      section.columns.last.blocks.addAll(removed.blocks);
      final texts = section.columns.expand((c) => c.blocks).map((b) => b.id);
      expect(texts, containsAll(['a', 'c']));
      expect(section.columns, hasLength(2));
    });

    test('image crop metadata round-trips and legacy images stay plain', () {
      final frame = const BlogImageFrame(x: 0.1, y: 0.2, w: 0.5, h: 0.4, aspect: 1.6, fit: 'cover');
      final again = BlogImageFrame.fromJson(frame.toJson());
      expect(again.x, 0.1);
      expect(again.fit, 'cover');
      expect(again.aspect, 1.6);
      final legacy = BlogBlock.fromJson({
        'id': 'i',
        'type': 'image',
        'url': 'https://x/a.jpg',
        'alt': 'Eski',
      })!;
      expect(legacy.frame.isLegacy, isTrue);
      expect(legacy.toJson().containsKey('crop'), isFalse);
    });

    test('a locked ratio stays inside the image', () {
      final frame = const BlogImageFrame(x: 0, y: 0, w: 1, h: 1)
          .withRatio(16 / 9, imageAspect: 1);
      expect(frame.w, lessThanOrEqualTo(1));
      expect(frame.h, lessThanOrEqualTo(1));
      expect(frame.aspect, closeTo(16 / 9, 0.02));
    });

    test('a draft can be saved before a title or author is chosen', () {
      final draft = BlogPostDraft(document: BlogDocument());
      expect(draft.validate(), isNull);
      expect(draft.validate(publishing: true), contains('başlık'));
      draft.title = 'Yayın';
      expect(draft.validate(publishing: true), contains('yazar'));
    });
  });

  group('BlogPostDraft', () {
    test('payload carries the block document and derived slug', () {
      final draft = BlogPostDraft(title: 'Yeni Ürün Rehberi', document: BlogDocument.fromJson(sampleContent()));
      final payload = draft.toPayload();
      expect(payload['slug'], 'yeni-urun-rehberi');
      expect((payload['content'] as Map)['version'], 1);
      expect(draft.validate(), isNull);
      draft.authorId = 'a1';
      expect((draft..coverUrl = 'https://a/b.jpg').validate(publishing: true), contains('alternatif'));
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
