import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../application/visual_search_controller.dart';
import '../domain/visual_search_models.dart';
import 'visual_search_capture_page.dart';
import 'visual_search_chrome.dart';
import 'visual_search_result_pages.dart';
import 'widgets/visual_search_cards.dart';
import 'widgets/visual_search_states.dart';

class VisualSearchHistoryPage extends StatefulWidget {
  const VisualSearchHistoryPage({super.key, this.controller});

  final VisualSearchController? controller;

  @override
  State<VisualSearchHistoryPage> createState() => _VisualSearchHistoryPageState();
}

class _VisualSearchHistoryPageState extends State<VisualSearchHistoryPage> {
  late final VisualSearchController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? VisualSearchController.shared();
    _controller.loadHistory();
  }

  Future<void> _delete(VisualSearchJob job) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kaydı sil'),
        content: const Text('Bu görsel arama geçmişten kaldırılsın mı?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _controller.remove(job.id);
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: visualSearchAppBar(context, 'Geçmiş'),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final jobs = _controller.visibleHistory;
          return VisualSearchPageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final filter in VisualSearchHistoryFilter.values)
                      ChoiceChip(
                        label: Text(_filterLabel(filter)),
                        selected: _controller.filter == filter,
                        selectedColor: AppColors.softPurple,
                        labelStyle: TextStyle(
                          color: _controller.filter == filter
                              ? AppColors.primary
                              : AppColors.textDark,
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected: (_) => _controller.setFilter(filter),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_controller.historyLoading && jobs.isEmpty)
                  const VisualSearchStatePanel(
                    icon: Icons.hourglass_empty,
                    title: 'Geçmiş yükleniyor',
                    message: 'Kayıtlar hazırlanıyor.',
                    busy: true,
                  )
                else if (jobs.isEmpty)
                  VisualSearchStatePanel(
                    icon: Icons.history,
                    title: 'Henüz kayıt yok',
                    message: 'Görsel zeka veya ürün araması yaptığında burada listelenir.',
                    actionLabel: 'Görsel ekle',
                    onAction: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => VisualSearchCapturePage(
                            jobType: VisualSearchJobType.combined,
                            controller: _controller,
                          ),
                        ),
                      );
                    },
                  )
                else if (wide)
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: jobs.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisExtent: 132,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemBuilder: (context, index) => _tile(jobs[index]),
                  )
                else
                  for (final job in jobs) ...[
                    _tile(job),
                    const SizedBox(height: 10),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _tile(VisualSearchJob job) {
    return VisualSearchHistoryTile(
      job: job,
      onDelete: () => _delete(job),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => VisualSearchHistoryDetailPage(
              jobId: job.id,
              controller: _controller,
            ),
          ),
        );
      },
    );
  }

  String _filterLabel(VisualSearchHistoryFilter filter) {
    switch (filter) {
      case VisualSearchHistoryFilter.all:
        return 'Tümü';
      case VisualSearchHistoryFilter.visualSearch:
        return 'Görsel arama';
      case VisualSearchHistoryFilter.intelligence:
        return 'Görsel zeka';
      case VisualSearchHistoryFilter.damage:
        return 'Hasar analizi';
      case VisualSearchHistoryFilter.missingParts:
        return 'Eksik parça';
    }
  }
}
