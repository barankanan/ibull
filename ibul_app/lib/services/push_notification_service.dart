import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM background message: ${json.encode(message.data)}');
}

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  FirebaseMessaging? _messaging;
  final SupabaseClient _supabase = Supabase.instance.client;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static const String _nearbyStoreCategoryId = 'nearby_store';
  static const String _nearbyStoreActionId = 'review_store';
  static const String _nearbyStoreChannelId = 'ibul_nearby_store_channel';
  static const String _nearbyStoreChannelName = 'IBUL Nearby Stores';

  GlobalKey<NavigatorState>? _navigatorKey;
  bool _initialized = false;
  bool _localNotificationsInitialized = false;
  bool _timezonesInitialized = false;

  FirebaseMessaging get _messagingClient {
    return _messaging ??= FirebaseMessaging.instance;
  }

  Future<void> _ensureFirebaseReady() async {
    if (kIsWeb) return;
    if (Firebase.apps.isNotEmpty) return;

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  Future<void> initialize({
    required GlobalKey<NavigatorState> navigatorKey,
  }) async {
    if (_initialized) return;
    _navigatorKey = navigatorKey;

    try {
      await _ensureFirebaseReady();

      if (kIsWeb) {
        final supported = await _messagingClient.isSupported();
        if (!supported) {
          debugPrint(
            'Push notifications are not supported on this web runtime.',
          );
          _initialized = true;
          return;
        }
      } else {
        await _messagingClient.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        await _messagingClient.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
        await _initializeLocalNotifications();
      }
    } catch (error) {
      debugPrint('Push notification support check failed: $error');
      _initialized = true;
      return;
    }

    if (!kIsWeb) {
      try {
        await _syncFcmToken();
      } catch (error) {
        debugPrint('FCM token sync skipped: $error');
      }
    }

    _messagingClient.onTokenRefresh.listen((token) async {
      try {
        await _upsertDeviceToken(token);
      } catch (error) {
        debugPrint('FCM token refresh handling failed: $error');
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      try {
        _handleMessageNavigation(message);
      } catch (error) {
        debugPrint('Push open handling failed: $error');
      }
    });

    FirebaseMessaging.onMessage.listen((message) async {
      try {
        await _showForegroundSystemNotification(message);
      } catch (error) {
        debugPrint('Foreground push rendering failed: $error');
      }
    });

    try {
      final initialMessage = await _messagingClient.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageNavigation(initialMessage);
      }
    } catch (error) {
      debugPrint('Initial push message lookup failed: $error');
    }

    _initialized = true;
  }

  Future<void> syncUserInterests({
    required List<String> searchHistory,
    required List<String> favoriteTerms,
    required List<String> cartTerms,
    required List<String> savedListTerms,
  }) async {
    if (kIsWeb) return;

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final terms = <Map<String, dynamic>>[];
    for (final s in searchHistory.take(30)) {
      final term = s.trim();
      if (term.isNotEmpty) {
        terms.add({
          'user_id': userId,
          'interest_type': 'searched',
          'term': term,
        });
      }
    }
    for (final s in favoriteTerms.take(30)) {
      final term = s.trim();
      if (term.isNotEmpty) {
        terms.add({
          'user_id': userId,
          'interest_type': 'favorite',
          'term': term,
        });
      }
    }
    for (final s in cartTerms.take(30)) {
      final term = s.trim();
      if (term.isNotEmpty) {
        terms.add({'user_id': userId, 'interest_type': 'cart', 'term': term});
      }
    }
    for (final s in savedListTerms.take(50)) {
      final term = s.trim();
      if (term.isNotEmpty) {
        terms.add({'user_id': userId, 'interest_type': 'saved', 'term': term});
      }
    }

    if (terms.isEmpty) return;

    await _supabase
        .from('user_product_interests')
        .delete()
        .eq('user_id', userId);
    await _supabase.from('user_product_interests').insert(terms);
  }

  Future<void> syncUserLocation({
    required double latitude,
    required double longitude,
  }) async {
    if (kIsWeb) return;

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    await _supabase.from('user_live_locations').upsert({
      'user_id': userId,
      'latitude': latitude,
      'longitude': longitude,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> _syncFcmToken() async {
    final token = await _messagingClient.getToken();
    if (token == null || token.isEmpty) return;
    await _upsertDeviceToken(token);
  }

  Future<void> _upsertDeviceToken(String token) async {
    final userId = _supabase.auth.currentUser?.id;
    await _supabase.from('push_device_tokens').upsert({
      'token': token,
      'user_id': userId,
      'platform': defaultTargetPlatform.name,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'is_active': true,
    }, onConflict: 'token');
  }

  Future<void> _initializeLocalNotifications() async {
    if (kIsWeb || _localNotificationsInitialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    final iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      notificationCategories: <DarwinNotificationCategory>[
        DarwinNotificationCategory(
          _nearbyStoreCategoryId,
          actions: <DarwinNotificationAction>[
            DarwinNotificationAction.plain(
              _nearbyStoreActionId,
              'Mağazayı İncele',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
          ],
        ),
      ],
    );

    await _localNotifications.initialize(
      InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.trim().isEmpty) return;
        try {
          _navigateFromNotificationPayload(
            Map<String, dynamic>.from(json.decode(payload) as Map),
          );
        } catch (error) {
          debugPrint('Local notification payload parse failed: $error');
        }
      },
    );

    const channel = AndroidNotificationChannel(
      _nearbyStoreChannelId,
      _nearbyStoreChannelName,
      description: 'Yakin magazalardaki ilgini ceken urun bildirimleri.',
      importance: Importance.max,
      playSound: true,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    _localNotificationsInitialized = true;
  }

  void _ensureTimezoneDataInitialized() {
    if (_timezonesInitialized) return;
    tz.initializeTimeZones();
    _timezonesInitialized = true;
  }

  bool _isNotificationAuthorized(NotificationSettings settings) {
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  Future<bool> ensureNotificationPermission({
    bool promptIfNeeded = true,
  }) async {
    if (kIsWeb) return false;

    await _ensureFirebaseReady();
    await _initializeLocalNotifications();

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      var settings = await _messagingClient.getNotificationSettings();
      if (_isNotificationAuthorized(settings)) {
        return true;
      }
      if (!promptIfNeeded) {
        return false;
      }

      settings = await _messagingClient.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      return _isNotificationAuthorized(settings);
    }

    return true;
  }

  Future<bool> showNearbyStoreNotification({
    required String storeName,
    required String body,
    String? initialStoreProductQuery,
  }) async {
    if (kIsWeb) return false;

    final trimmedStoreName = storeName.trim();
    final trimmedBody = body.trim();
    final trimmedQuery = initialStoreProductQuery?.trim();
    if (trimmedStoreName.isEmpty || trimmedBody.isEmpty) return false;

    final permissionGranted = await ensureNotificationPermission();
    if (!permissionGranted) {
      return false;
    }

    final payload = json.encode({
      'storeName': trimmedStoreName,
      if (trimmedQuery != null && trimmedQuery.isNotEmpty)
        'initialStoreProductQuery': trimmedQuery,
    });

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _nearbyStoreChannelId,
        _nearbyStoreChannelName,
        channelDescription:
            'Yakin magazalardaki ilgini ceken urun bildirimleri.',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        ticker: 'IBUL yakındaki mağazayı buldu',
        icon: '@mipmap/ic_launcher',
        largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(
            _nearbyStoreActionId,
            'Mağazayı İncele',
            cancelNotification: true,
            showsUserInterface: true,
          ),
        ],
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        presentBanner: true,
        presentList: true,
        categoryIdentifier: _nearbyStoreCategoryId,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );

    await _localNotifications.show(
      DateTime.now().microsecondsSinceEpoch.remainder(1 << 31),
      trimmedStoreName,
      trimmedBody,
      details,
      payload: payload,
    );

    return true;
  }

  Future<bool> scheduleNearbyStoreNotification({
    required String storeName,
    required String body,
    String? initialStoreProductQuery,
    int delaySeconds = 3,
  }) async {
    if (kIsWeb) return false;

    final trimmedStoreName = storeName.trim();
    final trimmedBody = body.trim();
    final trimmedQuery = initialStoreProductQuery?.trim();
    if (trimmedStoreName.isEmpty || trimmedBody.isEmpty) return false;

    final permissionGranted = await ensureNotificationPermission();
    if (!permissionGranted) {
      return false;
    }

    _ensureTimezoneDataInitialized();

    final payload = json.encode({
      'storeName': trimmedStoreName,
      if (trimmedQuery != null && trimmedQuery.isNotEmpty)
        'initialStoreProductQuery': trimmedQuery,
    });

    final scheduledAt = tz.TZDateTime.now(
      tz.local,
    ).add(Duration(seconds: delaySeconds));

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _nearbyStoreChannelId,
        _nearbyStoreChannelName,
        channelDescription:
            'Yakin magazalardaki ilgini ceken urun bildirimleri.',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        ticker: 'IBUL yakındaki mağazayı buldu',
        icon: '@mipmap/ic_launcher',
        largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(
            _nearbyStoreActionId,
            'Mağazayı İncele',
            cancelNotification: true,
            showsUserInterface: true,
          ),
        ],
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        presentBanner: true,
        presentList: true,
        categoryIdentifier: _nearbyStoreCategoryId,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );

    await _localNotifications.zonedSchedule(
      DateTime.now().microsecondsSinceEpoch.remainder(1 << 31),
      trimmedStoreName,
      trimmedBody,
      scheduledAt,
      details,
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    return true;
  }

  Future<bool> showNearbyStoreNotificationAfterDelay({
    required String storeName,
    required String body,
    String? initialStoreProductQuery,
    int delaySeconds = 3,
  }) async {
    if (kIsWeb) return false;

    final permissionGranted = await ensureNotificationPermission();
    if (!permissionGranted) {
      return false;
    }

    await Future<void>.delayed(Duration(seconds: delaySeconds));

    return showNearbyStoreNotification(
      storeName: storeName,
      body: body,
      initialStoreProductQuery: initialStoreProductQuery,
    );
  }

  Future<void> _showForegroundSystemNotification(RemoteMessage message) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    final data = message.data;
    final storeName =
        data['storeName']?.toString().trim() ??
        message.notification?.title?.trim() ??
        '';
    final body =
        message.notification?.body?.trim() ?? _buildFallbackBodyFromData(data);
    if (storeName.isEmpty || body.isEmpty) return;

    await _initializeLocalNotifications();

    final payload = json.encode({
      'storeName': storeName,
      if (data['initialStoreProductQuery'] != null)
        'initialStoreProductQuery': data['initialStoreProductQuery'].toString(),
      if (data['term'] != null && data['initialStoreProductQuery'] == null)
        'initialStoreProductQuery': data['term'].toString(),
    });

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _nearbyStoreChannelId,
        _nearbyStoreChannelName,
        channelDescription:
            'Yakin magazalardaki ilgini ceken urun bildirimleri.',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        ticker: 'IBUL yakındaki mağazayı buldu',
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(
            _nearbyStoreActionId,
            'Mağazayı İncele',
            cancelNotification: true,
            showsUserInterface: true,
          ),
        ],
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        presentBanner: true,
        presentList: true,
        categoryIdentifier: _nearbyStoreCategoryId,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );

    await _localNotifications.show(
      DateTime.now().microsecondsSinceEpoch.remainder(1 << 31),
      storeName,
      body,
      details,
      payload: payload,
    );
  }

  String _buildFallbackBodyFromData(Map<String, dynamic> data) {
    final storeName = data['storeName']?.toString().trim() ?? '';
    final term =
        data['initialStoreProductQuery']?.toString().trim() ??
        data['term']?.toString().trim() ??
        '';
    final type = data['interestType']?.toString().trim() ?? 'searched';
    if (storeName.isEmpty || term.isEmpty) return '';

    String intro = 'Aradığın';
    if (type == 'favorite') {
      intro = 'Beğendiğin';
    } else if (type == 'cart') {
      intro = 'Sepete eklediğin';
    } else if (type == 'saved') {
      intro = 'Kaydettiğin';
    }
    return "$intro ürün '$term', '$storeName' mağazasında mevcut. Görmek ister misin?";
  }

  void _handleMessageNavigation(RemoteMessage message) {
    _navigateFromNotificationPayload(message.data);
  }

  void _navigateFromNotificationPayload(Map<String, dynamic> data) {
    final storeName = data['storeName']?.toString().trim();
    if (storeName == null || storeName.isEmpty) return;
    final productQuery =
        data['initialStoreProductQuery']?.toString().trim().isNotEmpty == true
        ? data['initialStoreProductQuery'].toString().trim()
        : data['term']?.toString().trim();
    final navigator = _navigatorKey?.currentState;
    if (navigator == null) return;
    navigator.pushNamed(
      '/map',
      arguments: {
        'targetStoreName': storeName,
        if (productQuery != null && productQuery.trim().isNotEmpty)
          'initialStoreProductQuery': productQuery.trim(),
      },
    );
  }
}
