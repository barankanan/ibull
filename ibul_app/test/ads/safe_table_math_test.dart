import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/ads/helpers/safe_table_math.dart';

void main() {
  group('SafeTableMath.safeCount', () {
    test('normal int passes through', () {
      expect(SafeTableMath.safeCount(42), 42);
      expect(SafeTableMath.safeCount(0), 0);
    });

    test('negative falls back', () {
      expect(SafeTableMath.safeCount(-5), 0);
      expect(SafeTableMath.safeCount(-5, fallback: 3), 3);
    });

    test('NaN / infinity fall back', () {
      expect(SafeTableMath.safeCount(double.nan), 0);
      expect(SafeTableMath.safeCount(double.infinity), 0);
      expect(SafeTableMath.safeCount(double.negativeInfinity), 0);
    });

    test('double floors, string parses, junk falls back', () {
      expect(SafeTableMath.safeCount(7.9), 7);
      expect(SafeTableMath.safeCount('12'), 12);
      expect(SafeTableMath.safeCount('abc'), 0);
      expect(SafeTableMath.safeCount(null), 0);
      expect(SafeTableMath.safeCount(Object()), 0);
    });
  });

  group('SafeTableMath.safeCeil', () {
    test('does not throw for NaN (NaN.ceil regression)', () {
      expect(() => SafeTableMath.safeCeil(double.nan), returnsNormally);
      expect(SafeTableMath.safeCeil(double.nan, fallback: 1), 1);
      expect(SafeTableMath.safeCeil(double.infinity, fallback: 1), 1);
    });

    test('normal values ceil', () {
      expect(SafeTableMath.safeCeil(1.1), 2);
      expect(SafeTableMath.safeCeil(3), 3);
    });
  });

  group('SafeTableMath.safePageCount', () {
    test('empty table returns 1 page and never NaN', () {
      expect(
        SafeTableMath.safePageCount(totalRowCount: 0, pageSize: 10),
        1,
      );
    });

    test('pageSize 0 does not divide by zero', () {
      expect(
        SafeTableMath.safePageCount(totalRowCount: 25, pageSize: 0),
        1,
      );
    });

    test('NaN totalRowCount does not produce NaN page count', () {
      expect(
        () => SafeTableMath.safePageCount(
          totalRowCount: double.nan,
          pageSize: 10,
        ),
        returnsNormally,
      );
      expect(
        SafeTableMath.safePageCount(totalRowCount: double.nan, pageSize: 10),
        1,
      );
    });

    test('junk (non-num) totalRowCount does not crash', () {
      expect(
        SafeTableMath.safePageCount(totalRowCount: Object(), pageSize: 10),
        1,
      );
    });

    test('normal pagination math', () {
      expect(
        SafeTableMath.safePageCount(totalRowCount: 25, pageSize: 10),
        3,
      );
      expect(
        SafeTableMath.safePageCount(totalRowCount: 30, pageSize: 10),
        3,
      );
      expect(
        SafeTableMath.safePageCount(totalRowCount: 1, pageSize: 10),
        1,
      );
    });
  });

  group('SafeTableMath.safeColumnWidth', () {
    test('NaN/inf/zero width falls back', () {
      expect(SafeTableMath.safeColumnWidth(double.nan), 120.0);
      expect(SafeTableMath.safeColumnWidth(double.infinity), 120.0);
      expect(SafeTableMath.safeColumnWidth(0), 120.0);
      expect(SafeTableMath.safeColumnWidth(-10), 120.0);
    });

    test('clamps into min/max', () {
      expect(SafeTableMath.safeColumnWidth(5, min: 24), 24.0);
      expect(SafeTableMath.safeColumnWidth(9000, max: 600), 600.0);
      expect(SafeTableMath.safeColumnWidth(130), 130.0);
    });
  });
}
