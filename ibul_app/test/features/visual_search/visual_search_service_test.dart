import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/visual_search/application/visual_search_controller.dart';
import 'package:ibul_app/features/visual_search/application/visual_search_service.dart';
import 'package:ibul_app/features/visual_search/data/mock_visual_search_analyzer.dart';
import 'package:ibul_app/features/visual_search/data/visual_search_repository.dart';
import 'package:ibul_app/features/visual_search/domain/visual_catalog_matcher.dart';
import 'package:ibul_app/features/visual_search/domain/visual_search_models.dart';

void main() {
  VisualSearchService buildService(MemoryVisualSearchRepository repository) {
    return VisualSearchService(
      repository: repository,
      analyzer: const MockVisualSearchAnalyzer(),
    );
  }

  test('cracked mug analysis marks damage and a missing part', () async {
    final repository = MemoryVisualSearchRepository();
    final job = await buildService(repository).submit(
      type: VisualSearchJobType.combined,
      bytes: Uint8List.fromList([1, 2, 3, 4]),
      fileName: 'catlak-kupa.jpg',
    );

    expect(job.status, VisualSearchJobStatus.completed);
    expect(job.analysis!.damages, isNotEmpty);
    expect(job.analysis!.missingParts.single.partName, 'Kulp parçası');
    expect(job.analysis!.confidence, greaterThan(0.8));
    expect(job.isEmptyResult, isFalse);
    final stored = await repository.getJob(job.id);
    expect(stored?.analysis?.summary, contains('kupa'));
  });

  test('missing chair leg and shoe search use distinct scenarios', () async {
    final service = buildService(MemoryVisualSearchRepository());
    final chair = await service.submit(
      type: VisualSearchJobType.combined,
      bytes: Uint8List.fromList([9, 9, 9]),
      fileName: 'sandalye.png',
    );
    final shoes = await service.submit(
      type: VisualSearchJobType.visualSearch,
      bytes: Uint8List.fromList([4, 5, 6]),
      fileName: 'kosu-ayakkabi.jpg',
    );

    expect(chair.analysis!.missingParts.single.partName, 'Ön sol ayak');
    expect(shoes.isProductSearch, isTrue);
    expect(shoes.analysis!.matches.first.name, contains('Ayakkabı'));
    expect(shoes.analysis!.matches.first.price, isNotEmpty);
    expect(shoes.analysis!.matches.first.store, isNotEmpty);
  });

  test('empty filename scenario stays on the empty result path', () async {
    final job = await buildService(MemoryVisualSearchRepository()).submit(
      type: VisualSearchJobType.visualSearch,
      bytes: Uint8List.fromList([1]),
      fileName: 'bos-sonuc.jpg',
    );

    expect(job.isEmptyResult, isTrue);
    expect(job.analysis!.matches, isEmpty);
  });

  test('rejects unsupported and oversized files before saving history', () async {
    final repository = MemoryVisualSearchRepository();
    final service = buildService(repository);

    await expectLater(
      service.submit(
        type: VisualSearchJobType.visualSearch,
        bytes: Uint8List.fromList([1, 2]),
        fileName: 'notlar.txt',
      ),
      throwsA(
        isA<VisualSearchException>().having(
          (error) => error.code,
          'code',
          VisualSearchErrorCode.unsupportedType,
        ),
      ),
    );
    await expectLater(
      service.submit(
        type: VisualSearchJobType.visualSearch,
        bytes: Uint8List(VisualSearchService.maxBytes + 1),
        fileName: 'buyuk.jpg',
      ),
      throwsA(
        isA<VisualSearchException>().having(
          (error) => error.code,
          'code',
          VisualSearchErrorCode.fileTooLarge,
        ),
      ),
    );
    expect(await repository.listJobs(), isEmpty);
  });

  test('history filter and delete keep the local record set', () async {
    final repository = MemoryVisualSearchRepository();
    final service = buildService(repository);
    await service.submit(
      type: VisualSearchJobType.visualSearch,
      bytes: Uint8List.fromList([1]),
      fileName: 'ayakkabi.jpg',
    );
    final analysis = await service.submit(
      type: VisualSearchJobType.combined,
      bytes: Uint8List.fromList([2]),
      fileName: 'kupa.jpg',
    );
    final jobs = await service.history();
    expect(
      filterVisualSearchHistory(jobs, VisualSearchHistoryFilter.intelligence),
      hasLength(1),
    );
    await service.delete(analysis.id);
    expect(await service.history(), hasLength(1));
  });

  test('catalog matcher prefers the shoe over a mug', () {
    const matcher = VisualCatalogMatcher();
    final matches = matcher.match(
      hint: 'kosu ayakkabi',
      catalog: MockVisualSearchAnalyzer.demoCatalog,
    );
    expect(matches.first.category, 'Ayakkabı');
    expect(matches.first.similarityScore, greaterThan(0));
  });

  test('controller reaches success and can remove the job', () async {
    final controller = VisualSearchController(
      service: buildService(MemoryVisualSearchRepository()),
      userId: 'user-1',
    );
    final job = await controller.analyze(
      type: VisualSearchJobType.combined,
      bytes: Uint8List.fromList([7, 7]),
      fileName: 'fincan.jpg',
    );

    expect(controller.phase, VisualSearchPhase.success);
    expect(job, isNotNull);
    expect(controller.history, hasLength(1));
    expect(controller.imageBytesFor(job!.id), isNotNull);
    await controller.remove(job.id);
    expect(controller.history, isEmpty);
  });

  test('analysis json survives a round trip', () async {
    final job = await buildService(MemoryVisualSearchRepository()).submit(
      type: VisualSearchJobType.combined,
      bytes: Uint8List.fromList([3]),
      fileName: 'kupa.jpg',
    );
    final restored = VisualSearchJob.fromJson(job.toJson());
    expect(restored.jobType, VisualSearchJobType.combined);
    expect(restored.analysis!.damages.first.label, 'Gövde çatlağı');
    expect(restored.analysis!.damages.first.bbox.width, greaterThan(0));
  });
}
