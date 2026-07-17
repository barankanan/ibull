import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/config/runtime_config.dart';

void main() {
  group('AppRuntimeConfig.sanitizeEnvValue', () {
    test('değeri trim eder', () {
      expect(
        AppRuntimeConfig.sanitizeEnvValue('  https://x.supabase.co  '),
        'https://x.supabase.co',
      );
    });

    test('boş / whitespace değerleri boş kabul eder', () {
      expect(AppRuntimeConfig.sanitizeEnvValue(null), '');
      expect(AppRuntimeConfig.sanitizeEnvValue(''), '');
      expect(AppRuntimeConfig.sanitizeEnvValue('   '), '');
      expect(AppRuntimeConfig.sanitizeEnvValue('\t\n'), '');
    });

    test('"null" ve "undefined" değerlerini boş kabul eder (case-insensitive)', () {
      expect(AppRuntimeConfig.sanitizeEnvValue('null'), '');
      expect(AppRuntimeConfig.sanitizeEnvValue('NULL'), '');
      expect(AppRuntimeConfig.sanitizeEnvValue('Null '), '');
      expect(AppRuntimeConfig.sanitizeEnvValue('undefined'), '');
      expect(AppRuntimeConfig.sanitizeEnvValue('UNDEFINED'), '');
    });

    test('geçerli değeri aynen döner', () {
      expect(AppRuntimeConfig.sanitizeEnvValue('eyKey123'), 'eyKey123');
    });
  });

  group('AppRuntimeConfig.resolveWithFallback', () {
    const url = 'https://abcd1234.supabase.co';
    const legacyUrl = 'https://legacy.supabase.co';
    const generatedUrl = 'https://generated.supabase.co';

    test('dart-define doluysa onu kullanır (source=dart_define)', () {
      final r = AppRuntimeConfig.resolveWithFallback(
        primaryDefine: url,
        legacyDefine: legacyUrl,
        generated: generatedUrl,
      );
      expect(r.value, url);
      expect(r.source, 'dart_define');
      expect(r.isPresent, isTrue);
    });

    test('dart-define boşsa legacy define kullanır (source=legacy_define)', () {
      final r = AppRuntimeConfig.resolveWithFallback(
        primaryDefine: '',
        legacyDefine: legacyUrl,
        generated: generatedUrl,
      );
      expect(r.value, legacyUrl);
      expect(r.source, 'legacy_define');
    });

    test('define yokken generated fallback okunur (source=generated)', () {
      final r = AppRuntimeConfig.resolveWithFallback(
        primaryDefine: '',
        legacyDefine: '',
        generated: generatedUrl,
      );
      expect(r.value, generatedUrl);
      expect(r.source, 'generated');
    });

    test('hepsi boşsa missing döner ve value boştur', () {
      final r = AppRuntimeConfig.resolveWithFallback(
        primaryDefine: '',
        legacyDefine: '',
        generated: '',
      );
      expect(r.value, '');
      expect(r.source, 'missing');
      expect(r.isPresent, isFalse);
    });

    test('"null"/"undefined" dart-define değeri sonraki katmana düşer', () {
      final r1 = AppRuntimeConfig.resolveWithFallback(
        primaryDefine: 'null',
        legacyDefine: legacyUrl,
      );
      expect(r1.value, legacyUrl);
      expect(r1.source, 'legacy_define');

      final r2 = AppRuntimeConfig.resolveWithFallback(
        primaryDefine: 'undefined',
        legacyDefine: '  ',
        generated: generatedUrl,
      );
      expect(r2.value, generatedUrl);
      expect(r2.source, 'generated');
    });

    test('dolu dart-define hiçbir katmana düşmez, hata da atmaz', () {
      final r = AppRuntimeConfig.resolveWithFallback(
        primaryDefine: '  $url  ',
      );
      expect(r.value, url); // trim edilmiş
      expect(r.source, 'dart_define');
    });
  });

  group('Supabase resolved getters (ortamdan bağımsız tutarlılık)', () {
    test('hasSupabaseConfig, resolved değerlerle tutarlıdır', () {
      final url = AppRuntimeConfig.supabaseUrlResolved;
      final key = AppRuntimeConfig.supabaseAnonKeyResolved;
      expect(
        AppRuntimeConfig.hasSupabaseConfig,
        url.isPresent && key.isPresent,
      );
    });

    test('resolved source geçerli bir etikettir', () {
      const validSources = {
        'dart_define',
        'legacy_define',
        'generated',
        'missing',
      };
      expect(
        validSources.contains(AppRuntimeConfig.supabaseUrlResolved.source),
        isTrue,
      );
      expect(
        validSources.contains(AppRuntimeConfig.supabaseAnonKeyResolved.source),
        isTrue,
      );
    });

    test('logSupabaseConfigDiagnostics hata atmaz ve key sızdırmaz', () {
      expect(AppRuntimeConfig.logSupabaseConfigDiagnostics, returnsNormally);
    });
  });

  group('AppRuntimeConfig.safeDiagnostics', () {
    test('hata atmaz ve beklenen alanları içerir', () {
      final diag = AppRuntimeConfig.safeDiagnostics();
      const expectedKeys = {
        'buildMarker',
        'buildShaHint',
        'supabaseUrlPresent',
        'supabaseAnonKeyPresent',
        'supabaseUrlHost',
        'anonKeyLength',
        'configSource',
        'generatedUrlPresent',
        'generatedAnonKeyLength',
        'dartDefineUrlPresent',
        'legacyUrlPresent',
        'missingKey',
        'firebaseAndroidApiKeyPresent',
        'firebaseAndroidApiKeyLength',
        'firebaseAndroidAppIdPresent',
        'firebaseProjectId',
        'firebaseSource',
        'firebaseMissingKey',
      };
      expect(diag.keys.toSet(), expectedKeys);
    });

    test('anon key değerinin kendisini hiçbir alanda içermez', () {
      final anonKey = AppRuntimeConfig.rawSupabaseAnonKey;
      final diag = AppRuntimeConfig.safeDiagnostics();
      for (final entry in diag.entries) {
        if (anonKey.isNotEmpty) {
          expect(
            entry.value.contains(anonKey),
            isFalse,
            reason: 'safeDiagnostics["${entry.key}"] anon key sızdırıyor',
          );
        }
        // Değerler sadece length/presence/marker olmalı; JWT payload'ı olamaz.
        expect(entry.value.startsWith('eyJ'), isFalse);
      }
    });

    test('anonKeyLength sadece uzunluk döner, değeri değil', () {
      final diag = AppRuntimeConfig.safeDiagnostics();
      final anonKey = AppRuntimeConfig.rawSupabaseAnonKey;
      expect(diag['anonKeyLength'], '${anonKey.length}');
    });

    test('Firebase Android API key değerini hiçbir alanda içermez', () {
      final apiKey = AppRuntimeConfig.firebaseAndroidApiKeyResolved.value;
      final diag = AppRuntimeConfig.safeDiagnostics();
      if (apiKey.isEmpty) return;
      for (final entry in diag.entries) {
        expect(
          entry.value.contains(apiKey),
          isFalse,
          reason:
              'safeDiagnostics["${entry.key}"] Firebase API key sızdırıyor',
        );
      }
      expect(diag['firebaseAndroidApiKeyPresent'], 'true');
      expect(diag['firebaseAndroidApiKeyLength'], '${apiKey.length}');
    });

    test('firebaseSource geçerli bir kaynak etiketi döner', () {
      final diag = AppRuntimeConfig.safeDiagnostics();
      const validSources = {'dart_define', 'legacy_define', 'generated', 'missing'};
      final source = diag['firebaseSource']!;
      expect(
        validSources.contains(source) || source.startsWith('mixed('),
        isTrue,
        reason: 'beklenmeyen firebaseSource: $source',
      );
    });
  });

  group('AppRuntimeConfig.missingFirebaseAndroidKeyNames', () {
    const present = ResolvedRuntimeValue('value', 'dart_define');
    const absent = ResolvedRuntimeValue('', 'missing');

    test('API key yoksa IBUL_FIREBASE_ANDROID_API_KEY döner', () {
      final missing = AppRuntimeConfig.missingFirebaseAndroidKeyNames(
        apiKey: absent,
        appId: present,
        senderId: present,
        projectId: present,
        storageBucket: present,
      );
      expect(missing, 'IBUL_FIREBASE_ANDROID_API_KEY');
    });

    test('hepsi doluysa boş string döner', () {
      final missing = AppRuntimeConfig.missingFirebaseAndroidKeyNames(
        apiKey: present,
        appId: present,
        senderId: present,
        projectId: present,
        storageBucket: present,
      );
      expect(missing, isEmpty);
    });

    test('birden çok eksikte tümünü isim isim listeler', () {
      final missing = AppRuntimeConfig.missingFirebaseAndroidKeyNames(
        apiKey: absent,
        appId: absent,
        senderId: present,
        projectId: absent,
        storageBucket: present,
      );
      expect(
        missing,
        'IBUL_FIREBASE_ANDROID_API_KEY,'
        'IBUL_FIREBASE_ANDROID_APP_ID,'
        'IBUL_FIREBASE_PROJECT_ID',
      );
    });
  });

  group('Firebase Android generated fallback', () {
    test('dart-define boşken generated değer okunur (source=generated)', () {
      final r = AppRuntimeConfig.resolveWithFallback(
        primaryDefine: '',
        generated: 'AIzaFakeGeneratedKey123',
      );
      expect(r.value, 'AIzaFakeGeneratedKey123');
      expect(r.source, 'generated');
    });

    test('resolved getter\'lar hata atmaz ve tutarlı source döner', () {
      const validSources = {'dart_define', 'legacy_define', 'generated', 'missing'};
      for (final resolved in [
        AppRuntimeConfig.firebaseAndroidApiKeyResolved,
        AppRuntimeConfig.firebaseAndroidAppIdResolved,
        AppRuntimeConfig.firebaseMessagingSenderIdResolved,
        AppRuntimeConfig.firebaseProjectIdResolved,
        AppRuntimeConfig.firebaseStorageBucketResolved,
      ]) {
        expect(validSources.contains(resolved.source), isTrue);
        expect(resolved.isPresent, resolved.value.isNotEmpty);
      }
    });
  });

  group('AppRuntimeConfig.maskSecrets', () {
    test('gerçek anon key değerini maskeler', () {
      final anonKey = AppRuntimeConfig.rawSupabaseAnonKey;
      if (anonKey.isEmpty) return;
      final masked = AppRuntimeConfig.maskSecrets('error: $anonKey happened');
      expect(masked.contains(anonKey), isFalse);
      expect(masked.contains('***anonKey(len=${anonKey.length})***'), isTrue);
    });

    test('JWT benzeri değerleri maskeler', () {
      const fakeJwt =
          'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dGhpc2lzYWZha2VzaWc';
      final masked = AppRuntimeConfig.maskSecrets('token=$fakeJwt end');
      expect(masked.contains(fakeJwt), isFalse);
      expect(masked.contains('***jwt***'), isTrue);
    });

    test('secret içermeyen metni değiştirmeden döner', () {
      const plain = 'plain error with no secrets';
      expect(AppRuntimeConfig.maskSecrets(plain), plain);
    });
  });
}
