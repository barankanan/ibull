import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../application/visual_search_controller.dart';
import '../domain/visual_search_models.dart';
import 'visual_search_chrome.dart';
import 'widgets/visual_search_results.dart';
import 'widgets/visual_search_states.dart';

class AnalysisResultPage extends StatelessWidget {
  const AnalysisResultPage({super.key, required this.job, this.controller});

  final VisualSearchJob job;
  final VisualSearchController? controller;

  @override
  Widget build(BuildContext context) {
    final analysis = job.analysis;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: visualSearchAppBar(context, 'Analiz Sonucu'),
      body: VisualSearchPageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (job.isEmptyResult)
              const VisualSearchStatePanel(
                icon: Icons.search_off,
                title: 'Sonuç yok',
                message: 'Hasar veya eksik parça net olarak ayrışmadı.',
              )
            else ...[
              VisualSearchResultSummary(job: job),
              const SizedBox(height: 16),
              VisualSearchMarkOverlay(job: job),
              const SizedBox(height: 16),
              VisualSearchFindingList(
                title: 'Tespit edilen hasarlar',
                children: [
                  for (final damage in analysis?.damages ?? const <DamageDetection>[])
                    VisualSearchFindingTile(
                      title: damage.label,
                      detail: damage.description,
                      confidence: damage.confidence,
                    ),
                ],
              ),
              VisualSearchFindingList(
                title: 'Eksik parçalar',
                children: [
                  for (final part in analysis?.missingParts ?? const <MissingPartDetection>[])
                    VisualSearchFindingTile(
                      title: part.partName,
                      detail: part.details,
                      confidence: part.confidence,
                    ),
                ],
              ),
              if ((analysis?.matches ?? const []).isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text(
                  'İlgili ürünler',
                  style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
                ),
                const SizedBox(height: 8),
                for (final match in analysis!.matches)
                  VisualSearchMatchCard(
                    match: match,
                    onOpen: () => openVisualSearchProduct(context, match),
                  ),
              ],
            ],
            const SizedBox(height: 8),
            VisualSearchFeedbackRow(
              onFeedback: (type) => _feedback(context, type),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _feedback(BuildContext context, String type) async {
    await (controller ?? VisualSearchController.shared()).sendFeedback(job.id, type);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Geri bildirimin kaydedildi.')),
    );
  }
}

class ProductMatchResultPage extends StatelessWidget {
  const ProductMatchResultPage({super.key, required this.job, this.controller});

  final VisualSearchJob job;
  final VisualSearchController? controller;

  @override
  Widget build(BuildContext context) {
    final matches = job.analysis?.matches ?? const <ProductMatch>[];
    final exact = matches.where((item) => item.matchType == ProductMatchType.exact);
    final similar = matches.where((item) => item.matchType != ProductMatchType.exact);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: visualSearchAppBar(context, 'Ürün Eşleşme Sonucu'),
      body: VisualSearchPageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            VisualSearchResultSummary(job: job),
            const SizedBox(height: 16),
            if (matches.isEmpty)
              const VisualSearchStatePanel(
                icon: Icons.search_off,
                title: 'Eşleşme yok',
                message: 'Katalogda bu görsele yakın ürün bulunamadı.',
              )
            else ...[
              if (exact.isNotEmpty) ...[
                const Text(
                  'Eşleşen ürünler',
                  style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
                ),
                const SizedBox(height: 8),
                for (final match in exact) _card(context, match),
              ],
              if (similar.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text(
                  'Benzer ürünler',
                  style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
                ),
                const SizedBox(height: 8),
                for (final match in similar) _card(context, match),
              ],
            ],
            VisualSearchFeedbackRow(
              onFeedback: (type) => _feedback(context, type),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(BuildContext context, ProductMatch match) {
    return VisualSearchMatchCard(
      match: match,
      onOpen: () => openVisualSearchProduct(context, match),
    );
  }

  Future<void> _feedback(BuildContext context, String type) async {
    await (controller ?? VisualSearchController.shared()).sendFeedback(job.id, type);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Geri bildirimin kaydedildi.')),
    );
  }
}

class VisualSearchHistoryDetailPage extends StatefulWidget {
  const VisualSearchHistoryDetailPage({
    super.key,
    required this.jobId,
    this.controller,
  });

  final String jobId;
  final VisualSearchController? controller;

  @override
  State<VisualSearchHistoryDetailPage> createState() =>
      _VisualSearchHistoryDetailPageState();
}

class _VisualSearchHistoryDetailPageState extends State<VisualSearchHistoryDetailPage> {
  late final VisualSearchController _controller;
  VisualSearchJob? _job;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? VisualSearchController.shared();
    _load();
  }

  Future<void> _load() async {
    final job = await _controller.findJob(widget.jobId);
    if (!mounted) return;
    setState(() {
      _job = job;
      _loading = false;
    });
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kaydı sil'),
        content: const Text('Bu görsel arama geçmişten kaldırılsın mı?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sil')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _controller.remove(widget.jobId);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _again() async {
    final bytes = _controller.imageBytesFor(widget.jobId);
    final job = _job;
    if (bytes == null || job == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Görsel bu oturumda yok. Yeni bir fotoğraf seçin.'),
        ),
      );
      return;
    }
    final next = await _controller.analyze(
      type: job.jobType,
      bytes: bytes,
      fileName: job.fileName,
    );
    if (!mounted || next == null) return;
    final page = next.isProductSearch
        ? ProductMatchResultPage(job: next, controller: _controller)
        : AnalysisResultPage(job: next, controller: _controller);
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final job = _job;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: visualSearchAppBar(context, 'Geçmiş Detay'),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : job == null
          ? const VisualSearchPageBody(
              child: VisualSearchStatePanel(
                icon: Icons.history_toggle_off,
                title: 'Kayıt bulunamadı',
                message: 'Bu analiz silinmiş veya bu cihazda yok.',
              ),
            )
          : VisualSearchPageBody(child: _detailBody(context, job)),
      bottomNavigationBar: job == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _delete,
                        child: const Text('Kaydı sil'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: _again,
                        style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                        child: const Text('Yeniden analiz et'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _detailBody(BuildContext context, VisualSearchJob job) {
    final analysis = job.analysis;
    if (job.isProductSearch) {
      final matches = analysis?.matches ?? const <ProductMatch>[];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VisualSearchResultSummary(job: job),
          const SizedBox(height: 12),
          if (matches.isEmpty)
            const Text('Eşleşen ürün yok.', style: TextStyle(color: AppColors.textGrey))
          else
            for (final match in matches)
              VisualSearchMatchCard(
                match: match,
                onOpen: () => openVisualSearchProduct(context, match),
              ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        VisualSearchResultSummary(job: job),
        const SizedBox(height: 12),
        VisualSearchMarkOverlay(job: job),
        const SizedBox(height: 12),
        VisualSearchFindingList(
          title: 'Tespit edilen hasarlar',
          children: [
            for (final damage in analysis?.damages ?? const <DamageDetection>[])
              VisualSearchFindingTile(
                title: damage.label,
                detail: damage.description,
                confidence: damage.confidence,
              ),
          ],
        ),
        VisualSearchFindingList(
          title: 'Eksik parçalar',
          children: [
            for (final part in analysis?.missingParts ?? const <MissingPartDetection>[])
              VisualSearchFindingTile(
                title: part.partName,
                detail: part.details,
                confidence: part.confidence,
              ),
          ],
        ),
      ],
    );
  }
}
