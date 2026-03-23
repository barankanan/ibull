import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/constants.dart';
import '../services/order_service.dart';

class ReturnPickupSchedulePage extends StatefulWidget {
  const ReturnPickupSchedulePage({
    super.key,
    required this.userId,
    required this.orderItemId,
    this.initialReturnRequestId,
    this.productName,
    this.storeName,
  });

  final String userId;
  final String orderItemId;
  final String? initialReturnRequestId;
  final String? productName;
  final String? storeName;

  @override
  State<ReturnPickupSchedulePage> createState() =>
      _ReturnPickupSchedulePageState();
}

class _ReturnPickupSchedulePageState extends State<ReturnPickupSchedulePage> {
  static const Locale _trLocale = Locale('tr', 'TR');
  final TextEditingController _noteController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  String _errorText = '';
  String _requestId = '';

  late DateTime _selectedDate;
  TimeOfDay _startTime = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 12, minute: 0);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day + 1);
    _loadRequestAndDefaults();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  DateTime get _windowStart => DateTime(
    _selectedDate.year,
    _selectedDate.month,
    _selectedDate.day,
    _startTime.hour,
    _startTime.minute,
  );

  DateTime get _windowEnd => DateTime(
    _selectedDate.year,
    _selectedDate.month,
    _selectedDate.day,
    _endTime.hour,
    _endTime.minute,
  );

  DateTime _asLocalDateTime(DateTime value) {
    return value.isUtc ? value.toLocal() : value;
  }

  Future<DateTime?> _showTurkishDatePicker({
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
  }) {
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      locale: _trLocale,
      helpText: 'Tarih seç',
      cancelText: 'Vazgeç',
      confirmText: 'Tamam',
      fieldLabelText: 'Tarih',
      fieldHintText: 'gg.aa.yyyy',
      errorFormatText: 'Tarih formatı geçersiz',
      errorInvalidText: 'Geçerli bir tarih seçin',
    );
  }

  Future<TimeOfDay?> _showEasyTimePicker(TimeOfDay initialTime) {
    return showTimePicker(
      context: context,
      initialTime: initialTime,
      initialEntryMode: TimePickerEntryMode.input,
      helpText: 'Saat seç',
      cancelText: 'Vazgeç',
      confirmText: 'Tamam',
      hourLabelText: 'Saat',
      minuteLabelText: 'Dakika',
      errorInvalidText: 'Geçerli bir saat girin',
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(alwaysUse24HourFormat: true),
          child: Localizations.override(
            context: context,
            locale: _trLocale,
            delegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }

  Future<void> _loadRequestAndDefaults() async {
    try {
      var requestId = widget.initialReturnRequestId?.trim() ?? '';
      Map<String, dynamic>? request;

      if (requestId.isNotEmpty) {
        request = await OrderService.instance.getReturnRequestById(requestId);
      }
      if (request == null || request.isEmpty) {
        request = await OrderService.instance.getLatestReturnRequestForItem(
          orderItemId: widget.orderItemId,
        );
      }
      if (request == null) {
        setState(() {
          _errorText = 'İade kaydı bulunamadı.';
          _isLoading = false;
        });
        return;
      }

      requestId = request['id']?.toString().trim() ?? '';
      final requestStatus = request['status']?.toString().toLowerCase() ?? '';
      if (requestId.isEmpty ||
          (requestStatus != 'awaiting_customer_pickup_slot' &&
              requestStatus != 'pickup_scheduled')) {
        setState(() {
          _errorText =
              'Kurye zamanını seçebilmek için satıcı onayı bekleniyor.';
          _isLoading = false;
        });
        return;
      }

      final parsedStart = DateTime.tryParse(
        request['customer_pickup_slot_start']?.toString() ?? '',
      );
      final parsedEnd = DateTime.tryParse(
        request['customer_pickup_slot_end']?.toString() ?? '',
      );
      final parsedNote = request['buyer_pickup_note']?.toString() ?? '';

      if (parsedStart != null) {
        final localStart = _asLocalDateTime(parsedStart);
        _selectedDate = DateTime(
          localStart.year,
          localStart.month,
          localStart.day,
        );
        _startTime = TimeOfDay(
          hour: localStart.hour,
          minute: localStart.minute,
        );
      }
      if (parsedEnd != null) {
        final localEnd = _asLocalDateTime(parsedEnd);
        _endTime = TimeOfDay(hour: localEnd.hour, minute: localEnd.minute);
      }
      _noteController.text = parsedNote;

      setState(() {
        _requestId = requestId;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _errorText = 'İade kaydı yüklenirken bir hata oluştu.';
        _isLoading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await _showTurkishDatePicker(
      initialDate: _selectedDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year, now.month + 2, now.day),
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedDate = picked);
  }

  Future<void> _pickStartTime() async {
    final picked = await _showEasyTimePicker(_startTime);
    if (picked == null || !mounted) return;
    setState(() => _startTime = picked);
  }

  Future<void> _pickEndTime() async {
    final picked = await _showEasyTimePicker(_endTime);
    if (picked == null || !mounted) return;
    setState(() => _endTime = picked);
  }

  Future<void> _submit() async {
    final windowStart = _windowStart;
    final windowEnd = _windowEnd;
    if (!windowEnd.isAfter(windowStart)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitiş saati başlangıç saatinden sonra olmalı.'),
        ),
      );
      return;
    }
    if (windowStart.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Seçilen başlangıç saati şu andan ileri bir zaman olmalı.',
          ),
        ),
      );
      return;
    }
    if (_requestId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('İade kaydı bulunamadı.')));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await OrderService.instance.scheduleReturnPickupWindow(
        userId: widget.userId,
        returnRequestId: _requestId,
        pickupWindowStart: windowStart,
        pickupWindowEnd: windowEnd,
        note: _noteController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _formatDate(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
  }

  String _formatTime(TimeOfDay value) {
    return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime value) {
    return '${_formatDate(value)} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final productName = widget.productName?.trim().isNotEmpty == true
        ? widget.productName!.trim()
        : 'Ürün';
    final storeName = widget.storeName?.trim().isNotEmpty == true
        ? widget.storeName!.trim()
        : 'Mağaza';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F8),
      appBar: AppBar(
        title: const Text('İade Kurye Planlama'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorText.isNotEmpty
          ? _buildErrorState()
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderCard(
                    productName: productName,
                    storeName: storeName,
                  ),
                  const SizedBox(height: 14),
                  _buildSlotCard(),
                  const SizedBox(height: 14),
                  _buildNoteCard(),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submit,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.schedule_send_outlined),
                      label: Text(
                        _isSubmitting
                            ? 'Kaydediliyor...'
                            : 'Kurye Alım Zamanını Onayla',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Text(
            _errorText,
            style: const TextStyle(fontSize: 14, color: Color(0xFF475467)),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard({
    required String productName,
    required String storeName,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF5A22E0), Color(0xFF3A0CA3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kurye alım günü ve saatini seç',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$storeName • $productName',
            style: const TextStyle(color: Color(0xFFE4DEFF), fontSize: 13),
          ),
          const SizedBox(height: 10),
          Text(
            'iHız kurye bildirimi ${_formatDateTime(_windowStart)} anında düşer.',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Alım Aralığı',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: Text(_formatDate(_selectedDate)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickStartTime,
                  icon: const Icon(Icons.login_rounded, size: 18),
                  label: Text('Başlangıç ${_formatTime(_startTime)}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _pickEndTime,
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: Text('Bitiş ${_formatTime(_endTime)}'),
          ),
          const SizedBox(height: 8),
          Text(
            'Seçilen aralık: ${_formatDateTime(_windowStart)} - ${_formatDateTime(_windowEnd)}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF667085)),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: TextField(
        controller: _noteController,
        maxLines: 3,
        decoration: InputDecoration(
          labelText: 'Kurye notu (opsiyonel)',
          hintText: 'Adres tarifi, bina kodu veya kurye için ek bilgi.',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
