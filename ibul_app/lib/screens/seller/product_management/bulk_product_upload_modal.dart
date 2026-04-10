import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ibul_app/core/constants.dart';
import 'package:ibul_app/utils/browser_file_download.dart';

import 'bulk_product_csv_file_picker.dart';
import 'bulk_product_import_models.dart';
import 'bulk_product_import_service.dart';

class BulkProductUploadModal extends StatefulWidget {
  const BulkProductUploadModal({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => const BulkProductUploadModal(),
    );
  }

  @override
  State<BulkProductUploadModal> createState() => _BulkProductUploadModalState();
}

class _BulkProductUploadModalState extends State<BulkProductUploadModal> {
  final BulkProductImportService _service = BulkProductImportService();

  BulkProductSelectedFile? _selectedFile;
  BulkProductImportPreview? _preview;
  String? _inlineError;
  bool _isPickingFile = false;
  bool _isPreviewing = false;
  bool _isImporting = false;

  bool get _isLoading => _isPickingFile || _isPreviewing || _isImporting;

  String? get _loadingMessage {
    if (_isImporting) {
      return 'Ürünler ekleniyor...';
    }
    if (_isPreviewing) {
      return 'CSV önizlemesi hazırlanıyor...';
    }
    if (_isPickingFile) {
      return 'Dosya seçimi bekleniyor...';
    }
    return null;
  }

  Future<void> _downloadTemplate() async {
    final List<int> bytes = utf8.encode(bulkProductImportTemplateCsv);
    BrowserFileDownload.saveBytes(
      bytes: bytes,
      fileName: 'urunler_toplu_yukleme_sablonu.csv',
      mimeType: 'text/csv;charset=utf-8',
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('CSV şablonu indirildi.')));
  }

  Future<void> _pickFile() async {
    if (_isLoading) {
      return;
    }
    setState(() {
      _isPickingFile = true;
      _inlineError = null;
    });

    try {
      final BulkProductSelectedFile? file = await pickBulkProductCsvFile();
      if (!mounted) {
        return;
      }
      if (file == null) {
        setState(() {
          _isPickingFile = false;
        });
        return;
      }
      setState(() {
        _selectedFile = file;
        _preview = null;
        _inlineError = null;
        _isPickingFile = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _inlineError = error
            .toString()
            .replaceFirst('Exception: ', '')
            .replaceFirst('Unsupported operation: ', '');
        _isPickingFile = false;
      });
    }
  }

  Future<void> _previewFile() async {
    if (_selectedFile == null || _isLoading) {
      return;
    }
    setState(() {
      _isPreviewing = true;
      _inlineError = null;
    });

    try {
      final BulkProductImportPreview preview = await _service.buildPreview(
        _selectedFile!,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _preview = preview;
        _isPreviewing = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _inlineError = error.toString().replaceFirst('Exception: ', '');
        _isPreviewing = false;
      });
    }
  }

  Future<void> _importValidRows() async {
    final BulkProductImportPreview? preview = _preview;
    if (preview == null || !preview.hasValidRows || _isImporting) {
      return;
    }

    setState(() {
      _isImporting = true;
      _inlineError = null;
    });

    try {
      final BulkProductImportExecutionSummary summary = await _service
          .importValidRows(preview);
      if (!mounted) {
        return;
      }
      final String message = summary.successfulRows > 0
          ? 'Başarıyla ${summary.successfulRows} ürün eklendi.'
          : 'İçe aktarma tamamlandı ancak ürün eklenemedi.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _inlineError = error.toString().replaceFirst('Exception: ', '');
        _isImporting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isNarrow = screenWidth < 920;
    final BulkProductImportPreview? preview = _preview;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: math.min(screenWidth - 32, 1120),
          maxHeight: 736,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x140F172A),
                blurRadius: 28,
                offset: Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.file_upload_outlined,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Toplu Ürün Yükleme',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'CSV dosyası ile birden fazla ürünü aynı anda yükleyebilirsiniz. Önce şablonu indirin, sonra doldurup tekrar yükleyin.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFF6B7280),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _isImporting
                              ? null
                              : () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_loadingMessage != null) ...<Widget>[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F3FF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.14),
                          ),
                        ),
                        child: Row(
                          children: <Widget>[
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _loadingMessage!,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (_inlineError != null) ...<Widget>[
                      _buildInfoBanner(
                        color: const Color(0xFFDC2626),
                        background: const Color(0xFFFEE2E2),
                        icon: Icons.error_outline_rounded,
                        text: _inlineError!,
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (preview?.fileErrors.isNotEmpty == true) ...<Widget>[
                      _buildInfoBanner(
                        color: const Color(0xFFB45309),
                        background: const Color(0xFFFFF7ED),
                        icon: Icons.warning_amber_rounded,
                        text: preview!.fileErrors.join(' | '),
                      ),
                      const SizedBox(height: 14),
                    ],
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: <Widget>[
                        OutlinedButton.icon(
                          onPressed: _isImporting ? null : _downloadTemplate,
                          icon: const Icon(Icons.download_rounded, size: 18),
                          label: const Text('CSV Şablonunu İndir'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: BorderSide(
                              color: AppColors.primary.withValues(alpha: 0.22),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _isImporting ? null : _pickFile,
                          icon: Icon(
                            _isPickingFile
                                ? Icons.more_horiz_rounded
                                : Icons.attach_file_rounded,
                            size: 18,
                          ),
                          label: Text(
                            _selectedFile == null
                                ? 'CSV Dosyası Seç'
                                : 'Tekrar Dosya Seç',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF374151),
                            side: BorderSide(color: Colors.grey.shade300),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _selectedFile == null || _isImporting
                              ? null
                              : _previewFile,
                          icon: Icon(
                            _isPreviewing
                                ? Icons.more_horiz_rounded
                                : Icons.preview_outlined,
                            size: 18,
                          ),
                          label: const Text('Önizle'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_selectedFile != null) ...<Widget>[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Row(
                          children: <Widget>[
                            const Icon(
                              Icons.description_outlined,
                              size: 18,
                              color: Color(0xFF6B7280),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _selectedFile!.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: preview == null
                      ? _buildEmptyPreviewState()
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: <Widget>[
                                _buildSummaryChip(
                                  label: 'Toplam Satır',
                                  value: '${preview.totalRows}',
                                  color: const Color(0xFF1D4ED8),
                                  background: const Color(0xFFDBEAFE),
                                ),
                                _buildSummaryChip(
                                  label: 'Geçerli',
                                  value: '${preview.validRowCount}',
                                  color: const Color(0xFF15803D),
                                  background: const Color(0xFFDCFCE7),
                                ),
                                _buildSummaryChip(
                                  label: 'Hatalı',
                                  value: '${preview.invalidRowCount}',
                                  color: const Color(0xFFB91C1C),
                                  background: const Color(0xFFFEE2E2),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFFE5E7EB),
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: SingleChildScrollView(
                                      child: DataTable(
                                        headingRowColor:
                                            WidgetStateProperty.all(
                                              const Color(0xFFF8FAFC),
                                            ),
                                        horizontalMargin: 12,
                                        columnSpacing: isNarrow ? 16 : 22,
                                        columns: const <DataColumn>[
                                          DataColumn(label: Text('Satır')),
                                          DataColumn(label: Text('Ürün')),
                                          DataColumn(label: Text('Fiyat')),
                                          DataColumn(label: Text('Stok')),
                                          DataColumn(label: Text('Özellikler')),
                                          DataColumn(label: Text('Durum')),
                                          DataColumn(label: Text('Hata')),
                                        ],
                                        rows: preview.rows
                                            .map(_buildPreviewRow)
                                            .toList(growable: false),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                child: Row(
                  children: <Widget>[
                    TextButton(
                      onPressed: _isImporting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('İptal'),
                    ),
                    const Spacer(),
                    OutlinedButton(
                      onPressed: _isImporting ? null : _pickFile,
                      child: const Text('Tekrar dosya seç'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: preview?.hasValidRows == true && !_isImporting
                          ? _importValidRows
                          : null,
                      icon: _isImporting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.playlist_add_check_circle_outlined,
                              size: 18,
                            ),
                      label: Text(
                        _isImporting
                            ? 'Yükleniyor...'
                            : 'Geçerli kayıtları ekle',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyPreviewState() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.table_rows_outlined,
              color: AppColors.primary,
              size: 26,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'CSV dosyanızı seçip önizlemeyi başlatın',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Geçerli ve hatalı satırlar tablo halinde burada gösterilecek.',
            style: TextStyle(color: Color(0xFF6B7280)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner({
    required Color color,
    required Color background,
    required IconData icon,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryChip({
    required String label,
    required String value,
    required Color color,
    required Color background,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              color: color.withValues(alpha: 0.88),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  DataRow _buildPreviewRow(BulkProductImportPreviewRow row) {
    final String productName =
        row.candidate?.productName ?? row.rawValues['Ürün Adı'] ?? '-';
    final String price = row.rawValues['Fiyat']?.trim().isNotEmpty == true
        ? row.rawValues['Fiyat']!
        : '-';
    final String stock = row.rawValues['Stok']?.trim().isNotEmpty == true
        ? row.rawValues['Stok']!
        : '-';
    final List<String> attributes =
        row.candidate?.productAttributes ??
        parseCommaSeparated(row.rawValues['Ürün Özellikleri']);

    return DataRow(
      color: WidgetStateProperty.all(
        row.isValid ? const Color(0xFFF8FFFB) : const Color(0xFFFFFBFB),
      ),
      cells: <DataCell>[
        DataCell(Text('${row.rowNumber}')),
        DataCell(
          SizedBox(
            width: 180,
            child: Text(
              productName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        DataCell(Text(price)),
        DataCell(Text(stock)),
        DataCell(
          SizedBox(
            width: 260,
            child: attributes.isEmpty
                ? const Text('-', style: TextStyle(color: Color(0xFF6B7280)))
                : Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: attributes
                        .map((String item) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              item,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        })
                        .toList(growable: false),
                  ),
          ),
        ),
        DataCell(_StatusBadge(isValid: row.isValid)),
        DataCell(
          SizedBox(
            width: 280,
            child: row.errors.isEmpty
                ? const Text('-', style: TextStyle(color: Color(0xFF6B7280)))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: row.errors
                        .map((String error) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              error,
                              style: const TextStyle(
                                color: Color(0xFFB91C1C),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        })
                        .toList(growable: false),
                  ),
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isValid});

  final bool isValid;

  @override
  Widget build(BuildContext context) {
    final Color background = isValid
        ? const Color(0xFFDCFCE7)
        : const Color(0xFFFEE2E2);
    final Color foreground = isValid
        ? const Color(0xFF15803D)
        : const Color(0xFFB91C1C);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isValid ? 'Geçerli' : 'Hatalı',
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
