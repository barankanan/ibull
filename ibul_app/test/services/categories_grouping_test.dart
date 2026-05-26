// Tests for the client-side grouping logic introduced in F-04.
//
// getCategoriesWithSubs now fetches sub-categories in a single query and groups
// them by parent_id on the client. This file verifies that the grouping
// algorithm produces the same structure that the old N+1 approach produced.
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/models/db_category.dart';

void main() {
  // Pure grouping helper — mirrors the logic inside getCategoriesWithSubs.
  List<CategoryWithSubcategories> groupSubsUnderMains({
    required List<DBCategory> mainCategories,
    required List<DBCategory> allSubs,
  }) {
    final subsByParentId = <int, List<DBCategory>>{};
    for (final sub in allSubs) {
      if (sub.parentId != null) {
        subsByParentId.putIfAbsent(sub.parentId!, () => []).add(sub);
      }
    }

    return mainCategories
        .where((cat) => cat.id != null)
        .map(
          (mainCat) => CategoryWithSubcategories(
            mainCategory: mainCat,
            subCategories: subsByParentId[mainCat.id] ?? const [],
          ),
        )
        .toList(growable: false);
  }

  DBCategory makeCategory({
    required int id,
    required String name,
    int? parentId,
    int orderIndex = 0,
  }) {
    return DBCategory(
      id: id,
      name: name,
      iconName: null,
      imageUrl: null,
      orderIndex: orderIndex,
      parentId: parentId,
      isActive: true,
    );
  }

  group('getCategoriesWithSubs grouping (F-04)', () {
    test('each sub-category ends up under the correct parent', () {
      final mains = [
        makeCategory(id: 1, name: 'İçecekler'),
        makeCategory(id: 2, name: 'Yemekler'),
      ];
      final subs = [
        makeCategory(id: 10, name: 'Soğuk İçecekler', parentId: 1),
        makeCategory(id: 11, name: 'Sıcak İçecekler', parentId: 1),
        makeCategory(id: 20, name: 'Izgara', parentId: 2),
      ];

      final result = groupSubsUnderMains(mainCategories: mains, allSubs: subs);

      expect(result.length, 2);

      final icecekler = result.firstWhere((r) => r.mainCategory.id == 1);
      expect(icecekler.subCategories.map((s) => s.id), containsAll([10, 11]));

      final yemekler = result.firstWhere((r) => r.mainCategory.id == 2);
      expect(yemekler.subCategories.map((s) => s.id), containsAll([20]));
    });

    test('main category with no subs gets empty list, not null', () {
      final mains = [makeCategory(id: 3, name: 'Tatlılar')];
      final subs = <DBCategory>[];

      final result = groupSubsUnderMains(mainCategories: mains, allSubs: subs);

      expect(result.single.subCategories, isEmpty);
    });

    test('orphaned sub-categories (unknown parent_id) are silently ignored', () {
      final mains = [makeCategory(id: 1, name: 'İçecekler')];
      final subs = [
        makeCategory(id: 10, name: 'Soğuk', parentId: 1),
        makeCategory(id: 99, name: 'Sahipsiz', parentId: 999),
      ];

      final result = groupSubsUnderMains(mainCategories: mains, allSubs: subs);

      expect(result.single.subCategories.length, 1);
      expect(result.single.subCategories.first.id, 10);
    });

    test('empty mains returns empty result', () {
      final result = groupSubsUnderMains(
        mainCategories: [],
        allSubs: [makeCategory(id: 1, name: 'Orphan', parentId: 5)],
      );

      expect(result, isEmpty);
    });
  });
}
