import 'dart:async';

import 'package:flutter/material.dart';

import '../features/seller/panel/helpers/restaurant_printer_eligibility.dart';
import '../services/printer_repository.dart';
import '../services/restaurant_offline/restaurant_connectivity_service.dart';
import 'package:ibul_app/services/print_service_start_gate.dart';
import '../services/restaurant_offline/restaurant_lan_host.dart';
import '../services/restaurant_offline/restaurant_local_cache_service.dart';
import '../services/restaurant_offline/restaurant_offline_models.dart';
import '../services/restaurant_offline/restaurant_offline_sync_service.dart';

String waiterConnectionLabel({
  required bool internet,
  required bool localServerListening,
  required bool printerReady,
  required int pendingSync,
}) {
  if (!internet && !localServerListening) {
    return 'Yerel sipariş merkezi kullanılamıyor';
  }
  if (internet && pendingSync > 0) return 'Senkronize ediliyor...';
  if (internet) return 'Çevrimiçi';
  if (localServerListening) {
    return printerReady
        ? 'Çevrimdışı — Yerel sistem aktif'
        : 'Çevrimdışı — Yerel sistem aktif';
  }
  return 'Yerel sipariş merkezi kullanılamıyor';
}

/// "Online" is a cloud fact. It says nothing about printers, so the waiter
/// banner states the printer fact separately instead of looking fully ready.
/// [savedPrinters] is null while unknown; unknown never raises an alarm.
String? waiterPrinterNotice({required int? savedPrinters}) {
  if (savedPrinters == null || savedPrinters > 0) return null;
  return 'Yazıcı eklenmedi — Mutfak ve adisyon fişleri basılamaz.';
}

/// The saved-printer count the banner may trust. The database is the source of
/// truth; the offline cache is a fallback for when it cannot be read. A cache
/// that holds no printers proves nothing (it may simply never have been
/// filled), so it never produces the "no printer" alarm on its own.
int? resolveSavedPrinterCount({int? remoteCount, int? cachedCount}) {
  if (remoteCount != null) return remoteCount;
  if (cachedCount != null && cachedCount > 0) return cachedCount;
  return null;
}

/// First line of the banner while the cloud is reachable. Orders that have not
/// reached the cloud yet are not "all good", so it is never a plain
/// "Çevrimiçi" then.
String waiterCloudLine({required int pendingSync}) => pendingSync > 0
    ? 'Bulut bağlı — $pendingSync yerel sipariş henüz eşitlenmedi.'
    : 'Çevrimiçi';

class RestaurantOfflineBanner extends StatefulWidget {
  const RestaurantOfflineBanner({
    super.key,
    required this.restaurantId,
    required this.storeCategory,
    this.compact = false,
    this.showAdvancedActions = true,
  });

  final String restaurantId;
  final String? storeCategory;
  final bool compact;

  /// Manual recheck. Garson and kitchen banners keep it. A caller can hide it.
  final bool showAdvancedActions;

  @override
  State<RestaurantOfflineBanner> createState() => _RestaurantOfflineBannerState();
}

class _RestaurantOfflineBannerState extends State<RestaurantOfflineBanner> {
  int _pendingSyncCount = 0;
  int? _savedPrinterCount;
  DateTime? _cachedAt;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_refreshConnectivityAndCounts());
    });
  }

  @override
  void didUpdateWidget(covariant RestaurantOfflineBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.restaurantId != widget.restaurantId) {
      unawaited(_refreshConnectivityAndCounts());
    }
  }

  Future<void> _refreshConnectivityAndCounts() async {
    final connectivity = RestaurantConnectivityService.instance;
    await connectivity.refresh();
    final cache = await RestaurantLocalCacheService().read(widget.restaurantId);
    final sync = RestaurantOfflineSyncService();
    var pending = await sync.pendingCount(widget.restaurantId);
    // A waiting or failed local order is sent again whenever the cloud is
    // reachable; the server recognises its local id, so a repeat adds no
    // second order. Without this a failed sync waited for the next outage.
    if (pending > 0 &&
        connectivity.hasNetwork &&
        connectivity.supabaseReachable) {
      try {
        await sync.syncPendingOrders(restaurantId: widget.restaurantId);
      } catch (_) {}
      pending = await sync.pendingCount(widget.restaurantId);
    }
    int? remote;
    try {
      remote = (await PrinterRepository().fetchPrinters(
        widget.restaurantId,
      )).length;
    } catch (_) {
      remote = null; // offline or unreadable: fall back to the cache below
    }
    if (!mounted) return;
    setState(() {
      _pendingSyncCount = pending;
      _cachedAt = cache?.cachedAt;
      _savedPrinterCount = resolveSavedPrinterCount(
        remoteCount: remote,
        cachedCount: cache?.printers.length,
      );
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!canUseRestaurantPrinterSystem(widget.storeCategory)) {
      return const SizedBox.shrink();
    }
    if (!_loaded) {
      return const SizedBox.shrink();
    }

    return ListenableBuilder(
      listenable: RestaurantConnectivityService.instance,
      builder: (context, _) {
        final connectivity = RestaurantConnectivityService.instance;
        final mode = connectivity.mode;
        final hasInternet = connectivity.hasNetwork;
        final supabaseOk = connectivity.supabaseReachable;

        final printerNotice = waiterPrinterNotice(
          savedPrinters: _savedPrinterCount,
        );
        if (hasInternet && supabaseOk && mode == RestaurantConnectivityMode.online) {
          if (_pendingSyncCount <= 0 && printerNotice == null) {
            return const SizedBox.shrink();
          }
        }

        final lines = <String>[];
        Color background;
        Color foreground;

        switch (mode) {
          case RestaurantConnectivityMode.online:
            if (_pendingSyncCount <= 0 && printerNotice == null) {
              return const SizedBox.shrink();
            }
            if (_pendingSyncCount > 0) {
              // Not plain green: the cloud answers but orders are still waiting.
              lines.add(waiterCloudLine(pendingSync: _pendingSyncCount));
              final authNotice = RestaurantOfflineSyncService.authNotice.value;
              if (authNotice != null) lines.add(authNotice);
              background = const Color(0xFF2563EB);
            } else {
              // Only the printer notice is left to say.
              background = const Color(0xFFD97706);
            }
            foreground = Colors.white;
          case RestaurantConnectivityMode.syncing:
            lines.add('Yerel siparişler senkronlanıyor…');
            background = const Color(0xFF2563EB);
            foreground = Colors.white;
          case RestaurantConnectivityMode.bridgeUnreachable:
            // A center the operator has not started is not a fault.
            final closed = PrintServiceStartGate.refusal() != null;
            lines.add(
              closed
                  ? PrintServiceStartGate.closedMessage
                  : 'Yazıcı köprüsü çalışmıyor. Fiş basılamaz.',
            );
            background = closed
                ? const Color(0xFFD97706)
                : const Color(0xFFDC2626);
            foreground = Colors.white;
          case RestaurantConnectivityMode.supabaseUnreachable:
            lines.add('Supabase bağlantısı yok. Yerel restoran modu.');
            background = const Color(0xFFEA580C);
            foreground = Colors.white;
          case RestaurantConnectivityMode.offlineLocalMode:
            lines.add('İnternet yok. Yerel restoran modunda çalışıyorsunuz.');
            background = const Color(0xFFEA580C);
            foreground = Colors.white;
          case RestaurantConnectivityMode.lanUnavailable:
            lines.add(
              'Yerel ağ yok. Sipariş ve yazıcı yolu bu cihazdan kullanılamaz.',
            );
            background = const Color(0xFFEA580C);
            foreground = Colors.white;
          case RestaurantConnectivityMode.conflict:
            lines.add(
              'Kayıt çakışması var. Otomatik kapatma ve yeniden baskı yapılmaz.',
            );
            background = const Color(0xFFDC2626);
            foreground = Colors.white;
        }

        if (_pendingSyncCount > 0 &&
            mode != RestaurantConnectivityMode.online) {
          lines.add('$_pendingSyncCount yerel sipariş senkron bekliyor.');
        }
        if (printerNotice != null) lines.add(printerNotice);
        if (_cachedAt != null &&
            mode != RestaurantConnectivityMode.online &&
            mode != RestaurantConnectivityMode.bridgeUnreachable) {
          lines.add(
            RestaurantLocalCacheService().staleCacheMessage(_cachedAt!),
          );
        }

        return Material(
          color: background,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: widget.compact ? 12 : 16,
                vertical: widget.compact ? 8 : 10,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    mode == RestaurantConnectivityMode.online
                        ? Icons.cloud_done_outlined
                        : Icons.cloud_off_outlined,
                    color: foreground,
                    size: widget.compact ? 18 : 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      lines.join('\n'),
                      style: TextStyle(
                        color: foreground,
                        fontSize: widget.compact ? 12 : 13,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ),
                  if (widget.showAdvancedActions &&
                      mode != RestaurantConnectivityMode.online)
                    TextButton(
                      onPressed: () =>
                          unawaited(_refreshConnectivityAndCounts()),
                      style: TextButton.styleFrom(
                        foregroundColor: foreground,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                      child: const Text(
                        'Yeniden Kontrol Et',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Triggers pending-order sync when connectivity returns.
class RestaurantOfflineReconnectListener extends StatefulWidget {
  const RestaurantOfflineReconnectListener({
    super.key,
    required this.restaurantId,
    required this.storeCategory,
    required this.child,
  });

  final String restaurantId;
  final String? storeCategory;
  final Widget child;

  @override
  State<RestaurantOfflineReconnectListener> createState() =>
      _RestaurantOfflineReconnectListenerState();
}

class _RestaurantOfflineReconnectListenerState
    extends State<RestaurantOfflineReconnectListener> {
  bool _wasOffline = false;
  bool _startupSyncDone = false;

  /// Sync runs from the open local center only. Right after start the
  /// center is still coming up; syncing at once marked every waiting order
  /// as failed with "only from the open local server". This waits for it.
  Future<void> _syncWhenLocalCenterReady() async {
    final restaurantId = widget.restaurantId;
    for (var attempt = 0; attempt < 30; attempt++) {
      final host = RestaurantLanHostRegistry.current;
      if (host != null && host.listening && host.restaurantId == restaurantId) {
        break;
      }
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted) return;
    }
    await RestaurantOfflineSyncService().syncPendingOrders(
      restaurantId: restaurantId,
      forceRetry: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!canUseRestaurantPrinterSystem(widget.storeCategory)) {
      return widget.child;
    }

    // KÖK NEDEN FIX (Garson ProviderNotFound): web'de
    // RestaurantConnectivityService provider'ı mount edilmez
    // (app_providers.dart `if (!kIsWeb)`), bu Consumer build sırasında
    // "Provider<RestaurantConnectivityService> not found" fırlatıp Garson
    // sayfasını kırıyordu. Banner ile aynı desen: singleton'ı
    // ListenableBuilder ile dinle — desktop'ta provider da aynı instance'ı
    // (`.value(RestaurantConnectivityService.instance)`) veriyordu,
    // davranış birebir aynı kalır.
    return ListenableBuilder(
      listenable: RestaurantConnectivityService.instance,
      builder: (context, child) {
        final connectivity = RestaurantConnectivityService.instance;
        final offline =
            !connectivity.hasNetwork || !connectivity.supabaseReachable;
        // Orders left waiting by an earlier run (the app was closed while
        // offline, or a sync failed) are sent on the first online check too.
        // Before, only an offline-to-online change inside one run sent them,
        // so they could wait until the next outage.
        final startupSync = !offline && !_startupSyncDone;
        if (!offline) _startupSyncDone = true;
        if ((_wasOffline && !offline) || startupSync) {
          _wasOffline = false;
          _syncWhenLocalCenterReady().ignore();
        } else if (offline) {
          _wasOffline = true;
        }
        return child!;
      },
      child: widget.child,
    );
  }
}
