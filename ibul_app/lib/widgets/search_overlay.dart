import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/app_state.dart';
import '../../models/product_model.dart';
import '../../services/database_helper.dart';
import '../../services/search_telemetry_service.dart';
import 'advanced_filter_drawer.dart';

class SearchOverlay extends StatefulWidget {
  final Function(String) onSearch;
  final VoidCallback? onClose;
  final bool showFilters;
  final ValueListenable<String>? queryListenable;
  final ValueChanged<Product>? onProductTap;

  const SearchOverlay({
    super.key,
    required this.onSearch,
    this.onClose,
    this.showFilters = false,
    this.queryListenable,
    this.onProductTap,
  });

  @override
  State<SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends State<SearchOverlay> {
  late bool _showFilters;
  Timer? _debounce;
  String _query = '';
  bool _isLoadingSuggestions = false;
  String? _suggestionsError;
  List<Product> _suggestions = const [];
  bool _isLoadingPopularSearches = false;
  List<String> _popularSearchTerms = const [];
  int _suggestionRequestVersion = 0;

  @override
  void initState() {
    super.initState();
    _showFilters = widget.showFilters;
    widget.queryListenable?.addListener(_onQueryChanged);
    _query = widget.queryListenable?.value ?? '';
    unawaited(_loadPopularSearchTerms());
    if (_query.trim().isNotEmpty) {
      _debouncedSuggest();
    }
  }

  @override
  void dispose() {
    widget.queryListenable?.removeListener(_onQueryChanged);
    _debounce?.cancel();
    super.dispose();
  }

  void _onQueryChanged() {
    final next = widget.queryListenable?.value ?? '';
    if (next == _query) return;
    setState(() {
      _query = next;
    });
    _debouncedSuggest();
  }

  void _debouncedSuggest() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 100), () async {
      if (!mounted) return;
      await _loadSuggestions();
    });
  }

  Future<void> _loadSuggestions() async {
    final q = _normalize(_query);
    if (q.replaceAll(' ', '').length < 3) {
      if (!mounted) return;
      setState(() {
        _suggestions = const [];
        _isLoadingSuggestions = false;
        _suggestionsError = null;
      });
      return;
    }

    final requestVersion = ++_suggestionRequestVersion;
    setState(() {
      _isLoadingSuggestions = true;
      _suggestionsError = null;
    });

    try {
      final dbProducts = await DatabaseHelper.instance.getProductSuggestions(
        query: _query,
        limit: 8,
      );
      if (!mounted || requestVersion != _suggestionRequestVersion) return;
      setState(() {
        _suggestions = dbProducts
            .map(Product.fromDBProduct)
            .toList(growable: false);
        _isLoadingSuggestions = false;
      });
    } catch (_) {
      if (!mounted || requestVersion != _suggestionRequestVersion) return;
      setState(() {
        _suggestions = const [];
        _isLoadingSuggestions = false;
        _suggestionsError = 'Öneriler yüklenemedi';
      });
    }
  }

  Future<void> _loadPopularSearchTerms() async {
    if (_isLoadingPopularSearches) return;
    setState(() {
      _isLoadingPopularSearches = true;
    });

    final queryScores = <String, int>{};
    final displayByNormalized = <String, String>{};

    void addScore(String rawQuery, int score) {
      final trimmed = rawQuery.trim();
      if (trimmed.isEmpty) return;
      final normalized = _normalize(trimmed);
      if (normalized.replaceAll(' ', '').length < 2) return;
      queryScores.update(normalized, (value) => value + score, ifAbsent: () => score);
      displayByNormalized.putIfAbsent(normalized, () => trimmed);
    }

    final localHistory = context.read<AppState>().searchHistory;
    for (var i = 0; i < localHistory.length; i++) {
      // Daha yeni aramaya biraz daha yüksek ağırlık ver.
      addScore(localHistory[i], localHistory.length - i);
    }

    try {
      final recent = await SearchTelemetryService.instance.getRecentSearches(days: 30);
      for (final event in recent) {
        addScore(event.query, 1);
      }
    } catch (_) {
      // Telemetry hazır değilse local geçmişle devam ederiz.
    }

    final candidates = queryScores.entries.toList()
      ..sort((a, b) {
        final scoreCompare = b.value.compareTo(a.value);
        if (scoreCompare != 0) return scoreCompare;
        return a.key.length.compareTo(b.key.length);
      });

    final topCandidates = candidates.take(80);
    final popular = <String>[];
    for (final entry in topCandidates) {
      popular.add(displayByNormalized[entry.key] ?? entry.key);
      if (popular.length >= 3) break;
    }

    if (!mounted) return;
    setState(() {
      _popularSearchTerms = popular;
      _isLoadingPopularSearches = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final history = appState.searchHistory;
    final recentProducts = appState.recentlyViewedProducts;

    // Check if we are on a small screen (mobile)
    final isMobile = MediaQuery.of(context).size.width < 600;

    final normalizedQuery = _normalize(_query);
    final showSuggestions = normalizedQuery.replaceAll(' ', '').length >= 3;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 500),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Column: History & Popular
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (showSuggestions) ...[
                                  _buildSectionHeader('Öneriler', null),
                                  const SizedBox(height: 12),
                                  if (_isLoadingSuggestions)
                                    const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 8.0),
                                      child: LinearProgressIndicator(minHeight: 2),
                                    )
                                  else if (_suggestionsError != null)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                                      child: Text(_suggestionsError!, style: const TextStyle(color: Colors.grey)),
                                    )
                                  else if (_suggestions.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                                      child: Text('"${_query.trim()}" için öneri bulunamadı.', style: const TextStyle(color: Colors.grey)),
                                    )
                                  else
                                    Column(
                                      children: _suggestions.map((p) => _buildSuggestionItem(context, p)).toList(),
                                    ),
                                  const SizedBox(height: 20),
                                ],
                                _buildSectionHeader(
                                  'Geçmiş aramaların',
                                  history.isNotEmpty ? 'Temizle' : null,
                                  onAction: appState.clearSearchHistory,
                                ),
                                const SizedBox(height: 10),
                                if (history.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8.0),
                                    child: Text('Henüz arama yapmadınız.', style: TextStyle(color: Colors.grey)),
                                  )
                                else
                                  ...history.map((term) => _buildHistoryItem(term, () => appState.removeSearchHistory(term))),
                                
                                const SizedBox(height: 24),
                                _buildSectionHeader('Popüler aramalar', null),
                                const SizedBox(height: 16),
                                if (_isLoadingPopularSearches)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8.0),
                                    child: LinearProgressIndicator(minHeight: 2),
                                  )
                                else if (_popularSearchTerms.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8.0),
                                    child: Text(
                                      'Henüz popüler ürün araması yok.',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  )
                                else
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: _popularSearchTerms.map(_buildPopularTag).toList(),
                                  ),
                              ],
                            ),
                          ),
                          
                          // Divider (Only show if not mobile)
                          if (!isMobile)
                            Container(
                              width: 1,
                              height: 300,
                              color: Colors.grey.shade200,
                              margin: const EdgeInsets.symmetric(horizontal: 24),
                            ),
                          
                          // Right Column: Recently Viewed (Hide on Mobile)
                          if (!isMobile)
                            Expanded(
                              flex: 2,
                              child: _showFilters
                                  ? SizedBox(
                                      height: 260,
                                      child: AdvancedFilterDrawer(
                                        compact: true,
                                        onClose: () {
                                          setState(() {
                                            _showFilters = false;
                                          });
                                        },
                                        onApply: () {
                                          if (widget.onClose != null) {
                                            widget.onClose!();
                                          }
                                        },
                                      ),
                                    )
                                  : Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Son gezdiğin ürünler',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        recentProducts.isEmpty
                                            ? const Text('Henüz ürün gezmediniz.', style: TextStyle(color: Colors.grey))
                                            : Column(
                                                children: recentProducts.map((product) {
                                                  return _buildRecentProductItem(
                                                    product.name,
                                                    product.price,
                                                    product.images.isNotEmpty ? product.images.first : '',
                                                    isDiscounted: true,
                                                  );
                                                }).toList(),
                                              ),
                                      ],
                                    ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionItem(BuildContext context, Product product) {
    return InkWell(
      onTap: () {
        widget.onProductTap?.call(product);
        if (widget.onProductTap == null) {
          widget.onSearch(product.name);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.search, color: Colors.grey, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
            ),
            Text(
              product.price.contains('TL') ? product.price : '${product.price} TL',
              style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String? action, {VoidCallback? onAction}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: onAction ?? () {},
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              action,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  String _normalize(String value) {
    var t = value.toLowerCase().trim();
    t = t.replaceAll('i̇', 'i');
    t = t.replaceAll('ı', 'i').replaceAll('İ', 'i');
    t = t.replaceAll('ş', 's').replaceAll('Ş', 's');
    t = t.replaceAll('ğ', 'g').replaceAll('Ğ', 'g');
    t = t.replaceAll('ü', 'u').replaceAll('Ü', 'u');
    t = t.replaceAll('ö', 'o').replaceAll('Ö', 'o');
    t = t.replaceAll('ç', 'c').replaceAll('Ç', 'c');
    t = t.replaceAll(RegExp(r'\s+'), ' ');
    return t;
  }

  Widget _buildHistoryItem(String text, VoidCallback onRemove) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => widget.onSearch(text),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    const Icon(Icons.history, color: Colors.grey, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        text,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16, color: Colors.grey),
            onPressed: onRemove,
            splashRadius: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildPopularTag(String text) {
    return InkWell(
      onTap: () => widget.onSearch(text),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentProductItem(String title, String price, String imageUrl, {bool isDiscounted = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // Product Image (Small)
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 40,
              height: 40,
              child: imageUrl.startsWith('http')
                  ? Image.network(
                      imageUrl, 
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => Container(
                        color: Colors.grey.shade100,
                        child: const Icon(Icons.image_not_supported, size: 16, color: Colors.grey),
                      ),
                    )
                  : Image.asset(
                      imageUrl, 
                      fit: BoxFit.cover, 
                      errorBuilder: (c, e, s) => Container(
                        color: Colors.grey.shade100,
                        child: const Icon(Icons.image_not_supported, size: 16, color: Colors.grey),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          
          // Product Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isDiscounted)
                  Container(
                    margin: const EdgeInsets.only(bottom: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text(
                      'Yakın Lokasyon',
                      style: TextStyle(
                        color: AppColors.primary, 
                        fontSize: 9, 
                        fontWeight: FontWeight.w600
                      ),
                    ),
                  ),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
                Text(
                  price.contains('TL') ? price : '$price TL',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          
          // Action Icon
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
