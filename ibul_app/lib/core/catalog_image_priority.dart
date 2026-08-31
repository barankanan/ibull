import '../widgets/optimized_image.dart';

/// Visible-first image policy used by marketplace rails and grids.
/// Layout/colors stay the same; only decode/network work is gated.
abstract final class CatalogImagePriority {
  static const railEagerCount = 4;

  static OptimizedImagePriority forRailIndex(int index) {
    return index < railEagerCount
        ? OptimizedImagePriority.high
        : OptimizedImagePriority.lazy;
  }

  static OptimizedImagePriority forGridIndex(
    int index, {
    required int crossAxisCount,
    int eagerRows = 2,
  }) {
    final eager = (crossAxisCount.clamp(1, 12)) * eagerRows;
    return index < eager
        ? OptimizedImagePriority.high
        : OptimizedImagePriority.lazy;
  }
}
