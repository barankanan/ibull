import 'package:flutter/material.dart';
import 'package:ibul_app/core/constants.dart';
import 'package:ibul_app/utils/browser_file_download.dart';

import 'bulk_product_csv_file_picker.dart';
import 'bulk_product_import_models.dart';
import 'bulk_product_import_service.dart';

class BulkProductUploadModal extends StatefulWidget {
  const BulkProductUploadModal({super.key});

  static Future<bool?> show(BuildContext context) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (BuildContext context) => const BulkProductUploadModal(),
      ),
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
    try {
      final List<int> bytes = buildBulkProductImportTemplateBytes();
      final String? savedPath = await BrowserFileDownload.saveBytes(
        bytes: bytes,
        fileName: bulkProductImportTemplateFileName,
        mimeType: 'text/csv;charset=utf-8',
      );
      if (!mounted) return;
      if (savedPath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('CSV şablonu indirme iptal edildi.'),
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV şablonu indirildi: $savedPath')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('CSV şablonu indirilemedi: $error'),
        ),
      );
    }
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
      await _previewFile();
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
      final StringBuffer message = StringBuffer();
      if (summary.successfulRows > 0) {
        message.write('${summary.successfulRows} ürün onay için gönderildi');
        if (summary.failedRows > 0) {
          message.write(', ${summary.failedRows} ürün hatalı');
        }
        message.write('.');
      } else {
        message.write('İçe aktarma tamamlandı ancak ürün eklenemedi.');
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message.toString())));

      if (summary.failures.isNotEmpty) {
        setState(() {
          _inlineError = summary.failures
              .map(
                (BulkProductImportFailure failure) =>
                    'Satır ${failure.rowNumber}: ${failure.message}',
              )
              .join('\n');
          _isImporting = false;
        });
        if (summary.successfulRows > 0) {
          Navigator.of(context).pop(true);
        }
        return;
      }

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
    final BulkProductImportPreview? preview = _preview;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0,
        scrolledUnderElevation: 0.5,
        title: const Text(
          'Toplu Ürün Yükleme',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        leading: IconButton(
          tooltip: 'Kapat',
          onPressed: _isImporting ? null : () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: Column(
        children: <Widget>[
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'CSV dosyası ile birden fazla ürünü aynı anda yükleyebilirsiniz. '
                  'Ürün ekleme adımlarındaki tüm alanlar (kargo ağırlık, en, boy, yükseklik dahil) şablonda yer alır. '
                  'Yüklenen ürünler admin onayından sonra yayına alınır.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF6B7280),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                if (_loadingMessage != null) ...<Widget>[
                  _buildLoadingBanner(_loadingMessage!),
                  const SizedBox(height: 12),
                ],
                if (_inlineError != null) ...<Widget>[
                  _buildInfoBanner(
                    color: const Color(0xFFDC2626),
                    background: const Color(0xFFFEE2E2),
                    icon: Icons.error_outline_rounded,
                    text: _inlineError!,
                  ),
                  const SizedBox(height: 12),
                ],
                if (preview?.fileErrors.isNotEmpty == true) ...<Widget>[
                  _buildInfoBanner(
                    color: const Color(0xFFB45309),
                    background: const Color(0xFFFFF7ED),
                    icon: Icons.warning_amber_rounded,
                    text: preview!.fileErrors.join(' | '),
                  ),
                  const SizedBox(height: 12),
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
              padding: const EdgeInsets.all(16),
              child: preview == null
                  ? _buildEmptyPreviewState()
                  : _buildPreviewPanel(preview),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: SafeArea(
          top: false,
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
                  _isImporting ? 'Yükleniyor...' : 'Geçerli kayıtları ekle',
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
      ),
    );
  }

  Widget _buildLoadingBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: <Widget>[
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewPanel(BulkProductImportPreview preview) {
    final List<String> tableHeaders = _resolveTableHeaders(preview);

    return Column(
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
            _buildSummaryChip(
              label: 'Kolon',
              value: '${tableHeaders.length}',
              color: const Color(0xFF7C3AED),
              background: const Color(0xFFEDE9FE),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        const Color(0xFFF8FAFC),
                      ),
                      dataRowMinHeight: 52,
                      dataRowMaxHeight: 120,
                      horizontalMargin: 16,
                      columnSpacing: 18,
                      columns: _buildPreviewColumns(tableHeaders),
                      rows: preview.rows
                          .map(
                            (BulkProductImportPreviewRow row) =>
                                _buildPreviewRow(row, tableHeaders),
                          )
                          .toList(growable: false),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<String> _resolveTableHeaders(BulkProductImportPreview preview) {
    if (preview.headers.isNotEmpty) {
      return preview.headers
          .map((String header) => header.trim())
          .where((String header) => header.isNotEmpty)
          .toList(growable: false);
    }
    final Set<String> discovered = <String>{};
    for (final BulkProductImportPreviewRow row in preview.rows) {
      discovered.addAll(row.rawValues.keys);
    }
    return discovered.toList(growable: false)..sort();
  }

  List<DataColumn> _buildPreviewColumns(List<String> tableHeaders) {
    return <DataColumn>[
      const DataColumn(
        label: Text('Satır', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      ...tableHeaders.map((String header) {
        return DataColumn(
          label: SizedBox(
            width: _columnWidthForHeader(header),
            child: Text(
              bulkProductImportHeaderLabel(header),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
              ),
            ),
          ),
        );
      }),
      const DataColumn(
        label: Text('Durum', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      const DataColumn(
        label: Text('Hata', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
    ];
  }

  double _columnWidthForHeader(String header) {
    final String normalized =
        bulkProductImportHeaderAliases[header.trim().toLowerCase()] ??
        header.trim().toLowerCase();
    if (normalized == 'cargo_weight_kg' ||
        normalized == 'kargo_agirlik_kg' ||
        normalized == 'cargo_width_cm' ||
        normalized == 'en_cm' ||
        normalized == 'cargo_length_cm' ||
        normalized == 'boy_cm' ||
        normalized == 'cargo_height_cm' ||
        normalized == 'yukseklik_cm') {
      return 150;
    }
    if (normalized.contains('json') ||
        normalized.contains('url') ||
        normalized.contains('description') ||
        normalized.contains('açıklama') ||
        normalized.contains('aciklama')) {
      return 260;
    }
    if (normalized.contains('name') ||
        normalized.contains('product') ||
        normalized.contains('ürün') ||
        normalized.contains('urun')) {
      return 220;
    }
    return 140;
  }

  String _valueForHeader(BulkProductImportPreviewRow row, String header) {
    final String trimmedHeader = header.trim();
    if (trimmedHeader.isEmpty) {
      return '-';
    }

    final Map<String, String> values = row.rawValues;
    if (values.containsKey(trimmedHeader)) {
      final String direct = values[trimmedHeader]!.trim();
      if (direct.isNotEmpty) {
        return direct;
      }
    }

    final String? canonical =
        bulkProductImportHeaderAliases[trimmedHeader.toLowerCase()];
    if (canonical != null && values.containsKey(canonical)) {
      final String canonicalValue = values[canonical]!.trim();
      if (canonicalValue.isNotEmpty) {
        return canonicalValue;
      }
    }

    for (final MapEntry<String, String> entry in values.entries) {
      if (entry.key.toLowerCase() == trimmedHeader.toLowerCase() &&
          entry.value.trim().isNotEmpty) {
        return entry.value.trim();
      }
    }

    return '-';
  }

  Widget _buildCellText(String value) {
    final String display = value.trim().isEmpty ? '-' : value.trim();
    return Tooltip(
      message: display == '-' ? '' : display,
      waitDuration: const Duration(milliseconds: 350),
      child: Text(
        display,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12.5, height: 1.35),
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
            'Tüm CSV kolonları ve ürün bilgileri tam sayfa tabloda gösterilecek.',
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

  DataRow _buildPreviewRow(
    BulkProductImportPreviewRow row,
    List<String> tableHeaders,
  ) {
    return DataRow(
      color: WidgetStateProperty.all(
        row.isValid ? const Color(0xFFF8FFFB) : const Color(0xFFFFFBFB),
      ),
      cells: <DataCell>[
        DataCell(Text('${row.rowNumber}')),
        ...tableHeaders.map((String header) {
          return DataCell(
            SizedBox(
              width: _columnWidthForHeader(header),
              child: _buildCellText(_valueForHeader(row, header)),
            ),
          );
        }),
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
