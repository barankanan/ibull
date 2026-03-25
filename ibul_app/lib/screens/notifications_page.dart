import 'package:flutter/material.dart';
import 'package:ibul_app/widgets/optimized_image.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/chat_state.dart';
import '../core/constants.dart';
import '../services/auth_service.dart';
import '../services/order_service.dart';
import '../widgets/common/video_player_widget.dart';
import 'addresses_page.dart';
import 'ask_product_question_page.dart';
import 'cancel_appeal_page.dart';
import 'cancel_appeal_detail_page.dart';
import 'chat_page.dart';
import 'courier_info_page.dart';
import 'return_pickup_schedule_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage>
    with SingleTickerProviderStateMixin {
  static const String _ibulLogoAsset = 'assets/icons/ibul_logo_2.png';
  static const Locale _trLocale = Locale('tr', 'TR');
  late TabController _tabController;
  final TextEditingController _codeController = TextEditingController();
  final AuthService _authService = AuthService();
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _notifications = [];
  Map<String, String> _storeLogoByName = {};
  List<Map<String, dynamic>> _selectedTrackingHistory = [];
  Map<String, dynamic>? _selectedTrackingNotification;
  Map<String, dynamic>? _selectedTrackingData;
  final TextEditingController _returnPickupNoteController =
      TextEditingController();
  DateTime _returnPickupDate = DateTime.now();
  TimeOfDay _returnPickupStart = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _returnPickupEnd = const TimeOfDay(hour: 12, minute: 0);
  bool _isSubmittingReturnPickup = false;
  String _inlineReturnRequestId = '';
  bool _isLoadingNotifications = true;
  bool _isLoadingTracking = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _resetReturnPickupDraft(force: true);
    _loadNotifications();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _codeController.dispose();
    _returnPickupNoteController.dispose();
    super.dispose();
  }

  void _resetReturnPickupDraft({bool force = false}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isPastSelected = DateTime(
      _returnPickupDate.year,
      _returnPickupDate.month,
      _returnPickupDate.day,
    ).isBefore(today);
    if (force || isPastSelected) {
      _returnPickupDate = DateTime(now.year, now.month, now.day + 1);
      _returnPickupStart = const TimeOfDay(hour: 10, minute: 0);
      _returnPickupEnd = const TimeOfDay(hour: 12, minute: 0);
    }
  }

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

  void _hydrateReturnPickupDraft({
    required String requestId,
    String? slotStartRaw,
    String? slotEndRaw,
    String? note,
    bool resetIfMissing = false,
  }) {
    final parsedStart = DateTime.tryParse(slotStartRaw ?? '');
    final parsedEnd = DateTime.tryParse(slotEndRaw ?? '');
    final normalizedRequestId = requestId.trim();

    if (normalizedRequestId.isNotEmpty) {
      _inlineReturnRequestId = normalizedRequestId;
    } else if (resetIfMissing) {
      _inlineReturnRequestId = '';
    }

    if (parsedStart != null) {
      final localStart = _asLocalDateTime(parsedStart);
      _returnPickupDate = DateTime(
        localStart.year,
        localStart.month,
        localStart.day,
      );
      _returnPickupStart = TimeOfDay(
        hour: localStart.hour,
        minute: localStart.minute,
      );
    } else if (resetIfMissing) {
      _resetReturnPickupDraft(force: true);
    }

    if (parsedEnd != null) {
      final localEnd = _asLocalDateTime(parsedEnd);
      _returnPickupEnd = TimeOfDay(
        hour: localEnd.hour,
        minute: localEnd.minute,
      );
    } else if (resetIfMissing) {
      _returnPickupEnd = const TimeOfDay(hour: 12, minute: 0);
    }

    _returnPickupNoteController.text = (note ?? '').trim();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoadingNotifications = true);
    try {
      final currentUserId = _authService.currentUser?.id;
      if (currentUserId == null || currentUserId.isEmpty) {
        setState(() {
          _notifications = [];
          _isLoadingNotifications = false;
        });
        return;
      }
      final rows = await OrderService.instance.getUserNotifications(
        currentUserId,
      );
      final logoMap = await _resolveStoreLogosForNotifications(rows);
      if (!mounted) return;
      setState(() {
        _notifications = rows;
        _storeLogoByName = logoMap;
        _isLoadingNotifications = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingNotifications = false);
    }
  }

  String _normalizeStoreKey(String? raw) {
    return (raw ?? '').trim().toLowerCase();
  }

  String _notificationStoreName(
    Map<String, dynamic> notification,
    Map<String, dynamic> data,
  ) {
    final dataName = data['store_name']?.toString().trim() ?? '';
    if (dataName.isNotEmpty) return dataName;
    return _notificationTitle(notification).trim();
  }

  bool _isIbulReturnNotification(
    Map<String, dynamic> notification,
    Map<String, dynamic> data,
  ) {
    final type = data['type']?.toString().trim().toLowerCase() ?? '';
    final decision = data['decision']?.toString().trim().toLowerCase() ?? '';
    if (type == 'return_refund_completed') return true;
    if (type == 'return_reviewed' && decision == 'approved') return true;

    final normalizedTitle = _notificationTitle(notification).toLowerCase();
    return normalizedTitle.contains('iaden onaylandı') ||
        normalizedTitle.contains('iade talebin onaylandı');
  }

  String? _notificationLogoUrl(
    Map<String, dynamic> notification,
    Map<String, dynamic> data,
  ) {
    final direct = data['store_logo_url']?.toString().trim() ?? '';
    if (direct.isNotEmpty) return direct;
    final key = _normalizeStoreKey(_notificationStoreName(notification, data));
    if (key.isEmpty) return null;
    return _storeLogoByName[key];
  }

  Future<Map<String, String>> _resolveStoreLogosForNotifications(
    List<Map<String, dynamic>> notifications,
  ) async {
    final logos = <String, String>{};
    final namesNeedingLookup = <String>{};

    for (final notification in notifications) {
      final data = _notificationData(notification);
      final storeName = _notificationStoreName(notification, data);
      final key = _normalizeStoreKey(storeName);
      if (key.isEmpty) continue;

      final directLogo = data['store_logo_url']?.toString().trim() ?? '';
      if (directLogo.isNotEmpty) {
        logos[key] = directLogo;
      } else {
        namesNeedingLookup.add(storeName.trim());
      }
    }

    final unresolvedNames = namesNeedingLookup
        .where((name) => !logos.containsKey(_normalizeStoreKey(name)))
        .toList(growable: false);
    if (unresolvedNames.isEmpty) return logos;

    try {
      final rows = await _supabase
          .from('stores')
          .select('business_name, logo_url')
          .inFilter('business_name', unresolvedNames)
          .not('logo_url', 'is', null);

      for (final raw in (rows as List<dynamic>)) {
        final row = Map<String, dynamic>.from(raw as Map);
        final name = row['business_name']?.toString().trim() ?? '';
        final logo = row['logo_url']?.toString().trim() ?? '';
        final key = _normalizeStoreKey(name);
        if (key.isEmpty || logo.isEmpty) continue;
        logos.putIfAbsent(key, () => logo);
      }
    } catch (_) {}

    return logos;
  }

  Future<void> _openTrackingFromNotification(
    Map<String, dynamic> notification,
  ) async {
    final notificationId = notification['id']?.toString();
    final data = _notificationData(notification);
    final orderItemId = data['order_item_id']?.toString();
    final currentUserId = _authService.currentUser?.id;
    if (notificationId != null && notificationId.isNotEmpty) {
      OrderService.instance.markNotificationRead(notificationId);
    }
    if (currentUserId == null || currentUserId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Takip için giriş yapmanız gerekiyor.')),
      );
      return;
    }
    if (orderItemId == null || orderItemId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Takip bilgisi bulunamadı.')),
      );
      return;
    }

    setState(() {
      _isLoadingTracking = true;
      _selectedTrackingNotification = notification;
    });
    _tabController.animateTo(1);

    final results = await Future.wait<dynamic>([
      OrderService.instance.getUserTrackingSnapshotByItemId(
        userId: currentUserId,
        orderItemId: orderItemId,
      ),
      OrderService.instance.getOrderItemTracking(orderItemId),
      OrderService.instance.getLatestReturnRequestForItem(
        orderItemId: orderItemId,
      ),
    ]);
    if (!mounted) return;
    final snapshot = results[0] as Map<String, dynamic>?;
    final history = results[1] as List<Map<String, dynamic>>;
    final latestReturnRequest = results[2] as Map<String, dynamic>?;

    if (snapshot == null) {
      setState(() => _isLoadingTracking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Takip detayları yüklenemedi.')),
      );
      return;
    }

    setState(() {
      _selectedTrackingData = snapshot;
      _selectedTrackingHistory = history;
      _isLoadingTracking = false;
      _codeController.text = _preferredLookupCode(
        notificationData: data,
        snapshot: snapshot,
      );
      final trackedRequestId =
          data['return_request_id']?.toString().trim() ?? '';
      final latestRequestId =
          latestReturnRequest?['id']?.toString().trim() ?? '';
      final requestId = latestRequestId.isNotEmpty
          ? latestRequestId
          : trackedRequestId;
      final slotStartRaw =
          latestReturnRequest?['customer_pickup_slot_start']?.toString() ??
          data['customer_pickup_slot_start']?.toString() ??
          data['pickup_window_start']?.toString();
      final slotEndRaw =
          latestReturnRequest?['customer_pickup_slot_end']?.toString() ??
          data['customer_pickup_slot_end']?.toString() ??
          data['pickup_window_end']?.toString();
      final pickupNote =
          latestReturnRequest?['buyer_pickup_note']?.toString() ??
          data['buyer_pickup_note']?.toString() ??
          '';
      final hasReturnDraftSignal =
          requestId.isNotEmpty ||
          slotStartRaw?.trim().isNotEmpty == true ||
          slotEndRaw?.trim().isNotEmpty == true ||
          pickupNote.trim().isNotEmpty ||
          _shouldShowReturnAction(data);
      _hydrateReturnPickupDraft(
        requestId: requestId,
        slotStartRaw: slotStartRaw,
        slotEndRaw: slotEndRaw,
        note: pickupNote,
        resetIfMissing: !hasReturnDraftSignal,
      );
      final index = _notifications.indexWhere(
        (element) => element['id'] == notification['id'],
      );
      if (index != -1) {
        _notifications[index] = {
          ..._notifications[index],
          'read_at': DateTime.now().toIso8601String(),
        };
      }
    });
  }

  Future<void> _handleNotificationPrimaryAction(
    Map<String, dynamic> notification, {
    Map<String, dynamic>? linkedAppealData,
  }) async {
    final data = _notificationData(notification);
    if (_isCancelAppealAction(data)) {
      if (linkedAppealData != null) {
        await _openCancelAppealDetailFromData(
          sourceNotification: notification,
          detailData: linkedAppealData,
        );
        return;
      }
      await _openCancelAppealFromNotification(notification);
      return;
    }
    if (_isCancelAppealSubmittedInfo(data)) {
      await _openCancelAppealDetailFromNotification(notification);
      return;
    }
    if (!_shouldShowReturnAction(data)) {
      await _openTrackingFromNotification(notification);
      return;
    }
    await _openReturnPickupFromNotification(notification);
  }

  Future<void> _openCancelAppealFromNotification(
    Map<String, dynamic> notification,
  ) async {
    final notificationId = notification['id']?.toString().trim() ?? '';
    if (notificationId.isNotEmpty) {
      OrderService.instance.markNotificationRead(notificationId);
      if (mounted) {
        setState(() {
          final index = _notifications.indexWhere(
            (element) => element['id'] == notification['id'],
          );
          if (index != -1) {
            _notifications[index] = {
              ..._notifications[index],
              'read_at': DateTime.now().toIso8601String(),
            };
          }
        });
      }
    }

    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CancelAppealPage(
          notificationData: _notificationData(notification),
          notificationBody: notification['body']?.toString() ?? '',
        ),
      ),
    );
    if (!mounted) return;
    await _loadNotifications();
    if (!mounted) return;
    if (submitted != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('İtirazınız alındı. İnceleme sonucu bildirilecektir.'),
      ),
    );
  }

  Future<void> _openCancelAppealDetailFromData({
    required Map<String, dynamic> sourceNotification,
    required Map<String, dynamic> detailData,
  }) async {
    final notificationId = sourceNotification['id']?.toString().trim() ?? '';
    if (notificationId.isNotEmpty) {
      OrderService.instance.markNotificationRead(notificationId);
      if (mounted) {
        setState(() {
          final index = _notifications.indexWhere(
            (element) => element['id'] == sourceNotification['id'],
          );
          if (index != -1) {
            _notifications[index] = {
              ..._notifications[index],
              'read_at': DateTime.now().toIso8601String(),
            };
          }
        });
      }
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            CancelAppealDetailPage(data: detailData, explanationOnly: true),
      ),
    );
  }

  Future<void> _openCancelAppealDetailFromNotification(
    Map<String, dynamic> notification,
  ) async {
    await _openCancelAppealDetailFromData(
      sourceNotification: notification,
      detailData: _notificationData(notification),
    );
  }

  Future<void> _openReturnPickupFromNotification(
    Map<String, dynamic> notification,
  ) async {
    final currentUserId = _authService.currentUser?.id;
    if (currentUserId == null || currentUserId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('İade için giriş yapmanız gerekiyor.')),
      );
      return;
    }

    final data = _notificationData(notification);
    final orderItemId = data['order_item_id']?.toString().trim() ?? '';
    if (orderItemId.isEmpty) {
      await _openTrackingFromNotification(notification);
      return;
    }

    final notificationId = notification['id']?.toString().trim() ?? '';
    if (notificationId.isNotEmpty) {
      OrderService.instance.markNotificationRead(notificationId);
      if (mounted) {
        setState(() {
          final index = _notifications.indexWhere(
            (element) => element['id'] == notification['id'],
          );
          if (index != -1) {
            _notifications[index] = {
              ..._notifications[index],
              'read_at': DateTime.now().toIso8601String(),
            };
          }
        });
      }
    }

    String requestId = data['return_request_id']?.toString().trim() ?? '';
    String requestStatus = data['status']?.toString().trim() ?? '';
    Map<String, dynamic>? latestRequest;
    if (requestId.isEmpty || requestStatus.isEmpty) {
      latestRequest = await OrderService.instance.getLatestReturnRequestForItem(
        orderItemId: orderItemId,
      );
      if (latestRequest != null) {
        requestId = latestRequest['id']?.toString().trim() ?? requestId;
        requestStatus =
            latestRequest['status']?.toString().trim() ?? requestStatus;
      }
    }
    if (requestId.isEmpty) {
      await _openTrackingFromNotification(notification);
      return;
    }
    if (!_isReturnPickupEligibleStatus(requestStatus)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'İade Et seçeneği için önce satıcı/İBUL onayı gerekiyor.',
          ),
        ),
      );
      await _openTrackingFromNotification(notification);
      return;
    }
    if (!mounted) return;

    final scheduled = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ReturnPickupSchedulePage(
          userId: currentUserId,
          orderItemId: orderItemId,
          initialReturnRequestId: requestId,
          productName: data['product_name']?.toString(),
          storeName: data['store_name']?.toString(),
        ),
      ),
    );
    if (!mounted || scheduled != true) return;

    await _openTrackingFromNotification(notification);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('İade kurye alım zamanı kaydedildi.')),
    );
  }

  DateTime _returnWindowStart() {
    return DateTime(
      _returnPickupDate.year,
      _returnPickupDate.month,
      _returnPickupDate.day,
      _returnPickupStart.hour,
      _returnPickupStart.minute,
    );
  }

  DateTime _returnWindowEnd() {
    return DateTime(
      _returnPickupDate.year,
      _returnPickupDate.month,
      _returnPickupDate.day,
      _returnPickupEnd.hour,
      _returnPickupEnd.minute,
    );
  }

  Future<void> _pickInlineReturnDate() async {
    final now = DateTime.now();
    final picked = await _showTurkishDatePicker(
      initialDate: _returnPickupDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year, now.month + 2, now.day),
    );
    if (picked == null || !mounted) return;
    setState(() => _returnPickupDate = picked);
  }

  Future<void> _pickInlineReturnStartTime() async {
    final picked = await _showEasyTimePicker(_returnPickupStart);
    if (picked == null || !mounted) return;
    setState(() => _returnPickupStart = picked);
  }

  Future<void> _pickInlineReturnEndTime() async {
    final picked = await _showEasyTimePicker(_returnPickupEnd);
    if (picked == null || !mounted) return;
    setState(() => _returnPickupEnd = picked);
  }

  Future<void> _submitInlineReturnPickup(
    Map<String, dynamic> mergedData,
  ) async {
    final currentUserId = _authService.currentUser?.id;
    if (currentUserId == null || currentUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('İade için giriş yapmanız gerekiyor.')),
      );
      return;
    }
    final status = _selectedTrackingStatus(mergedData);
    if (!_isReturnPickupEligibleStatus(status)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Kurye çağırma için iadenin onaylanmış olması gerekiyor.',
          ),
        ),
      );
      return;
    }

    final deliveryType = mergedData['delivery_type']?.toString().trim() ?? '';
    if (deliveryType.isNotEmpty && !_isNearDistanceDeliveryType(deliveryType)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Bu siparişte iade şubeden satıcıya gönderilir. Kurye çağırma kapalıdır.',
          ),
        ),
      );
      return;
    }

    String requestId = _inlineReturnRequestId.trim();
    if (requestId.isEmpty) {
      requestId = mergedData['return_request_id']?.toString().trim() ?? '';
    }
    final orderItemId = mergedData['id']?.toString().trim() ?? '';
    if (requestId.isEmpty && orderItemId.isNotEmpty) {
      final latest = await OrderService.instance.getLatestReturnRequestForItem(
        orderItemId: orderItemId,
      );
      if (!mounted) return;
      requestId = latest?['id']?.toString().trim() ?? '';
    }
    if (requestId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('İade kaydı bulunamadı.')));
      return;
    }

    final windowStart = _returnWindowStart();
    final windowEnd = _returnWindowEnd();
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

    setState(() => _isSubmittingReturnPickup = true);
    try {
      await OrderService.instance.scheduleReturnPickupWindow(
        userId: currentUserId,
        returnRequestId: requestId,
        pickupWindowStart: windowStart,
        pickupWindowEnd: windowEnd,
        note: _returnPickupNoteController.text.trim(),
      );
      if (!mounted) return;
      _inlineReturnRequestId = requestId;
      if (_selectedTrackingNotification != null) {
        await _openTrackingFromNotification(_selectedTrackingNotification!);
      } else if (orderItemId.isNotEmpty) {
        final snapshot = await OrderService.instance
            .getUserTrackingSnapshotByItemId(
              userId: currentUserId,
              orderItemId: orderItemId,
            );
        final history = await OrderService.instance.getOrderItemTracking(
          orderItemId,
        );
        if (mounted && snapshot != null) {
          setState(() {
            _selectedTrackingData = snapshot;
            _selectedTrackingHistory = history;
          });
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Kurye alım zamanı kaydedildi. İade adımlarını izleyebilirsiniz.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmittingReturnPickup = false);
      }
    }
  }

  Future<void> _searchTrackingByCode() async {
    final code = _codeController.text.trim();
    final currentUserId = _authService.currentUser?.id;
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen bir ürün kodu girin.')),
      );
      return;
    }
    if (currentUserId == null || currentUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Takip için giriş yapmanız gerekiyor.')),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isLoadingTracking = true);

    final snapshot = await OrderService.instance.findUserTrackingByCode(
      userId: currentUserId,
      code: code,
    );
    if (!mounted) return;

    if (snapshot == null) {
      setState(() => _isLoadingTracking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu koda ait takip kaydı bulunamadı.')),
      );
      return;
    }

    final orderItemId = snapshot['id']?.toString() ?? '';
    final history = orderItemId.isEmpty
        ? <Map<String, dynamic>>[]
        : await OrderService.instance.getOrderItemTracking(orderItemId);
    if (!mounted) return;

    setState(() {
      _selectedTrackingNotification = null;
      _selectedTrackingData = snapshot;
      _selectedTrackingHistory = history;
      _isLoadingTracking = false;
      _codeController.text = snapshot['lookup_code']?.toString() ?? code;
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = ChatState().chatHistory
        .map(
          (chat) => {
            'productImage':
                chat['productImage'] ??
                'https://via.placeholder.com/60x60.png?text=Chat',
            'productTitle': chat['productName'] ?? 'Genel Sohbet',
            'sellerName': chat['sellerName'],
            'sellerBadge': chat['sellerLogo'],
            'status': 'Yanıt Bekleniyor',
            'statusColor': AppColors.primary,
            'question': chat['lastMessage'] ?? '',
            'timestamp': chat['timestamp'] ?? '',
            'sellerId': chat['sellerId'],
            'sellerLogo': chat['sellerLogo'],
          },
        )
        .toList();

    final isWeb = MediaQuery.of(context).size.width >= 800;
    const double webMaxWidth = 900;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        leadingWidth: 56,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: const [SizedBox(width: 56)],
        centerTitle: true,
        title: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: webMaxWidth),
              child: Row(
                children: [
                  _buildTabButton(0, 'Bildirim', Icons.notifications),
                  _buildTabButton(1, 'İzleme', Icons.play_arrow),
                  _buildTabButton(2, 'Mesaj', Icons.message),
                ],
              ),
            ),
          ),
        ),
        toolbarHeight: 62,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isWeb ? webMaxWidth : double.infinity,
          ),
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildNotificationsTab(),
              _buildTrackingTab(),
              _buildMessagesTab(messages),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    final isActive = _tabController.index == index;
    return Expanded(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 95;
          final horizontalGap = isCompact ? 5.0 : 8.0;
          final horizontalPadding = isCompact ? 7.0 : 12.0;
          final verticalPadding = isCompact ? 5.0 : 6.0;
          final iconSize = isCompact ? 14.0 : 16.0;
          final fontSize = isCompact ? 11.0 : 12.0;
          final spacing = isCompact ? 3.0 : 4.0;

          return GestureDetector(
            onTap: () {
              _tabController.animateTo(index);
              setState(() {});
            },
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalGap),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: verticalPadding,
                ),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isActive ? AppColors.primary : Colors.grey.shade300,
                    width: index == 1 ? 0.8 : 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: iconSize,
                      color: isActive ? Colors.white : Colors.grey,
                    ),
                    SizedBox(width: spacing),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: TextStyle(
                          color: isActive ? Colors.white : Colors.grey,
                          fontWeight: FontWeight.w500,
                          fontSize: fontSize,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotificationsTab() {
    final visibleNotifications = _visibleNotifications();
    final cancelAppealsByKey = _latestCancelAppealsByLookupKey();
    if (_isLoadingNotifications) {
      return const Center(child: CircularProgressIndicator());
    }
    if (visibleNotifications.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE7EAF0)),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.notifications_none_rounded,
                  size: 56,
                  color: Color(0xFFB9C0CC),
                ),
                SizedBox(height: 12),
                Text(
                  'Henüz bildiriminiz yok',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 6),
                Text(
                  'Sipariş hazırlama ve kargo güncellemeleri burada görünecek.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF667085)),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: visibleNotifications.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final notification = visibleNotifications[index];
          final data = _notificationData(notification);
          final notificationType =
              data['type']?.toString().trim().toLowerCase() ?? '';
          final notificationStatus = _normalizeTrackingStatus(
            data['status']?.toString(),
          );
          final isRead = notification['read_at'] != null;
          final isIbulReturnNotice = _isIbulReturnNotification(
            notification,
            data,
          );
          final isReturnAction = _shouldShowReturnAction(data);
          final isCancelAppealAction = _isCancelAppealAction(data);
          final linkedAppealData = isCancelAppealAction
              ? _findLinkedAppealDataForCancelled(
                  cancelledData: data,
                  appealByLookupKey: cancelAppealsByKey,
                )
              : null;
          final isAppealedCancel = linkedAppealData != null;
          final isCancelAppealInfo = _isCancelAppealSubmittedInfo(data);
          final showsTrackingAction =
              notificationType == 'order_tracking' &&
              _isInTransitTrackingStatus(notificationStatus);
          final showsReviewAction =
              notificationType == 'order_tracking' &&
              notificationStatus == 'delivered';
          final showsPrimaryAction =
              isReturnAction ||
              isAppealedCancel ||
              isCancelAppealAction ||
              isCancelAppealInfo ||
              showsTrackingAction ||
              showsReviewAction;
          final actionColor = isReturnAction
              ? const Color(0xFFD93E53)
              : isAppealedCancel
              ? const Color(0xFFB42318)
              : isCancelAppealAction
              ? const Color(0xFFD92D20)
              : isCancelAppealInfo
              ? const Color(0xFF2563EB)
              : showsReviewAction
              ? const Color(0xFF2563EB)
              : AppColors.primary;
          final actionLabel = isReturnAction
              ? 'İade Et'
              : isAppealedCancel
              ? 'İtiraz Edildi'
              : isCancelAppealAction
              ? 'İtiraz Et'
              : isCancelAppealInfo
              ? 'Detay'
              : showsReviewAction
              ? 'İncele'
              : 'İzleme';
          final actionIcon = isReturnAction
              ? Icons.assignment_return_rounded
              : isAppealedCancel
              ? Icons.check_circle_outline
              : isCancelAppealAction
              ? Icons.gavel_rounded
              : isCancelAppealInfo
              ? Icons.article_outlined
              : showsReviewAction
              ? Icons.search_rounded
              : Icons.play_arrow_rounded;
          final notificationBody = _notificationCardDescription(
            notification: notification,
            data: data,
            isReturnAction: isReturnAction,
            isCancelAppealAction: isCancelAppealAction,
            isAppealedCancel: isAppealedCancel,
            isCancelAppealInfo: isCancelAppealInfo,
          );
          return Container(
            decoration: BoxDecoration(
              color: isReturnAction
                  ? const Color(0xFFFFF6F7)
                  : isCancelAppealAction
                  ? Colors.white
                  : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isReturnAction
                    ? const Color(0xFFF1B8BF)
                    : isCancelAppealAction
                    ? const Color(0xFFE6E9EF)
                    : const Color(0xFFE6E9EF),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStoreBadge(
                    logoUrl: isIbulReturnNotice
                        ? null
                        : _notificationLogoUrl(notification, data),
                    storeName: isIbulReturnNotice
                        ? 'iBul'
                        : _notificationStoreName(notification, data),
                    forceIbulLogo: isIbulReturnNotice,
                    size: 22,
                  ),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                _notificationTitle(notification),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                  height: 1.15,
                                ),
                              ),
                            ),
                            if (!isRead)
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: actionColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          notificationBody,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            height: 1.35,
                            color: isReturnAction
                                ? const Color(0xFF8A1E2F)
                                : isCancelAppealAction
                                ? const Color(0xFF475467)
                                : const Color(0xFF475467),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            if (showsPrimaryAction) ...[
                              OutlinedButton.icon(
                                onPressed: () => _handleNotificationPrimaryAction(
                                  notification,
                                  linkedAppealData: linkedAppealData,
                                ),
                                icon: Icon(actionIcon, size: 13),
                                label: Text(actionLabel),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor:
                                      isReturnAction || isCancelAppealAction
                                      ? Colors.white
                                      : actionColor,
                                  backgroundColor:
                                      isReturnAction || isCancelAppealAction
                                      ? actionColor
                                      : Colors.white,
                                  side: BorderSide(
                                    color: actionColor,
                                    width: 2,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  minimumSize: const Size(0, 30),
                                ),
                              ),
                              const Spacer(),
                            ]
                            else
                              const Spacer(),
                            Icon(
                              Icons.access_time_rounded,
                              size: 14,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatNotificationTime(
                                notification['created_at']?.toString(),
                              ),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTrackingTab() {
    final data = _selectedTrackingData;
    final selectedNotification = _selectedTrackingNotification;
    final notificationData = selectedNotification == null
        ? const <String, dynamic>{}
        : _notificationData(selectedNotification);
    final mergedData = <String, dynamic>{...notificationData, ...?data};
    final productName = mergedData['product_name']?.toString() ?? 'Ürün';
    final imageUrl = mergedData['product_image_url']?.toString() ?? '';
    final storeName = mergedData['store_name']?.toString() ?? 'Mağaza';
    final orderNo =
        mergedData['order_number']?.toString() ??
        mergedData['order_id']?.toString() ??
        '-';
    final trackingNo = mergedData['tracking_number']?.toString() ?? '-';
    final cargoCompany = mergedData['cargo_company']?.toString() ?? 'iHiz';
    final deliveryMode = _deliveryModeLabel(
      mergedData['delivery_mode']?.toString(),
      cargoCompany,
    );
    final videoUrl =
        mergedData['product_video_url']?.toString().trim().isNotEmpty == true
        ? mergedData['product_video_url'].toString().trim()
        : _extractTrackingVideoUrl(_selectedTrackingHistory);
    final trackingStatus = _selectedTrackingStatus(
      mergedData,
      sourceNotificationData: notificationData,
    );
    final useIbulLogo =
        selectedNotification != null &&
        _isIbulReturnNotification(selectedNotification, notificationData);
    final steps = _buildTrackingSteps(trackingStatus);
    final locationLabel = _bestLocationLabel(mergedData);
    final recipientName = mergedData['recipient_name']?.toString().trim() ?? '';
    final currentStatus = _trackingStatusTitle(trackingStatus);
    final openedFromReturnAction =
        selectedNotification != null &&
        _shouldShowReturnAction(notificationData);
    final showInlineReturnPlanner =
        mergedData.isNotEmpty &&
        openedFromReturnAction &&
        _canUseInlineReturnPlanner(mergedData, trackingStatus);
    final showDetails = mergedData.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showInlineReturnPlanner) ...[
            _buildInlineReturnPickupPlanner(mergedData),
            const SizedBox(height: 16),
          ],
          _buildCodeLookupCard(),
          const SizedBox(height: 16),
          if (_isLoadingTracking)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (!showDetails)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: _trackingCardDecoration(),
              child: const Column(
                children: [
                  Icon(
                    Icons.play_circle_outline_rounded,
                    size: 56,
                    color: Color(0xFFB9C0CC),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'İzleme için kod girin',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Bildirim alanındaki İzleme butonuna bastığınızda kod otomatik gelir. İsterseniz ürüne ait kodu elle de yazabilirsiniz.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF667085), height: 1.5),
                  ),
                ],
              ),
            )
          else ...[
            _buildTrackingHeroCard(
              storeName: storeName,
              statusTitle: currentStatus,
              productName: productName,
              imageUrl: imageUrl,
              trackingNo: trackingNo,
              orderNo: orderNo,
              deliveryMode: deliveryMode,
              logoUrl: useIbulLogo
                  ? null
                  : ((mergedData['store_logo_url']
                                ?.toString()
                                .trim()
                                .isNotEmpty ??
                            false)
                        ? mergedData['store_logo_url']?.toString()
                        : _storeLogoByName[_normalizeStoreKey(storeName)]),
              forceIbulLogo: useIbulLogo,
            ),
            const SizedBox(height: 16),
            _buildVideoSection(
              videoUrl: videoUrl,
              productName: productName,
              storeName: storeName,
              trackingNo: trackingNo,
              imageUrl: imageUrl,
            ),
            const SizedBox(height: 16),
            _buildLocationSection(
              deliveryMode: deliveryMode,
              cargoCompany: cargoCompany,
              statusTitle: currentStatus,
              locationLabel: locationLabel,
              recipientName: recipientName,
              trackingData: mergedData,
            ),
            const SizedBox(height: 16),
            _buildTrackingStepsSection(steps),
            const SizedBox(height: 16),
            _buildHistorySection(),
          ],
        ],
      ),
    );
  }

  Widget _buildInlineReturnPickupPlanner(Map<String, dynamic> mergedData) {
    final windowStart = _returnWindowStart();
    final windowEnd = _returnWindowEnd();
    final isAlreadyScheduled =
        _normalizeTrackingStatus(_selectedTrackingStatus(mergedData)) ==
        'return_pickup_scheduled';
    final productName = mergedData['product_name']?.toString() ?? 'Ürün';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD9CCFF), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'İade Et: Tarih ve Saat Seç',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isAlreadyScheduled
                ? '$productName için kurye zamanını güncelleyebilirsin.'
                : '$productName için önce kurye alım günü ve saat aralığını seç.',
            style: const TextStyle(fontSize: 12, color: Color(0xFF667085)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSubmittingReturnPickup
                      ? null
                      : _pickInlineReturnDate,
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: Text(
                    '${_returnPickupDate.day.toString().padLeft(2, '0')}.${_returnPickupDate.month.toString().padLeft(2, '0')}.${_returnPickupDate.year}',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSubmittingReturnPickup
                      ? null
                      : _pickInlineReturnStartTime,
                  icon: const Icon(Icons.login_rounded, size: 18),
                  label: Text(
                    'Başlangıç ${_returnPickupStart.hour.toString().padLeft(2, '0')}:${_returnPickupStart.minute.toString().padLeft(2, '0')}',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _isSubmittingReturnPickup
                ? null
                : _pickInlineReturnEndTime,
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: Text(
              'Bitiş ${_returnPickupEnd.hour.toString().padLeft(2, '0')}:${_returnPickupEnd.minute.toString().padLeft(2, '0')}',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Seçilen aralık: ${_formatDateTime(windowStart)} - ${_formatDateTime(windowEnd)}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF667085)),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _returnPickupNoteController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Kurye notu (opsiyonel)',
              hintText: 'Adres tarifi veya ek bilgi',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSubmittingReturnPickup
                  ? null
                  : () => _submitInlineReturnPickup(mergedData),
              icon: _isSubmittingReturnPickup
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.schedule_send_outlined),
              label: Text(
                _isSubmittingReturnPickup
                    ? 'Kaydediliyor...'
                    : isAlreadyScheduled
                    ? 'Kurye Zamanını Güncelle'
                    : 'Kurye Alım Zamanını Onayla',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeLookupCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 2),
          child: Text(
            'KOD',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.primary, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _searchTrackingByCode(),
                  decoration: const InputDecoration(
                    hintText: 'Ürün kodu veya takip no yazın',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 18,
                    ),
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _searchTrackingByCode,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Icon(
                      Icons.send_rounded,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTrackingHeroCard({
    required String storeName,
    required String statusTitle,
    required String productName,
    required String imageUrl,
    required String trackingNo,
    required String orderNo,
    required String deliveryMode,
    String? logoUrl,
    bool forceIbulLogo = false,
  }) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _trackingCardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStoreBadge(
            logoUrl: logoUrl,
            storeName: storeName,
            forceIbulLogo: forceIbulLogo,
            size: 50,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  storeName,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$productName için izleme aktif. $trackingNo kodu ile hareketleri takip edebilirsiniz.',
                  style: const TextStyle(
                    height: 1.45,
                    color: Color(0xFF5C667A),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.start,
                  runAlignment: WrapAlignment.start,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: isMobile ? 6 : 8,
                  runSpacing: isMobile ? 6 : 8,
                  children: [
                    _buildInfoChip(Icons.qr_code_rounded, trackingNo),
                    _buildInfoChip(Icons.receipt_long_outlined, orderNo),
                    _buildInfoChip(Icons.local_shipping_outlined, deliveryMode),
                    _buildInfoChip(Icons.track_changes_rounded, statusTitle),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 84,
              height: 84,
              child: _buildImage(imageUrl),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoSection({
    required String? videoUrl,
    required String productName,
    required String storeName,
    required String trackingNo,
    required String imageUrl,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ÜRÜN VİDEOSU',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: _trackingCardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: videoUrl != null
                      ? VideoPlayerWidget(videoUrl: videoUrl, autoPlay: false)
                      : Container(
                          color: const Color(0xFFF1F3F6),
                          child: const Center(
                            child: Icon(
                              Icons.play_circle_outline_rounded,
                              color: Colors.white,
                              size: 76,
                            ),
                          ),
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      productName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      videoUrl != null
                          ? '$storeName sipariş videosu hazır.'
                          : 'Bu ürün için henüz yüklenmiş video bulunmuyor.',
                      style: const TextStyle(
                        color: Color(0xFF667085),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(
                                  text:
                                      '$storeName - $productName - Kod: $trackingNo',
                                ),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Paylaşım metni kopyalandı.'),
                                ),
                              );
                            },
                            icon: const Icon(Icons.ios_share_outlined),
                            label: const Text('Paylaş'),
                            style: _trackingActionButtonStyle(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AskProductQuestionPage(
                                    product: {
                                      'productName': productName,
                                      'storeName': storeName,
                                      'imageUrl': imageUrl,
                                    },
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.chat_bubble_outline),
                            label: const Text('Soru Sor'),
                            style: _trackingActionButtonStyle(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLocationSection({
    required String deliveryMode,
    required String cargoCompany,
    required String statusTitle,
    required String locationLabel,
    required String recipientName,
    required Map<String, dynamic> trackingData,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Konum',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F4F7),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFDDE4EC)),
          ),
          child: Column(
            children: [
              Container(
                height: 220,
                decoration: BoxDecoration(
                  color: const Color(0xFFE9EEF3),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Stack(
                  children: [
                    const Center(
                      child: Icon(
                        Icons.map_outlined,
                        size: 56,
                        color: Color(0xFFC9D2DD),
                      ),
                    ),
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: 14,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              deliveryMode == 'iHiz'
                                  ? '10 dk (3,3 Km)'
                                  : 'Takip aktif',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              locationLabel,
                              style: const TextStyle(
                                color: Color(0xFF667085),
                                height: 1.45,
                              ),
                            ),
                            if (recipientName.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Teslim alan: $recipientName',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF475467),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),
                            OutlinedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CourierInfoPage(
                                      trackingData: trackingData,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.two_wheeler_outlined),
                              label: const Text('Kurye Bilgi'),
                              style: _trackingActionButtonStyle(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _buildCourierInfoTile(
                      icon: Icons.local_shipping_outlined,
                      title: cargoCompany,
                      subtitle: statusTitle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildCourierInfoTile(
                      icon: Icons.location_on_outlined,
                      title: 'Adres',
                      subtitle: 'Teslimat konumu güncel',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddressesPage()),
                    );
                  },
                  icon: const Icon(Icons.edit_location_alt_outlined),
                  label: const Text('Adres Değiştir'),
                  style: _trackingActionButtonStyle(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTrackingStepsSection(List<_TrackingStep> steps) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _trackingCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sipariş İlerlemesi',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          ...steps.asMap().entries.map((entry) {
            final index = entry.key;
            final step = entry.value;
            final isLast = index == steps.length - 1;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: step.completed
                            ? AppColors.primary
                            : step.active
                            ? const Color(0xFFEDE7FF)
                            : Colors.white,
                        border: Border.all(
                          color: step.completed || step.active
                              ? AppColors.primary
                              : const Color(0xFFD1D5DB),
                          width: 2,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        step.completed ? Icons.check : step.icon,
                        size: 15,
                        color: step.completed
                            ? Colors.white
                            : step.active
                            ? AppColors.primary
                            : Colors.grey,
                      ),
                    ),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 42,
                        color: step.completed
                            ? AppColors.primary
                            : const Color(0xFFE5E7EB),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: step.active || step.completed
                                ? Colors.black87
                                : Colors.black45,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          step.subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHistorySection() {
    final latestHistory = _latestTrackingHistoryItems();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _trackingCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Son Hareketler',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          if (latestHistory.isEmpty)
            const Text(
              'Henüz detaylı hareket eklenmedi.',
              style: TextStyle(color: Color(0xFF667085)),
            )
          else
            ...latestHistory.map((entry) {
              final description = entry['description']?.toString() ?? '';
              if (description.startsWith('VIDEO::') ||
                  description.startsWith('VIDEO_REMOVED::')) {
                return const SizedBox.shrink();
              }
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry['title']?.toString().isNotEmpty == true
                                ? entry['title'].toString()
                                : _trackingStatusTitle(
                                    entry['status']?.toString() ?? '',
                                  ),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            description.isNotEmpty
                                ? description
                                : 'Durum güncellendi.',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF667085),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _formatNotificationTime(entry['created_at']?.toString()),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF98A2B3),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildMessagesTab(List<Map<String, dynamic>> messages) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final msg = messages[index];
        return GestureDetector(
          onTap: () {
            final seller = <String, dynamic>{
              'id': msg['sellerId'],
              'name': msg['sellerName'] ?? 'Mağaza',
              'logo': msg['sellerLogo'],
            };
            final product = <String, dynamic>{
              'name': msg['productTitle'] ?? msg['productName'],
              'image': msg['productImage'],
            };
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatPage(seller: seller, product: product),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 60,
                    height: 60,
                    child: _buildImage(msg['productImage']),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        msg['productTitle'],
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        msg['sellerName'] ?? 'Satıcı',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        msg['question'] ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            msg['status'],
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: msg['statusColor'],
                            ),
                          ),
                          Text(
                            msg['timestamp'] ?? '',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStoreBadge({
    String? logoUrl,
    required String storeName,
    bool forceIbulLogo = false,
    double size = 56,
  }) {
    final firstLetter = storeName.isNotEmpty ? storeName[0].toUpperCase() : 'M';
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: Container(
        width: size,
        height: size,
        color: const Color(0xFFF4F3FF),
        child: forceIbulLogo
            ? Image.asset(
                _ibulLogoAsset,
                fit: BoxFit.cover,
                errorBuilder: (_, error, stackTrace) => Center(
                  child: Text(
                    firstLetter,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              )
            : (logoUrl?.isNotEmpty ?? false)
            ? OptimizedImage(imageUrlOrPath: 
                logoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, error, stackTrace) => Center(
                  child: Text(
                    firstLetter,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              )
            : Center(
                child: Text(
                  firstLetter,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
      ),
    );
  }

  Map<String, dynamic> _notificationData(Map<String, dynamic> notification) {
    final raw = notification['data'];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return raw.map((key, value) => MapEntry('$key', value));
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _visibleNotifications() {
    if (_notifications.isEmpty) return const <Map<String, dynamic>>[];
    final filtered = _notifications
        .where((notification) {
          final data = _notificationData(notification);
          final type = data['type']?.toString().trim().toLowerCase() ?? '';
          // Itiraz gönderildi kartını ayrı tekrar göstermiyoruz; iptal kartı
          // aynı siparişte "İtiraz Edildi" durumuna geçiyor.
          if (type == 'cancel_appeal_submitted') return false;
          return _isImportantNotification(notification);
        })
        .toList(growable: false);

    return filtered;
  }

  bool _isImportantNotification(Map<String, dynamic> notification) {
    final data = _notificationData(notification);
    final type = data['type']?.toString().trim().toLowerCase() ?? '';
    final status = _normalizeTrackingStatus(data['status']?.toString());

    if (type == 'cancel_appeal_submitted' ||
        type == 'cancel_appeal_status_updated') {
      return true;
    }
    if (type == 'order_tracking') {
      return status == 'shipped' ||
          status == 'out_for_delivery' ||
          status == 'cancelled' ||
          status == 'delivered' ||
          status == 'returned' ||
          status == 'refunded';
    }
    if (_isReturnTrackingStatus(status) || _shouldShowReturnAction(data)) {
      return true;
    }
    return false;
  }

  String _preferredLookupCode({
    required Map<String, dynamic> notificationData,
    required Map<String, dynamic> snapshot,
  }) {
    final snapshotCode = snapshot['lookup_code']?.toString().trim() ?? '';
    if (snapshotCode.isNotEmpty) return snapshotCode;

    final productCode =
        notificationData['product_code']?.toString().trim() ?? '';
    if (productCode.isNotEmpty) return productCode;

    final trackingNumber =
        notificationData['tracking_number']?.toString().trim() ?? '';
    if (trackingNumber.isNotEmpty) return trackingNumber;

    final fromBody = _extractCodeFromText(
      _selectedTrackingNotification?['body']?.toString() ?? '',
    );
    if (fromBody.isNotEmpty) return fromBody;

    return notificationData['order_id']?.toString() ?? '';
  }

  String _notificationTitle(Map<String, dynamic> notification) {
    final value = notification['title']?.toString().trim() ?? '';
    return value.isEmpty ? 'Mağaza' : value;
  }

  String _notificationCardDescription({
    required Map<String, dynamic> notification,
    required Map<String, dynamic> data,
    required bool isReturnAction,
    required bool isCancelAppealAction,
    required bool isAppealedCancel,
    required bool isCancelAppealInfo,
  }) {
    final body = notification['body']?.toString().trim() ?? '';
    if (isAppealedCancel) {
      const suffix =
          'İtiraz gönderildi. Yazdığınız açıklamayı görmek için "İtiraz Edildi"ye dokun.';
      return body.isEmpty ? suffix : '$body\n$suffix';
    }
    if (isCancelAppealInfo) {
      const suffix =
          'Gönderdiğiniz itirazın detayını görmek için "Detay"a dokun.';
      return body.isEmpty ? suffix : '$body\n$suffix';
    }
    if (isCancelAppealAction) {
      const suffix =
          'İptal kararına itiraz etmek ve yeniden sipariş talebi göndermek için "İtiraz Et"e dokun.';
      return body.isEmpty ? suffix : '$body\n$suffix';
    }
    if (!isReturnAction) return body;

    final status = _normalizeTrackingStatus(data['status']?.toString());
    if (status == 'return_approved') {
      final suffix = 'İade için gün/saat seçmek üzere "İade Et"e dokun.';
      return body.isEmpty ? suffix : '$body\n$suffix';
    }
    if (status == 'return_pickup_scheduled') {
      final suffix =
          'Gerekirse iade kurye saatini "İade Et" ile güncelleyebilirsin.';
      return body.isEmpty ? suffix : '$body\n$suffix';
    }
    final fallback = 'İade akışını tamamlamak için "İade Et"e dokun.';
    return body.isEmpty ? fallback : '$body\n$fallback';
  }

  List<Map<String, dynamic>> _latestTrackingHistoryItems() {
    if (_selectedTrackingHistory.isEmpty) return const <Map<String, dynamic>>[];

    var filtered = _selectedTrackingHistory.where((entry) {
      final description = entry['description']?.toString() ?? '';
      return !description.startsWith('VIDEO::') &&
          !description.startsWith('VIDEO_REMOVED::');
    }).toList();

    final selectedNotification = _selectedTrackingNotification;
    if (selectedNotification != null) {
      final notificationData = _notificationData(selectedNotification);
      final type =
          notificationData['type']?.toString().trim().toLowerCase() ?? '';
      final openedFromReturnAction = _shouldShowReturnAction(notificationData);
      if (type == 'order_tracking' && !openedFromReturnAction) {
        filtered = filtered.where((entry) {
          final status = _normalizeTrackingStatus(entry['status']?.toString());
          return !_isReturnTrackingStatus(status);
        }).toList();
      }
    }

    if (filtered.isEmpty) return const <Map<String, dynamic>>[];
    return [filtered.last];
  }

  String _selectedTrackingStatus(
    Map<String, dynamic> data, {
    Map<String, dynamic>? sourceNotificationData,
  }) {
    final notificationData =
        sourceNotificationData ??
        (_selectedTrackingNotification == null
            ? null
            : _notificationData(_selectedTrackingNotification!));
    final notificationType =
        notificationData?['type']?.toString().trim().toLowerCase() ?? '';
    final notificationStatus = _normalizeTrackingStatus(
      notificationData?['status']?.toString(),
    );
    final openedFromReturnAction =
        notificationData != null && _shouldShowReturnAction(notificationData);
    if (!openedFromReturnAction &&
        notificationType == 'order_tracking' &&
        notificationStatus.isNotEmpty) {
      return notificationStatus;
    }

    final fromData = _normalizeTrackingStatus(data['status']?.toString());
    final fromShipment = _normalizeTrackingStatus(
      data['shipment_step']?.toString(),
    );
    final fromHistory = _selectedTrackingHistory.isNotEmpty
        ? _normalizeTrackingStatus(
            _selectedTrackingHistory.last['status']?.toString(),
          )
        : '';
    final hasReturnSignal =
        _isReturnTrackingStatus(fromData) ||
        _isReturnTrackingStatus(fromShipment) ||
        _isReturnTrackingStatus(fromHistory);
    if (hasReturnSignal) {
      if (fromHistory.isNotEmpty) return fromHistory;
      if (fromShipment.isNotEmpty) return fromShipment;
      if (fromData.isNotEmpty) return fromData;
    }
    if (fromData.isNotEmpty) return fromData;
    if (fromShipment.isNotEmpty) return fromShipment;
    if (fromHistory.isNotEmpty) return fromHistory;
    return 'confirmed';
  }

  String? _extractTrackingVideoUrl(List<Map<String, dynamic>> rows) {
    for (final row in rows.reversed) {
      final description = row['description']?.toString() ?? '';
      if (description.startsWith('VIDEO_REMOVED::')) {
        return null;
      }
      if (description.startsWith('VIDEO::')) {
        final payload = description.replaceFirst('VIDEO::', '').trim();
        final url = payload.split('|TRIM:').first.trim();
        if (url.isNotEmpty) return url;
      }
    }
    return null;
  }

  String _extractCodeFromText(String text) {
    final matches = RegExp(r'[A-Za-z0-9-]{3,}').allMatches(text);
    if (matches.isEmpty) return '';
    return matches.last.group(0)?.trim() ?? '';
  }

  List<_TrackingStep> _buildTrackingSteps(String status) {
    final normalizedStatus = _normalizeTrackingStatus(status);
    if (_isReturnTrackingStatus(normalizedStatus)) {
      final activeIndex = switch (normalizedStatus) {
        'return_pickup_scheduled' => 1,
        'return_shipped_back' ||
        'return_received' ||
        'returned' ||
        'refunded' => 2,
        _ => 0,
      };
      return [
        _TrackingStep(
          'İade Başlatıldı',
          'İade talebiniz oluşturuldu ve satıcı/İBUL incelemesine alındı.',
          Icons.assignment_return_outlined,
          activeIndex >= 0,
          activeIndex == 0,
        ),
        _TrackingStep(
          'Kurye Çağırıldı',
          'Seçtiğiniz gün ve saat aralığında kurye alımı planlandı.',
          Icons.local_shipping_outlined,
          activeIndex >= 1,
          activeIndex == 1,
        ),
        _TrackingStep(
          'Ürün Satıcıya İade Edildi',
          'İade ürünü satıcıya ulaştı ve süreç sonuçlandırılıyor.',
          Icons.check_circle_outline,
          activeIndex >= 2,
          activeIndex == 2,
        ),
      ];
    }

    if (normalizedStatus == 'cancelled') {
      return const [
        _TrackingStep(
          'Siparişiniz Alındı',
          'Ödeme ve sipariş kaydı başarıyla oluşturuldu.',
          Icons.receipt_long,
          true,
          false,
        ),
        _TrackingStep(
          'Sipariş İptal Edildi',
          'Kurye bildirilen sebeple teslimatı iptal etti.',
          Icons.cancel_outlined,
          true,
          true,
        ),
      ];
    }

    const order = [
      'confirmed',
      'preparing',
      'shipped',
      'transfer',
      'branch',
      'out_for_delivery',
      'delivered',
    ];
    final activeIndex = order
        .indexOf(normalizedStatus)
        .clamp(0, order.length - 1);
    return [
      _TrackingStep(
        'Siparişiniz Alındı',
        'Ödeme ve sipariş kaydı başarıyla oluşturuldu.',
        Icons.receipt_long,
        activeIndex >= 0,
        activeIndex == 0,
      ),
      _TrackingStep(
        'Hazırlanıyor',
        'Satıcı siparişi hazırlıyor ve paketliyor.',
        Icons.inventory_2_outlined,
        activeIndex >= 1,
        activeIndex == 1,
      ),
      _TrackingStep(
        'Kargoya Verildi',
        'Paket teslimat operasyonuna teslim edildi.',
        Icons.local_shipping_outlined,
        activeIndex >= 2,
        activeIndex == 2,
      ),
      _TrackingStep(
        'Transfer Aşamasında',
        'Paket transfer merkezinde hareket ediyor.',
        Icons.compare_arrows_outlined,
        activeIndex >= 3,
        activeIndex == 3,
      ),
      _TrackingStep(
        'Şubede',
        'Paket teslimat şubesine ulaştı.',
        Icons.store_mall_directory_outlined,
        activeIndex >= 4,
        activeIndex == 4,
      ),
      _TrackingStep(
        'Dağıtıma Çıktı',
        'Kurye paketi teslimat adresine getiriyor.',
        Icons.delivery_dining_outlined,
        activeIndex >= 5,
        activeIndex == 5,
      ),
      _TrackingStep(
        'Teslim Edildi',
        'Siparişiniz teslim edildi.',
        Icons.check_circle_outline,
        activeIndex >= 6,
        activeIndex == 6,
      ),
    ];
  }

  String _trackingStatusTitle(String status) {
    switch (_normalizeTrackingStatus(status)) {
      case 'confirmed':
      case 'new':
        return 'Siparişiniz Alındı';
      case 'preparing':
        return 'Siparişiniz Hazırlanıyor';
      case 'ready_to_ship':
        return 'Sipariş Hazırlandı';
      case 'shipped':
        return 'Siparişiniz Kargoya Verildi';
      case 'transfer':
        return 'Kargo Transfer Aşamasında';
      case 'branch':
        return 'Kargo Şubede';
      case 'out_for_delivery':
        return 'Dağıtıma Çıktı';
      case 'cancelled':
        return 'Sipariş İptal Edildi';
      case 'delivered':
        return 'Sipariş Teslim Edildi';
      case 'return_requested':
      case 'pending_seller_review':
      case 'awaiting_ibul_review':
      case 'reported_to_ibul':
        return 'İade Başlatıldı';
      case 'return_approved':
        return 'İade Onaylandı';
      case 'return_pickup_scheduled':
        return 'Kurye Çağırıldı';
      case 'return_shipped_back':
        return 'İade Ürünü Satıcıya Gidiyor';
      case 'return_received':
      case 'returned':
      case 'refunded':
        return 'Ürün Satıcıya İade Edildi';
      case 'cancelled_by_ibul':
      case 'seller_rejected':
      case 'closed_by_ibul':
        return 'İade Reddedildi';
      default:
        return 'Sipariş Güncellendi';
    }
  }

  bool _shouldShowReturnAction(Map<String, dynamic> data) {
    final status = _normalizeTrackingStatus(data['status']?.toString());
    if (_isReturnRejectedStatus(status)) return false;
    var shouldShow = _isReturnPickupEligibleStatus(status);
    if (!shouldShow) {
      final type = data['type']?.toString().trim().toLowerCase() ?? '';
      final decision = data['decision']?.toString().trim().toLowerCase() ?? '';
      shouldShow = type == 'return_reviewed' && decision == 'approved';
    }
    if (!shouldShow) return false;
    final deliveryType = data['delivery_type']?.toString().trim() ?? '';
    if (deliveryType.isEmpty) return true;
    return _isNearDistanceDeliveryType(deliveryType);
  }

  bool _isReturnPickupEligibleStatus(String status) {
    final normalized = _normalizeTrackingStatus(status);
    return normalized == 'return_approved' ||
        normalized == 'return_pickup_scheduled';
  }

  bool _isReturnRejectedStatus(String status) {
    final normalized = _normalizeTrackingStatus(status);
    return normalized == 'cancelled_by_ibul' ||
        normalized == 'seller_rejected' ||
        normalized == 'closed_by_ibul';
  }

  bool _isReturnTrackingStatus(String status) {
    final normalized = _normalizeTrackingStatus(status);
    switch (normalized) {
      case 'return_requested':
      case 'pending_seller_review':
      case 'awaiting_ibul_review':
      case 'reported_to_ibul':
      case 'return_approved':
      case 'return_pickup_scheduled':
      case 'return_shipped_back':
      case 'return_received':
      case 'returned':
      case 'refunded':
      case 'cancelled_by_ibul':
      case 'seller_rejected':
      case 'closed_by_ibul':
        return true;
      default:
        return false;
    }
  }

  bool _isInTransitTrackingStatus(String status) {
    switch (_normalizeTrackingStatus(status)) {
      case 'shipped':
      case 'transfer':
      case 'branch':
      case 'out_for_delivery':
        return true;
      default:
        return false;
    }
  }

  bool _isCancelAppealAction(Map<String, dynamic> data) {
    final type = data['type']?.toString().trim().toLowerCase() ?? '';
    if (type != 'order_tracking') return false;
    return _normalizeTrackingStatus(data['status']?.toString()) == 'cancelled';
  }

  bool _isCancelAppealSubmittedInfo(Map<String, dynamic> data) {
    final type = data['type']?.toString().trim().toLowerCase() ?? '';
    return type == 'cancel_appeal_submitted' ||
        type == 'cancel_appeal_status_updated';
  }

  String _cancelAppealLookupKey(Map<String, dynamic> data) {
    for (final key in const ['order_item_id', 'order_id', 'tracking_number']) {
      final value = data[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  DateTime _notificationCreatedAt(Map<String, dynamic> row) {
    final parsed = DateTime.tryParse(row['created_at']?.toString() ?? '');
    return parsed?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  Map<String, Map<String, dynamic>> _latestCancelAppealsByLookupKey() {
    final result = <String, Map<String, dynamic>>{};
    for (final notification in _notifications) {
      final data = _notificationData(notification);
      if (!_isCancelAppealSubmittedInfo(data)) continue;
      final key = _cancelAppealLookupKey(data);
      if (key.isEmpty) continue;
      final existing = result[key];
      if (existing == null ||
          _notificationCreatedAt(
            notification,
          ).isAfter(_notificationCreatedAt(existing))) {
        result[key] = notification;
      }
    }
    return result;
  }

  Map<String, dynamic>? _findLinkedAppealDataForCancelled({
    required Map<String, dynamic> cancelledData,
    required Map<String, Map<String, dynamic>> appealByLookupKey,
  }) {
    for (final keyName in const [
      'order_item_id',
      'order_id',
      'tracking_number',
    ]) {
      final key = cancelledData[keyName]?.toString().trim() ?? '';
      if (key.isEmpty) continue;
      final notification = appealByLookupKey[key];
      if (notification == null) continue;
      return _notificationData(notification);
    }
    return null;
  }

  String _normalizeTrackingStatus(String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    switch (normalized) {
      case 'awaiting_customer_pickup_slot':
        return 'return_approved';
      case 'pickup_scheduled':
        return 'return_pickup_scheduled';
      default:
        return normalized;
    }
  }

  bool _isNearDistanceDeliveryType(String rawType) {
    final normalized = rawType.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    return normalized.contains('near') ||
        normalized.contains('yakin') ||
        normalized.contains('yakın') ||
        normalized.contains('local') ||
        normalized.contains('ihiz') ||
        normalized.contains('kurye');
  }

  bool _canUseInlineReturnPlanner(
    Map<String, dynamic> data,
    String trackingStatus,
  ) {
    if (!_isReturnPickupEligibleStatus(trackingStatus)) return false;
    final deliveryType = data['delivery_type']?.toString().trim() ?? '';
    if (deliveryType.isNotEmpty) {
      return _isNearDistanceDeliveryType(deliveryType);
    }
    final deliveryMode =
        data['delivery_mode']?.toString().trim().toLowerCase() ?? '';
    final cargoCompany =
        data['cargo_company']?.toString().trim().toLowerCase() ?? '';
    if (deliveryMode == 'courier') return true;
    return cargoCompany.contains('ihiz') || cargoCompany.contains('ihız');
  }

  String _deliveryModeLabel(String? deliveryMode, String cargoCompany) {
    switch ((deliveryMode ?? '').toLowerCase()) {
      case 'courier':
        return 'iHiz';
      case 'branch_ihiz_pool':
        return 'iHiz Kargo Teslim';
      case 'branch_self_dropoff':
        return '$cargoCompany sube teslim';
      case 'branch_company_pickup':
        return '$cargoCompany adresten alim';
      case 'branch':
        return cargoCompany;
      default:
        return cargoCompany;
    }
  }

  String _formatNotificationTime(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    final parsed = DateTime.tryParse(raw)?.toLocal();
    if (parsed == null) return raw;
    final now = DateTime.now();
    final difference = now.difference(parsed);
    if (difference.inMinutes < 1) return 'şimdi';
    if (difference.inHours < 1) return '${difference.inMinutes} dk';
    if (difference.inDays < 1) {
      final hour = parsed.hour.toString().padLeft(2, '0');
      final minute = parsed.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }
    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    return '$day/$month/${parsed.year}';
  }

  String _formatDateTime(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year;
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$day.$month.$year $hour:$minute';
  }

  String _bestLocationLabel(Map<String, dynamic> data) {
    final storeAddress = data['store_address']?.toString().trim() ?? '';
    if (storeAddress.isNotEmpty) return storeAddress;

    final deliveryAddress =
        data['delivery_address_text']?.toString().trim() ?? '';
    if (deliveryAddress.isNotEmpty) return deliveryAddress;

    final hasCoordinates =
        data['store_lat'] != null && data['store_lng'] != null;
    if (hasCoordinates) {
      return 'Mağaza konumu haritada hazır. Kurye hareketleri bu rota üzerinden izlenebilir.';
    }

    return 'Konum bilgisi hazırlanıyor. Kurye bilgi alanından son teslimat durumunu görebilirsiniz.';
  }

  BoxDecoration _trackingCardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE7EAF0)),
    );
  }

  ButtonStyle _trackingActionButtonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: Colors.black87,
      side: BorderSide(color: Colors.grey.shade300),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      backgroundColor: Colors.white,
    );
  }

  Widget _buildCourierInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String value) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(String imageUrl) {
    if (imageUrl.isEmpty) {
      return Container(
        color: const Color(0xFFF3F4F6),
        child: const Icon(Icons.image_outlined, color: Color(0xFFB7BDC8)),
      );
    }
    if (imageUrl.startsWith('http')) {
      return OptimizedImage(imageUrlOrPath: 
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          color: const Color(0xFFF3F4F6),
          child: const Icon(Icons.image_outlined, color: Color(0xFFB7BDC8)),
        ),
      );
    }
    return Image.asset(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        color: const Color(0xFFF3F4F6),
        child: const Icon(Icons.image_outlined, color: Color(0xFFB7BDC8)),
      ),
    );
  }
}

class _TrackingStep {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool completed;
  final bool active;

  const _TrackingStep(
    this.title,
    this.subtitle,
    this.icon,
    this.completed,
    this.active,
  );
}
