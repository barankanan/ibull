/// Integer percent helpers for the gift wheel. Avoids float (99.999999) save bugs.
abstract final class RewardWheelProbability {
  static const int fullPercent = 100;
  static const int bpsPerPercent = 100;
  static const int fullBps = 10000;

  static int clampPercent(int value) {
    if (value < 0) return 0;
    if (value > fullPercent) return fullPercent;
    return value;
  }

  static int parsePercent(String raw) {
    final trimmed = raw.trim().replaceAll(',', '.');
    if (trimmed.isEmpty) return 0;
    final asInt = int.tryParse(trimmed);
    if (asInt != null) return clampPercent(asInt);
    final asDouble = double.tryParse(trimmed);
    if (asDouble == null) return 0;
    return clampPercent(asDouble.round());
  }

  static int percentToBps(int percent) => clampPercent(percent) * bpsPerPercent;

  static int bpsToPercent(int bps) {
    if (bps <= 0) return 0;
    return clampPercent(((bps + 50) ~/ bpsPerPercent));
  }

  static int totalPercent(Iterable<int> percents) =>
      percents.fold<int>(0, (sum, value) => sum + value);

  static int remainingPercent(Iterable<int> percents) =>
      fullPercent - totalPercent(percents);

  static bool isComplete(Iterable<int> percents) =>
      totalPercent(percents) == fullPercent;

  /// Spreads 100% across [count] slots. Remainder 1% units go to the first slots.
  static List<int> equalDistribute(int count) {
    if (count <= 0) return const [];
    final base = fullPercent ~/ count;
    final extra = fullPercent - base * count;
    return [
      for (var i = 0; i < count; i++) base + (i < extra ? 1 : 0),
    ];
  }

  /// Adds leftover percent points one-by-one.
  /// When [targetIndexes] is empty, every slot receives a share.
  static List<int> distributeRemainder(
    List<int> current, {
    List<int>? targetIndexes,
  }) {
    if (current.isEmpty) return current;
    final total = totalPercent(current);
    if (total >= fullPercent) return List<int>.from(current);
    final targets = (targetIndexes == null || targetIndexes.isEmpty)
        ? [for (var i = 0; i < current.length; i++) i]
        : targetIndexes.where((i) => i >= 0 && i < current.length).toList();
    if (targets.isEmpty) return List<int>.from(current);

    final next = List<int>.from(current);
    var remaining = fullPercent - total;
    var cursor = 0;
    while (remaining > 0) {
      final index = targets[cursor % targets.length];
      next[index] = clampPercent(next[index] + 1);
      remaining -= 1;
      cursor += 1;
    }
    return next;
  }

  /// Moves leftover bps onto the no-prize item so the visible/spin totals stay 100%.
  /// Does not change other items' bps — leftover probability becomes "try again".
  static List<int> absorbDroppedBps({
    required List<int> keptBps,
    required int droppedBps,
    required int noPrizeIndex,
  }) {
    if (keptBps.isEmpty) return keptBps;
    final next = List<int>.from(keptBps);
    if (noPrizeIndex < 0 || noPrizeIndex >= next.length) return next;
    next[noPrizeIndex] = (next[noPrizeIndex] + droppedBps).clamp(0, fullBps);
    final extra = totalPercent(next) - fullBps;
    if (extra > 0) {
      next[noPrizeIndex] = (next[noPrizeIndex] - extra).clamp(0, fullBps);
    }
    return next;
  }
}
