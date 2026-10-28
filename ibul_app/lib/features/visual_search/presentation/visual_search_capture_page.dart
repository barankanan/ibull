import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants.dart';
import '../application/visual_search_controller.dart';
import '../domain/visual_search_models.dart';
import 'visual_search_chrome.dart';
import 'visual_search_picker.dart';
import 'visual_search_result_pages.dart';
import 'widgets/visual_search_cards.dart';
import 'widgets/visual_search_states.dart';

class VisualSearchCapturePage extends StatefulWidget {
  const VisualSearchCapturePage({
    super.key,
    required this.jobType,
    this.autoPick,
    this.controller,
  });

  final VisualSearchJobType jobType;
  final ImageSource? autoPick;
  final VisualSearchController? controller;

  @override
  State<VisualSearchCapturePage> createState() => _VisualSearchCapturePageState();
}

class _VisualSearchCapturePageState extends State<VisualSearchCapturePage> {
  late final VisualSearchController _controller;
  String? _openedJobId;
  var _autoStarted = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? VisualSearchController.shared();
    _controller.addListener(_onController);
    if (widget.autoPick != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pick(widget.autoPick!));
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onController);
    super.dispose();
  }

  void _onController() {
    final job = _controller.activeJob;
    if (!mounted || job == null || _openedJobId == job.id) return;
    final phase = _controller.phase;
    if (phase != VisualSearchPhase.success && phase != VisualSearchPhase.empty) {
      return;
    }
    _openedJobId = job.id;
    final page = job.isProductSearch
        ? ProductMatchResultPage(job: job, controller: _controller)
        : AnalysisResultPage(job: job, controller: _controller);
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  Future<void> _pick(ImageSource source) async {
    if (_autoStarted && source == widget.autoPick && _openedJobId != null) return;
    _autoStarted = true;
    _controller.markSelecting();
    final image = await pickVisualSearchImage(context, source);
    if (!mounted) return;
    if (image == null) {
      _controller.markIdle();
      return;
    }
    await _controller.analyze(
      type: widget.jobType,
      bytes: image.bytes,
      fileName: image.fileName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final intelligence = widget.jobType != VisualSearchJobType.visualSearch;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: visualSearchAppBar(
        context,
        intelligence ? 'Görsel Zeka' : 'Ürünü Arat',
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          return VisualSearchPageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                VisualSearchUploadArea(
                  title: intelligence
                      ? 'Hasar ve eksik parça'
                      : 'Katalogda ürün ara',
                  subtitle: intelligence
                      ? 'Eksik parçalı veya hasarlı ürün fotoğrafı yükle.'
                      : 'Kameradan çek veya galeriden seç, benzer ürünler gelsin.',
                  onCamera: () => _pick(ImageSource.camera),
                  onGallery: () => _pick(ImageSource.gallery),
                ),
                const SizedBox(height: 16),
                _phasePanel(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _phasePanel() {
    switch (_controller.phase) {
      case VisualSearchPhase.uploading:
        return const VisualSearchStatePanel(
          icon: Icons.cloud_upload_outlined,
          title: 'Fotoğraf hazırlanıyor',
          message: 'Görsel kayda alınıyor.',
          busy: true,
        );
      case VisualSearchPhase.analyzing:
        return const VisualSearchStatePanel(
          icon: Icons.auto_awesome_outlined,
          title: 'Analiz ediliyor',
          message: 'Hasar, eksik parça ve benzer ürünler taranıyor.',
          busy: true,
        );
      case VisualSearchPhase.error:
        return VisualSearchStatePanel(
          icon: Icons.error_outline,
          title: 'İşlem tamamlanamadı',
          message: _controller.errorMessage ?? 'Tekrar deneyin.',
          actionLabel: 'Tekrar dene',
          onAction: _controller.retry,
        );
      case VisualSearchPhase.empty:
        return const VisualSearchStatePanel(
          icon: Icons.search_off,
          title: 'Sonuç yok',
          message: 'Bu görsel için eşleşme bulunamadı. Başka bir açıdan çekmeyi dene.',
        );
      case VisualSearchPhase.success:
        return const VisualSearchStatePanel(
          icon: Icons.check_circle_outline,
          title: 'Sonuç hazır',
          message: 'Analiz ekranı açıldı. Buradan yeni bir görsel de ekleyebilirsin.',
        );
      case VisualSearchPhase.idle:
      case VisualSearchPhase.selectingImage:
        return const SizedBox.shrink();
    }
  }
}
