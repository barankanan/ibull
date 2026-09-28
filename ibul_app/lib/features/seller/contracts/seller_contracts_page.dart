import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants.dart';
import '../../../widgets/ibul_page_state.dart';
import 'store_contract.dart';
import 'store_contract_repository.dart';

class SellerContractsPage extends StatefulWidget {
  const SellerContractsPage({super.key, required this.sellerId});

  final String sellerId;

  @override
  State<SellerContractsPage> createState() => _SellerContractsPageState();
}

class _SellerContractsPageState extends State<SellerContractsPage> {
  final _repo = StoreContractRepository();
  List<StoreContractVersion> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await _repo.listMine();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      debugPrint('seller contracts load');
      if (!mounted) return;
      setState(() {
        _error = 'Sözleşmeler yüklenemedi';
        _loading = false;
      });
    }
  }

  StoreContractVersion? _of(String type) {
    for (final item in _items) {
      if (item.type == type) return item;
    }
    return null;
  }

  Future<void> _edit(String type) async {
    final existing = _of(type);
    final title = TextEditingController(
      text: existing?.title ?? StoreContractTypes.labels[type] ?? '',
    );
    final body = TextEditingController(text: existing?.bodyText ?? '');
    var usePdf = existing?.isPdf == true;
    String? pdfPath = existing?.pdfPath;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: Text(StoreContractTypes.labels[type] ?? 'Sözleşme'),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: title,
                        decoration: const InputDecoration(labelText: 'Sözleşme adı'),
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: false, label: Text('Metin Yaz')),
                          ButtonSegment(value: true, label: Text('PDF Yükle')),
                        ],
                        selected: {usePdf},
                        onSelectionChanged: (value) {
                          setLocal(() => usePdf = value.first);
                        },
                      ),
                      const SizedBox(height: 8),
                      if (!usePdf)
                        TextField(
                          controller: body,
                          minLines: 8,
                          maxLines: 16,
                          decoration: const InputDecoration(
                            labelText: 'Sözleşme metni',
                            alignLabelWithHint: true,
                          ),
                        )
                      else
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () async {
                              final picked = await FilePicker.platform.pickFiles(
                                type: FileType.custom,
                                allowedExtensions: const ['pdf'],
                                withData: true,
                              );
                              final files = picked?.files;
                              if (files == null || files.isEmpty) return;
                              final file = files.first;
                              if (file.bytes == null) return;
                              pdfPath = await _repo.uploadPdf(
                                type: type,
                                bytes: file.bytes!,
                                fileName: file.name,
                              );
                              setLocal(() {});
                            },
                            icon: const Icon(Icons.upload_file),
                            label: Text(
                              pdfPath == null ? 'PDF seç' : 'PDF yüklendi · değiştir',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Vazgeç'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Kaydet'),
                ),
              ],
            );
          },
        );
      },
    );
    if (saved != true) return;
    await _repo.publish(
      type: type,
      title: title.text.trim(),
      bodyText: usePdf ? null : body.text.trim(),
      pdfPath: usePdf ? pdfPath : null,
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const IbulPageState.loading();
    if (_error != null) {
      return IbulPageState.error(title: _error!, onAction: _load);
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Sözleşmeler',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text(
          'Yeni sürüm kaydedildiğinde eski kiralama/siparişlerin kabul kaydı değişmez.',
          style: TextStyle(color: AppColors.textGrey),
        ),
        const SizedBox(height: 16),
        _card(StoreContractTypes.vehicleRental),
        const SizedBox(height: 12),
        _card(StoreContractTypes.productSale),
      ],
    );
  }

  Widget _card(String type) {
    final item = _of(type);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            StoreContractTypes.labels[type] ?? type,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(item == null ? 'Henüz tanımlanmadı' : item.title),
          if (item != null)
            Text(
              'Sürüm ${item.version}  ·  ${item.isActive ? 'Aktif' : 'Pasif'}'
              '${item.updatedAt == null ? '' : '  ·  ${item.updatedAt}'}',
              style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              FilledButton(
                onPressed: () => _edit(type),
                child: Text(item == null ? 'Oluştur' : 'Yeni sürüm'),
              ),
              if (item != null)
                OutlinedButton(
                  onPressed: () async {
                    await _repo.setActive(type: type, active: !item.isActive);
                    await _load();
                  },
                  child: Text(item.isActive ? 'Pasifleştir' : 'Aktifleştir'),
                ),
              if (item?.isPdf == true)
                TextButton(
                  onPressed: () async {
                    final url = await _repo.signedPdfUrl(item!);
                    if (url == null) return;
                    await launchUrl(Uri.parse(url));
                  },
                  child: const Text('PDF'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
