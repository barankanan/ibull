import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/app_ready.dart';
import '../core/constants.dart';
import '../core/qr_initial_params.dart';
import '../services/store_service.dart';
import 'business_detail_page.dart';

/// Standalone screen shown when the app is opened via a QR code URL
/// (`/qr?seller=...&table=...&token=...`).
///
/// Resolves the QR parameters, verifies the token, then replaces itself with
/// [BusinessDetailPage] to open the table ordering flow directly.
/// Never falls back to the home page — shows a QR-specific error instead.
class QrEntryScreen extends StatefulWidget {
  const QrEntryScreen({super.key});

  @override
  State<QrEntryScreen> createState() => _QrEntryScreenState();
}

class _QrEntryScreenState extends State<QrEntryScreen> {
  final StoreService _storeService = StoreService();

  String? _errorMessage;
  // Shown in the loading label once params are parsed.
  String? _resolvedSellerHint;

  @override
  void initState() {
    super.initState();
    debugPrint('[QR-Timing] QrEntryScreen.initState called');
    // Log the first rendered frame for end-to-end timing.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('[QR-Timing] QrEntryScreen first frame rendered (mounted=true)');
    });
    // Start resolving immediately — params are already captured, no reason to
    // delay until the first frame. The async work (Supabase queries) takes
    // 100–300 ms, and Navigator is available well before that finishes.
    _handleQr();
  }

  // ─── helpers ──────────────────────────────────────────────────────────────

  static String _first(Map<String, String> src, List<String> keys) {
    for (final key in keys) {
      final v = (src[key] ?? '').trim();
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  static int? _parseTable(String raw) {
    final direct = int.tryParse(raw.trim());
    if (direct != null) return direct;
    final m = RegExp(r'\d+').firstMatch(raw);
    if (m == null) return null;
    return int.tryParse(m.group(0)!);
  }

  // ─── QR resolution ────────────────────────────────────────────────────────

  Future<void> _handleQr() async {
    final qrWatch = Stopwatch()..start();
    debugPrint(
      '[QR-Bootstrap] START — source=QrEntryScreen ${QrInitialParams.debugState}',
    );
    debugPrint('[QR-Timing] ${qrWatch.elapsedMilliseconds}ms — _handleQr started');

    // On the QR web fast-path, runApp is called before Supabase initialises.
    // Wait here (typically 100–500 ms) so Supabase.instance is available before
    // any API call.  On all other paths this future is already resolved (no-op).
    try {
      await appServicesReady.timeout(const Duration(seconds: 12));
    } catch (_) {
      _setError('Uygulama başlatılamadı. Lütfen sayfayı yenileyin.');
      return;
    }
    debugPrint('[QR-Timing] ${qrWatch.elapsedMilliseconds}ms — services ready');

    // Consume startup-captured params first; fall back to live Uri.base on web.
    final params = <String, String>{
      ...QrInitialParams.consume(source: 'QrEntryScreen'),
    };
    if (params.isEmpty && kIsWeb) {
      params.addAll(Uri.base.queryParameters);
      debugPrint(
        '[QR-Bootstrap] SKIPPED — startup params empty, using live Uri.base '
        'source=QrEntryScreen params=$params ${QrInitialParams.debugState}',
      );
      debugPrint('[QrEntryScreen] startup params empty — using live Uri.base.queryParameters: $params');
    }

    final sellerId = _first(params, ['seller', 'seller_id', 'store']);
    final tableRaw = _first(params, ['table', 'table_number', 'masa']);
    final tableNumber = _parseTable(tableRaw);
    final token = _first(params, ['token', 'qr_token', 'qr', 't']);

    debugPrint('[QR-Timing] ${qrWatch.elapsedMilliseconds}ms — sellerId=$sellerId tableNumber=$tableNumber token=$token');

    if (sellerId.isEmpty) {
      _setError('Geçersiz QR kodu: mağaza bilgisi eksik.');
      return;
    }

    // Show the seller hint in the loading label so the user sees feedback
    // before the network round-trip completes.
    if (mounted) setState(() => _resolvedSellerHint = sellerId);

    try {
      debugPrint('[QR-Timing] ${qrWatch.elapsedMilliseconds}ms — QR resolve start (parallel Supabase calls)');
      final futures = await Future.wait<Object?>([
        (token.isNotEmpty && tableNumber != null && tableNumber > 0)
            ? _storeService.resolveStoreTableQr(
                sellerId: sellerId,
                tableNumber: tableNumber,
                qrToken: token,
              )
            : Future<Map<String, dynamic>?>.value(null),
        _storeService.getBusinessSummaryBySellerId(sellerId),
      ]);

      debugPrint('[QR-Timing] ${qrWatch.elapsedMilliseconds}ms — QR resolve done');

      if (!mounted) return;

      final resolvedTable = futures[0] as Map<String, dynamic>?;
      var business = futures[1] as Map<String, dynamic>?;

      // Fallback: try by business name if lookup by seller ID returned nothing.
      if (business == null) {
        debugPrint('[QR-Timing] ${qrWatch.elapsedMilliseconds}ms — fallback: getBusinessSummaryByBusinessName');
        business = await _storeService.getBusinessSummaryByBusinessName(sellerId);
        // Inject the seller_id from QR params so downstream code
        // (_fetchStoreProducts) skips an extra ID-lookup round-trip.
        if (business != null) {
          final existingSellerId = business['seller_id']?.toString() ?? '';
          if (existingSellerId.isEmpty) {
            business = Map<String, dynamic>.from(business)..['seller_id'] = sellerId;
          }
        }
      }
      debugPrint('[QR-Timing] ${qrWatch.elapsedMilliseconds}ms — business resolved: ${business?['name']}');

      if (!mounted) return;

      if (business == null) {
        _setError('Bu QR kodu için mağaza bulunamadı.');
        return;
      }

      final qrVerified = token.isNotEmpty && resolvedTable != null;
      if (!qrVerified && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'QR doğrulanamadı: menü önizleme modu. Sipariş için garson onayı gerekir.',
            ),
            duration: Duration(seconds: 5),
          ),
        );
      }

      // Navigate instantly (zero-duration transition) → BusinessDetailPage.
      // Eliminating the slide animation saves ~300 ms, and because there is no
      // animation to wait for, BusinessDetailPage can open the table dialog
      // with a much shorter internal delay (fromQr: true uses 80 ms vs 420 ms).
      debugPrint('[QR-Timing] ${qrWatch.elapsedMilliseconds}ms — navigating to BusinessDetailPage');
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          pageBuilder: (_, _, _) => BusinessDetailPage(
            business: business!,
            forceTableSelection: true,
            initialTableNumber: tableNumber,
            fromQr: true,
            unverifiedQrTableFlow: !qrVerified,
          ),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
      debugPrint('[QR-Timing] ${qrWatch.elapsedMilliseconds}ms — total QR→BDP navigation time');
    } catch (error, stack) {
      debugPrint('[QrEntryScreen] EXCEPTION: $error');
      debugPrintStack(stackTrace: stack);
      if (mounted) _setError('QR açılamadı: $error');
    }
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() => _errorMessage = message);
  }

  // ─── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.qr_code_rounded,
                    size: 36,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'QR Kod Hatası',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── İbul logo with premium rounded-rectangle container ──
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.28),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                'assets/icons/ibul_logo_2.png',
                width: 88,
                height: 88,
                fit: BoxFit.cover,
                // Fallback if asset isn't available in the root project context
                errorBuilder: (_, _, _) => Container(
                  width: 88,
                  height: 88,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF7B2FBE), Color(0xFF5B1FBF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Icon(
                    Icons.store_mall_directory_rounded,
                    color: Colors.white,
                    size: 44,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            // ── Branded spinner ──
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.primary.withValues(alpha: 0.80),
                ),
              ),
            ),
            const SizedBox(height: 18),
            // ── Contextual status text ──
            Text(
              _resolvedSellerHint != null
                  ? 'Restoran bağlanıyor…'
                  : 'QR kod okunuyor…',
              style: const TextStyle(
                fontSize: 13.5,
                color: Colors.black45,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
