import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ibul_app/core/constants.dart';
import 'package:ibul_app/utils/browser_file_download.dart';

import 'bulk_product_csv_file_picker.dart';
import 'bulk_product_import_models.dart' show BulkProductSelectedFile;
import 'bulk_product_price_stock_update_models.dart';
import 'bulk_product_price_stock_update_service.dart';

class BulkProductPriceStockUpdateModal extends StatefulWidget {
  const BulkProductPriceStockUpdateModal({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) =>
          const BulkProductPriceStockUpdateModal(),
    );
  }

  @override
  State<BulkProductPriceStockUpdateModal> createState() =>
      _BulkProductPriceStockUpdateModalState();
}

class _BulkProductPriceStockUpdateModalState
    extends State<BulkProductPriceStockUpdateModal> {
  final BulkProductPriceStockUpdateService _service =
      BulkProductPriceStockUpdateService();

  BulkProductSelectedFile? _selectedFile;
  BulkProductPriceStockUpdatePreview? _preview;
  BulkProductPriceStockUpdateExecutionSummary? _executionSummary;
  String? _inlineError;
  bool _isPickingFile = false;
  bool _isPreviewing = false;
  bool _isUpdating = false;
  bool _shouldRefreshOnClose = false;

  bool get _isLoading => _isPickingFile || _isPreviewing || _isUpdating;

  String? get _loadingMessage {
    if (_isUpdating) {
      return 'Geçerli satırlar güncelleniyor...';
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
    final List<int> bytes = utf8.encode(bulkProductPriceStockUpdateTemplateCsv);
    BrowserFileDownload.saveBytes(
      bytes: bytes,
      fileName: 'urunler_toplu_fiyat_stok_guncelleme_sablonu.csv',
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
        _executionSummary = null;
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
      _executionSummary = null;
      _inlineError = null;
    });

    try {
      final BulkProductPriceStockUpdatePreview preview = await _service
          .buildPreview(_selectedFile!);
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

  Future<void> _applyValidRows() async {
    final BulkProductPriceStockUpdatePreview? preview = _preview;
    if (preview == null || !preview.hasUpdatableRows || _isUpdating) {
      return;
    }

    setState(() {
      _isUpdating = true;
      _executionSummary = null;
      _inlineError = null;
    });

    try {
      final BulkProductPriceStockUpdateExecutionSummary summary = await _service
          .updateValidRows(preview);
      BulkProductPriceStockUpdatePreview? refreshedPreview;
      final BulkProductSelectedFile? selectedFile = _selectedFile;
      if (selectedFile != null) {
        try {
          refreshedPreview = await _service.buildPreview(selectedFile);
        } catch (_) {}
      }
      if (!mounted) {
        return;
      }
      final String message =
          'Toplu güncelleme tamamlandı. ${summary.updatedRows} satır güncellendi, '
          '${summary.invalidRows} hatalı, ${summary.unchangedRows} değişiklik yok'
          '${summary.failedRows > 0 ? ', ${summary.failedRows} satır başarısız' : ''}.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      setState(() {
        _preview = refreshedPreview ?? _preview;
        _executionSummary = summary;
        _shouldRefreshOnClose =
            _shouldRefreshOnClose || summary.updatedRows > 0;
        _isUpdating = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _inlineError = error.toString().replaceFirst('Exception: ', '');
        _isUpdating = false;
      });
    }
  }

  void _closeModal() {
    Navigator.of(context).pop(_shouldRefreshOnClose);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isNarrow = screenWidth < 1080;
    final BulkProductPriceStockUpdatePreview? preview = _preview;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: math.min(screenWidth - 32, 1280),
          maxHeight: 748,
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
                            Icons.price_change_outlined,
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
                                'Toplu Fiyat & Stok Güncelleme',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'CSV dosyasını yükleyin, SKU üzerinden eşleştirilmiş satırları önizleyin ve yalnızca geçerli değişiklikleri tek seferde uygulayın.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFF6B7280),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _isUpdating ? null : _closeModal,
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
                          onPressed: _isUpdating ? null : _downloadTemplate,
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
                          onPressed: _isUpdating ? null : _pickFile,
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
                          onPressed: _selectedFile == null || _isUpdating
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
                                  label: 'Güncellenecek',
                                  value: '${preview.updatableRowCount}',
                                  color: const Color(0xFF15803D),
                                  background: const Color(0xFFDCFCE7),
                                ),
                                _buildSummaryChip(
                                  label: 'Hatalı',
                                  value: '${preview.invalidRowCount}',
                                  color: const Color(0xFFB91C1C),
                                  background: const Color(0xFFFEE2E2),
                                ),
                                _buildSummaryChip(
                                  label: 'Değişiklik Yok',
                                  value: '${preview.unchangedRowCount}',
                                  color: const Color(0xFF475569),
                                  background: const Color(0xFFF1F5F9),
                                ),
                              ],
                            ),
                            if (_executionSummary != null) ...<Widget>[
                              const SizedBox(height: 14),
                              _buildExecutionSummaryCard(_executionSummary!),
                            ],
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
                                          DataColumn(label: Text('SKU')),
                                          DataColumn(
                                            label: Text('Mevcut Fiyat'),
                                          ),
                                          DataColumn(label: Text('Yeni Fiyat')),
                                          DataColumn(
                                            label: Text('Mevcut Stok'),
                                          ),
                                          DataColumn(label: Text('Yeni Stok')),
                                          DataColumn(label: Text('Yeni Durum')),
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
                      onPressed: _isUpdating ? null : _closeModal,
                      child: Text(
                        _executionSummary == null ? 'İptal' : 'Kapat',
                      ),
                    ),
                    const Spacer(),
                    OutlinedButton(
                      onPressed: _isUpdating ? null : _pickFile,
                      child: const Text('Tekrar Dosya Seç'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed:
                          preview?.hasUpdatableRows == true && !_isUpdating
                          ? _applyValidRows
                          : null,
                      icon: _isUpdating
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
                        _isUpdating
                            ? 'Güncelleniyor...'
                            : 'Geçerli Satırları Güncelle',
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
            'Geçerli, hatalı ve değişiklik içermeyen satırlar burada ayrı ayrı gösterilecek.',
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

  Widget _buildExecutionSummaryCard(
    BulkProductPriceStockUpdateExecutionSummary summary,
  ) {
    final bool hasFailures = summary.failures.isNotEmpty;
    final Color accent = hasFailures
        ? const Color(0xFFB45309)
        : const Color(0xFF15803D);
    final Color background = hasFailures
        ? const Color(0xFFFFF7ED)
        : const Color(0xFFF0FDF4);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            hasFailures ? 'İşlem Özeti' : 'Güncelleme Tamamlandı',
            style: TextStyle(
              color: accent,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${summary.updatedRows} satır güncellendi, ${summary.invalidRows} hatalı, ${summary.unchangedRows} değişiklik yok.',
            style: const TextStyle(
              color: Color(0xFF111827),
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          if (hasFailures) ...<Widget>[
            const SizedBox(height: 12),
            ...summary.failures.map((
              BulkProductPriceStockUpdateFailure failure,
            ) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'Satır ${failure.rowNumber} (${failure.sku}): ${failure.message}',
                  style: const TextStyle(
                    color: Color(0xFF92400E),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  DataRow _buildPreviewRow(BulkProductPriceStockPreviewRow row) {
    return DataRow(
      color: WidgetStateProperty.all(_rowBackgroundColor(row)),
      cells: <DataCell>[
        DataCell(Text('${row.rowNumber}')),
        DataCell(
          SizedBox(
            width: 140,
            child: Text(
              row.sku.isEmpty ? '-' : row.sku,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        DataCell(Text(_formatPrice(row.currentProduct?.price))),
        DataCell(Text(_formatRawPrice(row.rawValues['price']))),
        DataCell(Text(_formatStock(row.currentProduct?.stock))),
        DataCell(Text(_formatRawStock(row.rawValues['stock']))),
        DataCell(
          SizedBox(
            width: 120,
            child: Text(
              row.newStatusLabel,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        DataCell(_BulkProductPriceStockStatusBadge(rowState: row.rowState)),
        DataCell(
          SizedBox(
            width: 320,
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
                                fontSize: 12,
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

  Color _rowBackgroundColor(BulkProductPriceStockPreviewRow row) {
    switch (row.rowState) {
      case BulkProductPriceStockUpdateRowState.updatable:
        return const Color(0xFFF8FFFB);
      case BulkProductPriceStockUpdateRowState.unchanged:
        return const Color(0xFFF8FAFC);
      case BulkProductPriceStockUpdateRowState.invalid:
        return const Color(0xFFFFFBFB);
    }
  }

  String _formatPrice(double? value) {
    if (value == null) {
      return '-';
    }
    final bool isWholeNumber = (value - value.roundToDouble()).abs() < 0.0001;
    return '₺${value.toStringAsFixed(isWholeNumber ? 0 : 2)}';
  }

  String _formatRawPrice(String? value) {
    final String text = value?.trim() ?? '';
    if (text.isEmpty) {
      return '-';
    }
    return text.startsWith('₺') ? text : '₺$text';
  }

  String _formatStock(int? value) {
    return value == null ? '-' : '$value';
  }

  String _formatRawStock(String? value) {
    final String text = value?.trim() ?? '';
    return text.isEmpty ? '-' : text;
  }
}

class _BulkProductPriceStockStatusBadge extends StatelessWidget {
  const _BulkProductPriceStockStatusBadge({required this.rowState});

  final BulkProductPriceStockUpdateRowState rowState;

  @override
  Widget build(BuildContext context) {
    late final Color background;
    late final Color foreground;
    late final String label;

    switch (rowState) {
      case BulkProductPriceStockUpdateRowState.updatable:
        background = const Color(0xFFDCFCE7);
        foreground = const Color(0xFF15803D);
        label = 'Güncellenecek';
      case BulkProductPriceStockUpdateRowState.invalid:
        background = const Color(0xFFFEE2E2);
        foreground = const Color(0xFFB91C1C);
        label = 'Hatalı';
      case BulkProductPriceStockUpdateRowState.unchanged:
        background = const Color(0xFFF1F5F9);
        foreground = const Color(0xFF475569);
        label = 'Değişiklik Yok';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
