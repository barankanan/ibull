import 'package:flutter/material.dart';

import '../../../widgets/optimized_image.dart';

/// Fixed 16:6.4 banner slot. Skeleton and image share the same box.
class MobileHomeHero extends StatefulWidget {
  const MobileHomeHero({
    super.key,
    required this.urls,
    required this.loading,
  });

  final List<String> urls;
  final bool loading;

  static const aspectRatio = 16 / 6.4;

  @override
  State<MobileHomeHero> createState() => _MobileHomeHeroState();
}

class _MobileHomeHeroState extends State<MobileHomeHero> {
  final _page = PageController();
  var _index = 0;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.loading && widget.urls.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: AspectRatio(
        key: const ValueKey('mobile-home-banner'),
        aspectRatio: MobileHomeHero.aspectRatio,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: widget.loading && widget.urls.isEmpty
              ? const ColoredBox(
                  key: ValueKey('mobile-home-banner-skeleton'),
                  color: Color(0xFFE6E7EE),
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    PageView.builder(
                      controller: _page,
                      itemCount: widget.urls.length,
                      onPageChanged: (value) => setState(() => _index = value),
                      itemBuilder: (context, index) => OptimizedImage(
                        imageUrlOrPath: widget.urls[index],
                        fit: BoxFit.cover,
                        cacheWidth: 960,
                        cacheHeight: 384,
                        priority: OptimizedImagePriority.high,
                        placeholder: const ColoredBox(color: Color(0xFFE6E7EE)),
                        errorWidget: const ColoredBox(
                          color: Color(0xFFE6E7EE),
                          child: Icon(Icons.image_outlined, color: Color(0xFF9CA3AF)),
                        ),
                      ),
                    ),
                    if (widget.urls.length > 1)
                      Positioned(
                        right: 10,
                        bottom: 8,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xCC111827),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Text(
                              '${_index + 1}/${widget.urls.length}',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
