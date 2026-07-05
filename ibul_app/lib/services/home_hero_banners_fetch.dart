import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/runtime_config.dart';
import '../core/home_data_diagnostics.dart';
import '../core/home_snapshot_cache.dart';

/// Supabase campaign_images hero banners — no asset/demo fallback.
class HomeHeroBannersFetch {
  HomeHeroBannersFetch._();

  static const Duration requestTimeout = Duration(seconds: 3);

  static List<String> readCachedUrlsSync() =>
      _readCachedUrls(preferMobile: false);

  static Future<HomeHeroBannersFetchResult> fetch({
    bool preferMobile = false,
  }) async {
    HomeAdsDiagnostics.heroRequestStart();
    final cached = _readCachedUrls(preferMobile: preferMobile);
    if (cached.isNotEmpty) {
      HomeAdsDiagnostics.heroRaw(count: cached.length);
      HomeAdsDiagnostics.heroActive(count: cached.length);
      return HomeHeroBannersFetchResult(
        imageUrls: cached,
        source: 'cache',
        ms: 0,
        rawCount: cached.length,
      );
    }

    if (!AppRuntimeConfig.hasSupabaseConfig) {
      HomeAdsDiagnostics.heroHidden(reason: 'config_missing');
      return const HomeHeroBannersFetchResult(
        imageUrls: [],
        source: 'skipped',
        error: 'Supabase config eksik',
      );
    }

    final started = DateTime.now().millisecondsSinceEpoch;
    try {
      final rows = await Supabase.instance.client
          .from('campaign_images')
          .select('id, image_path, mobile_image_path, is_active, sort_order')
          .eq('is_active', true)
          .order('sort_order', ascending: true)
          .timeout(requestTimeout);
      final list = (rows as List).cast<Map<String, dynamic>>();
      HomeAdsDiagnostics.heroRaw(count: list.length);
      final urls = _resolveBannerUrls(list, preferMobile: preferMobile);
      HomeAdsDiagnostics.heroActive(count: urls.length);
      if (urls.isNotEmpty) {
        HomeAdsDiagnostics.heroRendered(count: urls.length);
        HomeAdsDiagnostics.heroBanners(count: urls.length);
        HomeSnapshotCache.instance.writeMemory(
          HomeSnapshot(
            heroAds: list,
            createdAt: DateTime.now(),
          ),
        );
      } else {
        HomeAdsDiagnostics.heroHidden(reason: 'no_resolvable_urls');
      }
      return HomeHeroBannersFetchResult(
        imageUrls: urls,
        source: 'network',
        ms: DateTime.now().millisecondsSinceEpoch - started,
        rawCount: list.length,
      );
    } catch (error) {
      HomeAdsDiagnostics.heroHidden(reason: 'error');
      HomeAdsDiagnostics.sectionHidden(source: 'hero_banners');
      return HomeHeroBannersFetchResult(
        imageUrls: const [],
        source: 'network',
        ms: DateTime.now().millisecondsSinceEpoch - started,
        error: error.toString(),
      );
    }
  }

  static List<String> _readCachedUrls({bool preferMobile = false}) {
    final snapshot = HomeSnapshotCache.instance.readMemory();
    if (snapshot == null || snapshot.heroAds.isEmpty) return const [];
    return _resolveBannerUrls(snapshot.heroAds, preferMobile: preferMobile);
  }

  static List<String> _resolveBannerUrls(
    List<Map<String, dynamic>> banners, {
    bool preferMobile = false,
  }) {
    return banners
        .map((banner) => _resolveBannerImagePath(banner, preferMobile: preferMobile))
        .whereType<String>()
        .toList(growable: false);
  }

  static String? _resolveBannerImagePath(
    Map<String, dynamic> banner, {
    bool preferMobile = false,
  }) {
    final imagePath = banner['image_path']?.toString().trim() ?? '';
    final mobileImagePath =
        banner['mobile_image_path']?.toString().trim() ?? '';
    final resolved = preferMobile
        ? (mobileImagePath.isNotEmpty ? mobileImagePath : imagePath)
        : (imagePath.isNotEmpty ? imagePath : mobileImagePath);
    if (resolved.isEmpty || resolved.startsWith('assets/')) return null;
    return resolved;
  }
}

class HomeHeroBannersFetchResult {
  const HomeHeroBannersFetchResult({
    required this.imageUrls,
    required this.source,
    this.ms = 0,
    this.rawCount = 0,
    this.error,
  });

  final List<String> imageUrls;
  final String source;
  final int ms;
  final int rawCount;
  final String? error;
}
