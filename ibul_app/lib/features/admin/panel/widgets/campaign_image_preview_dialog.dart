import 'package:flutter/material.dart';

import '../../../../widgets/optimized_image.dart';
import 'system_layout_section.dart';

/// Ana sayfa hero ölçüleri (`home_section_hero_banner.dart`): masaüstü gömülü
/// slider 264 px, mobil 160 px yükseklik; görseller `BoxFit.contain`.
const double _desktopHeroHeight = 264;
const double _desktopHeroWidth = 264 * 996 / 412;
const double _mobileHeroHeight = 160;
const double _mobileHeroWidth = 390 - 24;

Future<void> showCampaignImagePreviewDialog({
  required BuildContext context,
  required Map<String, dynamic> image,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _CampaignImagePreviewDialog(image: image),
  );
}

class _CampaignImagePreviewDialog extends StatefulWidget {
  const _CampaignImagePreviewDialog({required this.image});

  final Map<String, dynamic> image;

  @override
  State<_CampaignImagePreviewDialog> createState() =>
      _CampaignImagePreviewDialogState();
}

enum _PreviewMode { full, desktop, mobile }

class _CampaignImagePreviewDialogState
    extends State<_CampaignImagePreviewDialog> {
  var _mode = _PreviewMode.full;

  String get _desktopPath => widget.image['image_path']?.toString() ?? '';

  String get _mobilePath {
    final mobile = widget.image['mobile_image_path']?.toString().trim() ?? '';
    return mobile.isNotEmpty ? mobile : _desktopPath;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final title = (widget.image['title']?.toString() ?? '').trim();
    final link = (widget.image['link_url']?.toString() ?? '').trim();

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: SystemLayoutColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: size.width.clamp(320, 1100).toDouble(),
          maxHeight: size.height - 48,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title.isEmpty ? 'Kampanya görseli' : title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: SystemLayoutColors.title,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Kapat',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<_PreviewMode>(
                  segments: const [
                    ButtonSegment(
                      value: _PreviewMode.full,
                      icon: Icon(Icons.fullscreen_rounded, size: 16),
                      label: Text('Tam görsel'),
                    ),
                    ButtonSegment(
                      value: _PreviewMode.desktop,
                      icon: Icon(Icons.desktop_windows_outlined, size: 16),
                      label: Text('Masaüstü'),
                    ),
                    ButtonSegment(
                      value: _PreviewMode.mobile,
                      icon: Icon(Icons.phone_iphone_rounded, size: 16),
                      label: Text('Mobil'),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (value) =>
                      setState(() => _mode = value.first),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: SystemLayoutColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: SystemLayoutColors.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: _buildPreview(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Text(
                [
                  _modeNote(),
                  link.isEmpty ? 'Hedef bağlantı yok' : 'Hedef: $link',
                ].join('\n'),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: SystemLayoutColors.muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _modeNote() => switch (_mode) {
    _PreviewMode.full =>
      'Kırpılmamış görsel. Yakınlaştırmak için kaydırın veya sıkıştırın.',
    _PreviewMode.desktop =>
      'Masaüstü ana sayfa: 264 px yükseklik, görsel kırpılmadan sığdırılır.',
    _PreviewMode.mobile =>
      'Mobil ana sayfa (390 px ekran): 160 px yükseklik. '
          '${(widget.image['mobile_image_path']?.toString() ?? '').trim().isEmpty ? 'Mobil görsel yok, masaüstü görseli kullanılır.' : 'Mobil görsel kullanılır.'}',
  };

  Widget _buildPreview() {
    switch (_mode) {
      case _PreviewMode.full:
        return InteractiveViewer(
          maxScale: 5,
          child: Center(
            child: OptimizedImage(
              imageUrlOrPath: _desktopPath,
              fit: BoxFit.contain,
            ),
          ),
        );
      case _PreviewMode.desktop:
        return _frame(
          width: _desktopHeroWidth,
          height: _desktopHeroHeight,
          radius: 16,
          path: _desktopPath,
        );
      case _PreviewMode.mobile:
        return _frame(
          width: _mobileHeroWidth,
          height: _mobileHeroHeight,
          radius: 12,
          path: _mobilePath,
        );
    }
  }

  Widget _frame({
    required double width,
    required double height,
    required double radius,
    required String path,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(radius),
              boxShadow: const [
                BoxShadow(color: Color(0x14000000), blurRadius: 12),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: OptimizedImage(imageUrlOrPath: path, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
