import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/blog/editor/blog_editor_page.dart';
import 'package:ibul_app/features/blog/models/blog_content.dart';
import 'package:ibul_app/features/blog/models/blog_models.dart';
import 'package:ibul_app/features/blog/models/blog_post_draft.dart';
import 'package:ibul_app/features/blog/screens/blog_home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_blog_repository.dart';

const _author = BlogAccess(isAdmin: false, authorId: 'a1', authorName: 'Yazar Bir');
const _admin = BlogAccess(isAdmin: true);

Future<void> _pumpEditor(
  WidgetTester tester,
  FakeBlogRepository repo,
  BlogAccess access, {
  String? postId,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      home: BlogEditorPage(access: access, postId: postId, repository: repo),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _addBlock(WidgetTester tester, String label) async {
  await tester.tap(find.byTooltip('Blok ekle').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String fieldText, String value) async {
  final field = find.widgetWithText(TextField, fieldText).last;
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await tester.pump();
}

Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).last);
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('author drafts, reopens and submits; admin previews and publishes', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeBlogRepository();

    await _pumpEditor(tester, repo, _author);
    await _enter(tester, 'Başlık', 'Kış Alışveriş Rehberi');
    await _addBlock(tester, 'Paragraf');
    await _enter(tester, 'Yazmaya başlayın…', 'Sıcak tutan **montlar** burada.');
    await _addBlock(tester, 'Görsel');
    await _enter(tester, 'Görsel adresi', 'https://x.supabase.co/storage/v1/object/public/blog-media/a.jpg');
    await _enter(tester, 'Alternatif metin (zorunlu)', 'Mont vitrini');
    await _addBlock(tester, 'Video');
    await _tapText(tester, 'YouTube / Vimeo');
    await _enter(tester, 'YouTube veya Vimeo bağlantısı', 'https://youtu.be/dQw4w9WgXcQ');
    await _addBlock(tester, 'Buton');
    await _enter(tester, 'Buton metni', 'Montlara göz at');
    await _enter(tester, 'Hedef bağlantı', '/kategori/1/2');
    await _addBlock(tester, '3 sütunlu bölüm');

    expect(find.textContaining('kaydedilmedi'), findsOneWidget);
    await _tapText(tester, 'Taslağı kaydet');
    expect(find.text('Taslak kaydedildi.'), findsOneWidget);
    expect(repo.rows, hasLength(1));
    final id = repo.rows.keys.single;
    final saved = BlogDocument.fromJson(repo.rows[id]!['content']);
    expect(saved.blocks.map((b) => b.type), [
      BlogBlockType.paragraph,
      BlogBlockType.image,
      BlogBlockType.video,
      BlogBlockType.button,
      BlogBlockType.columns,
    ]);
    expect(saved.blocks[2].videoSource, BlogVideoSource.youtube);
    expect(saved.blocks[4].columns, hasLength(3));
    expect(repo.rows[id]!['slug'], 'kis-alisveris-rehberi');
    expect(await BlogPostDraft.readBackup(null), isNull);

    await _pumpEditor(tester, repo, _author, postId: id);
    expect(find.text('Kış Alışveriş Rehberi'), findsWidgets);
    final paragraphY = tester.getTopLeft(find.text('Sıcak tutan **montlar** burada.')).dy;
    final buttonY = tester.getTopLeft(find.text('Montlara göz at')).dy;
    expect(paragraphY, lessThan(buttonY));
    await _tapText(tester, 'İncelemeye gönder');
    expect(repo.rows[id]!['status'], 'in_review');
    expect(find.text('Yayınla'), findsNothing);

    await _pumpEditor(tester, repo, _admin, postId: id);
    await _tapText(tester, 'Önizle');
    expect(find.text('Önizleme — bu görünüm herkese açık değildir.'), findsOneWidget);
    expect(find.text('Montlara göz at'), findsOneWidget);
    await _tapText(tester, 'Düzenle');
    await _tapText(tester, 'Yayınla');
    expect(repo.rows[id]!['status'], 'published');

    repo.rows[id]!['category_id'] = FakeBlogRepository.category.id;
    for (final page in [
      const BlogHomePage(),
      const BlogHomePage(initialCategory: 'teknoloji'),
      const BlogHomePage(initialSearch: 'montlar'),
    ]) {
      await tester.pumpWidget(MaterialApp(key: UniqueKey(), home: BlogHomePage(
        initialSearch: page.initialSearch,
        initialCategory: page.initialCategory,
        repository: repo,
      )));
      await tester.pumpAndSettle();
      expect(find.text('Kış Alışveriş Rehberi'), findsWidgets);
    }
  });

  testWidgets('failed save keeps content and a local backup', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeBlogRepository()..failNextSave = true;

    await _pumpEditor(tester, repo, _author);
    await _enter(tester, 'Başlık', 'Kaybolmasın');
    await _addBlock(tester, 'Paragraf');
    await _enter(tester, 'Yazmaya başlayın…', 'Önemli metin');
    await _tapText(tester, 'Taslağı kaydet');

    expect(find.text('Bağlantı hatası.'), findsOneWidget);
    expect(repo.rows, isEmpty);
    expect(find.text('Önemli metin'), findsOneWidget);
    expect(find.textContaining('kaydedilmedi'), findsOneWidget);
    final backup = await BlogPostDraft.readBackup(null);
    expect(backup?.draft.title, 'Kaybolmasın');
    expect(backup?.draft.document.blocks.single.text, 'Önemli metin');
  });
}
