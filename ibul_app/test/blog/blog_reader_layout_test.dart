import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/blog/screens/blog_home_page.dart';
import 'package:ibul_app/features/blog/screens/blog_post_page.dart';
import 'package:ibul_app/features/blog/widgets/blog_post_card.dart';

import 'fake_blog_repository.dart';

Map<String, dynamic> _row(int i, {List<Map<String, dynamic>>? blocks}) => {
  'id': 'p$i',
  'slug': 'yazi-$i',
  'title': 'Yazı $i ${'uzunkelime' * 6}',
  'excerpt': 'Özet $i',
  'status': 'published',
  'category_id': 'c1',
  'is_featured': i == 0,
  'cover_url': 'https://x.supabase.co/c$i.jpg',
  'cover_alt': 'Kapak $i',
  'published_at': '2026-10-0${(i % 9) + 1}T10:00:00Z',
  'content': {
    'version': 1,
    'blocks': blocks ?? [
      {'id': 'p', 'type': 'paragraph', 'text': 'Metin $i'},
    ],
  },
};

final _richBlocks = <Map<String, dynamic>>[
  for (var h = 0; h < 3; h++) {'id': 'h$h', 'type': 'heading', 'level': 2, 'text': 'Bölüm $h'},
  {'id': 'p', 'type': 'paragraph', 'text': '${'çokuzunbirkelime' * 8} **kalın** [bağlantı](/blog)'},
  {'id': 'i', 'type': 'image', 'url': 'https://x.supabase.co/a.jpg', 'alt': 'Görsel', 'caption': 'Açıklama'},
  {'id': 'v', 'type': 'video', 'source': 'youtube', 'url': 'https://youtu.be/dQw4w9WgXcQ'},
  {'id': 'b', 'type': 'button', 'label': 'Çok uzun bir buton metni ' * 3, 'url': '/kategori/1/2'},
  {
    'id': 'c',
    'type': 'columns',
    'columns': [
      for (var c = 0; c < 4; c++)
        {
          'blocks': [
            {'id': 'ci$c', 'type': 'image', 'url': 'https://x.supabase.co/$c.jpg', 'alt': 'S$c'},
            {'id': 'cp$c', 'type': 'paragraph', 'text': 'Sütun $c ${'metin' * 10}'},
          ],
        },
    ],
  },
];

FakeBlogRepository _repo(int count) {
  final repo = FakeBlogRepository();
  for (var i = 0; i < count; i++) {
    repo.rows['p$i'] = _row(i, blocks: i == 1 ? _richBlocks : null);
  }
  return repo;
}

void _size(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  for (var i = 0; i < 30 && target.evaluate().isEmpty; i++) {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(target.first);
  await tester.pumpAndSettle();
}

void main() {
  for (final width in [390.0, 820.0, 1440.0]) {
    testWidgets('home grid and article fit at ${width.toInt()}px', (tester) async {
      _size(tester, width);
      final repo = _repo(7);
      await tester.pumpWidget(MaterialApp(home: BlogHomePage(repository: repo)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('İBUL Blog'), findsWidgets);
      expect(find.byType(BlogFeaturedCard), findsOneWidget);
      final cards = find.byType(BlogPostCard);
      await _scrollTo(tester, cards);
      expect(cards, findsWidgets);
      final rowY = tester.getTopLeft(cards.first).dy;
      final perRow = cards.evaluate().where((e) => tester.getTopLeft(find.byWidget(e.widget)).dy == rowY).length;
      expect(perRow, width >= 1000 ? 3 : (width >= 640 ? 2 : 1));

      await tester.pumpWidget(MaterialApp(home: BlogPostPage(slug: 'yazi-1', repository: repo)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('İçindekiler'), findsOneWidget);
      expect(find.text('Tüm blog yazıları'), findsWidgets);
      await _scrollTo(tester, find.textContaining('Sütun 0'));
      final s0 = tester.getTopLeft(find.textContaining('Sütun 0'));
      final s1 = tester.getTopLeft(find.textContaining('Sütun 1'));
      if (width < 1000) {
        expect(s1.dy, greaterThan(s0.dy), reason: 'columns stack on narrow screens');
      } else {
        expect(s1.dy, s0.dy);
      }
    });
  }

  testWidgets('unknown or unpublished slug shows not found', (tester) async {
    _size(tester, 390);
    final repo = _repo(2)..rows['p1']!['status'] = 'draft';
    await tester.pumpWidget(MaterialApp(home: BlogPostPage(slug: 'yazi-1', repository: repo)));
    await tester.pumpAndSettle();
    expect(find.text('Yazı bulunamadı'), findsOneWidget);
  });

  testWidgets('empty and error states', (tester) async {
    _size(tester, 390);
    await tester.pumpWidget(MaterialApp(home: BlogHomePage(repository: _repo(0))));
    await tester.pumpAndSettle();
    expect(find.text('Henüz yazı yok'), findsOneWidget);

    await tester.pumpWidget(MaterialApp(
      key: UniqueKey(),
      home: BlogHomePage(initialSearch: 'yok', repository: _repo(3)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Sonuç bulunamadı'), findsOneWidget);

    await tester.pumpWidget(MaterialApp(
      key: UniqueKey(),
      home: BlogHomePage(repository: _repo(3)..failLists = true),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Yazılar yüklenemedi'), findsOneWidget);
  });
}
