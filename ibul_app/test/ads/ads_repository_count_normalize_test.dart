import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/ads/repositories/ads_repository.dart';

/// `select(...).count(CountOption.exact)` gerçek shape'i: int değil,
/// `.count` alanı olan bir response nesnesi. NaN.ceil kök nedeni buydu.
class _FakePostgrestResponse {
  const _FakePostgrestResponse(this.count);
  final int count;
}

class _NoCountShape {
  const _NoCountShape();
}

void main() {
  group('AdsRepository.normalizeCountResult', () {
    test('plain int passes through', () {
      expect(AdsRepository.normalizeCountResult(17), 17);
      expect(AdsRepository.normalizeCountResult(0), 0);
    });

    test('negative / NaN / infinite fall back to 0', () {
      expect(AdsRepository.normalizeCountResult(-3), 0);
      expect(AdsRepository.normalizeCountResult(double.nan), 0);
      expect(AdsRepository.normalizeCountResult(double.infinity), 0);
    });

    test('PostgrestResponse-like object resolves nested count '
        '(NaN.ceil root cause)', () {
      expect(
        AdsRepository.normalizeCountResult(const _FakePostgrestResponse(8)),
        8,
      );
    });

    test('unknown shapes and null fall back without throwing', () {
      expect(
        () => AdsRepository.normalizeCountResult(const _NoCountShape()),
        returnsNormally,
      );
      expect(AdsRepository.normalizeCountResult(const _NoCountShape()), 0);
      expect(AdsRepository.normalizeCountResult(null), 0);
      expect(AdsRepository.normalizeCountResult('junk'), 0);
    });

    test('double count floors safely', () {
      expect(AdsRepository.normalizeCountResult(9.0), 9);
      expect(AdsRepository.normalizeCountResult(9.7), 9);
    });
  });
}
