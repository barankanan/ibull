import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/seller/panel/helpers/restaurant_printer_eligibility.dart';
import '../services/restaurant_offline/restaurant_connectivity_service.dart';
import '../services/restaurant_offline/restaurant_local_cache_service.dart';
import '../services/restaurant_offline/restaurant_offline_models.dart';
import '../services/restaurant_offline/restaurant_offline_sync_service.dart';

class RestaurantOfflineBanner extends StatefulWidget {
  const RestaurantOfflineBanner({
    super.key,
    required this.restaurantId,
    required this.storeCategory,
    this.compact = false,
  });

  final String restaurantId;
  final String? storeCategory;
  final bool compact;

  @override
  State<RestaurantOfflineBanner> createState() => _RestaurantOfflineBannerState();
}

class _RestaurantOfflineBannerState extends State<RestaurantOfflineBanner> {
  int _pendingSyncCount = 0;
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
    final pending = await RestaurantOfflineSyncService().pendingCount(
      widget.restaurantId,
    );
    if (!mounted) return;
    setState(() {
      _pendingSyncCount = pending;
      _cachedAt = cache?.cachedAt;
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

        if (hasInternet && supabaseOk && mode == RestaurantConnectivityMode.online) {
          if (_pendingSyncCount <= 0) {
            return const SizedBox.shrink();
          }
        }

        final lines = <String>[];
        Color background;
        Color foreground;

        switch (mode) {
          case RestaurantConnectivityMode.online:
            if (_pendingSyncCount <= 0) {
              return const SizedBox.shrink();
            }
            lines.add('Çevrimiçi');
            background = const Color(0xFF16A34A);
            foreground = Colors.white;
          case RestaurantConnectivityMode.syncing:
            lines.add('Yerel siparişler senkronlanıyor…');
            background = const Color(0xFF2563EB);
            foreground = Colors.white;
          case RestaurantConnectivityMode.bridgeUnreachable:
            lines.add('Yazıcı köprüsü çalışmıyor. Fiş basılamaz.');
            background = const Color(0xFFDC2626);
            foreground = Colors.white;
          case RestaurantConnectivityMode.supabaseUnreachable:
            lines.add('Supabase bağlantısı yok. Yerel restoran modu.');
            background = const Color(0xFFEA580C);
            foreground = Colors.white;
          case RestaurantConnectivityMode.offlineLocalMode:
            lines.add('İnternet yok. Yerel restoran modunda çalışıyorsunuz.');
            background = const Color(0xFFEA580C);
            foreground = Colors.white;
        }

        if (_pendingSyncCount > 0) {
          lines.add('$_pendingSyncCount yerel sipariş senkron bekliyor.');
        }
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
                  if (mode != RestaurantConnectivityMode.online)
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

  @override
  Widget build(BuildContext context) {
    if (!canUseRestaurantPrinterSystem(widget.storeCategory)) {
      return widget.child;
    }

    return Consumer<RestaurantConnectivityService>(
      builder: (context, connectivity, child) {
        final offline =
            !connectivity.hasNetwork || !connectivity.supabaseReachable;
        if (_wasOffline && !offline) {
          _wasOffline = false;
          RestaurantOfflineSyncService()
              .syncPendingOrders(restaurantId: widget.restaurantId)
              .ignore();
        } else if (offline) {
          _wasOffline = true;
        }
        return child!;
      },
      child: widget.child,
    );
  }
}
