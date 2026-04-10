String formatPreparationTime(int minutes) {
  if (minutes <= 0) return '0 dk';

  if (minutes < 60) {
    return '$minutes dk';
  }

  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;

  if (remainingMinutes == 0) {
    return '$hours saat';
  }

  return '$hours saat $remainingMinutes dk';
}
