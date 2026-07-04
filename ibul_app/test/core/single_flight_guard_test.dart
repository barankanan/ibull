import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/single_flight_guard.dart';

void main() {
  group('SingleFlightGuard (product duplicate request guard)', () {
    test('skips a second concurrent begin while in flight', () {
      final guard = SingleFlightGuard();
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);

      expect(guard.tryBegin(now: t0), isTrue);
      // A duplicate home product fetch while one is running must be skipped.
      expect(guard.tryBegin(now: t0), isFalse);
      expect(guard.isInFlight, isTrue);

      guard.finish();
      expect(guard.isInFlight, isFalse);
    });

    test('debounces rapid retries within the window', () {
      final guard = SingleFlightGuard(debounce: const Duration(seconds: 2));
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);

      expect(guard.tryBegin(now: t0), isTrue);
      guard.finish();

      // Retry 1s later — still inside debounce window, must be skipped.
      expect(guard.tryBegin(now: t0.add(const Duration(seconds: 1))), isFalse);

      // Retry after the debounce window — allowed again.
      expect(guard.tryBegin(now: t0.add(const Duration(seconds: 3))), isTrue);
    });

    test('reset clears in-flight and debounce state', () {
      final guard = SingleFlightGuard();
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);

      expect(guard.tryBegin(now: t0), isTrue);
      guard.reset();

      expect(guard.isInFlight, isFalse);
      expect(guard.tryBegin(now: t0), isTrue);
    });
  });
}
