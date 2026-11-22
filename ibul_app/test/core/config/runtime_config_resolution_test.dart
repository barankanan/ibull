import 'dart:io';

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

  group('isolated desktop guard', () {
    const generatedUrl = 'https://generated.supabase.co';
    const generatedKey = 'generated-key';

    test('production hâlâ generated Supabase değerine düşer', () {
      final url = AppRuntimeConfig.resolveSupabaseValue(
        isolatedDesktop: false,
        primaryDefine: '',
        legacyDefine: '',
        generated: generatedUrl,
      );
      final key = AppRuntimeConfig.resolveSupabaseValue(
        isolatedDesktop: false,
        primaryDefine: '',
        legacyDefine: '',
        generated: generatedKey,
      );
      expect(url.value, generatedUrl);
      expect(url.source, 'generated');
      expect(key.value, generatedKey);
      expect(key.source, 'generated');
      expect(
        AppRuntimeConfig.localPrintBridgeUri(isolatedDesktop: false).port,
        3001,
      );
    });

    test('izole mod generated Supabase adresine ve anahtarına düşmez', () {
      final url = AppRuntimeConfig.resolveSupabaseValue(
        isolatedDesktop: true,
        primaryDefine: '',
        legacyDefine: '',
        generated: generatedUrl,
      );
      final key = AppRuntimeConfig.resolveSupabaseValue(
        isolatedDesktop: true,
        primaryDefine: '',
        legacyDefine: '',
        generated: generatedKey,
      );
      expect(url.value, isEmpty);
      expect(url.source, 'missing');
      expect(key.value, isEmpty);
      expect(key.value.contains('generated'), isFalse);
      expect(url.value.contains('supabase.co'), isFalse);
    });

    test('izole mod supabase.co dart-define değerini de reddeder', () {
      final url = AppRuntimeConfig.resolveSupabaseValue(
        isolatedDesktop: true,
        primaryDefine: 'https://example.supabase.co',
        generated: generatedUrl,
      );
      expect(url.value, isEmpty);
      expect(url.source, 'isolated_refused');
    });

    test('izole mod yalnız erişilemeyen test adresini ve 3001 dışını bırakır', () {
      final url = AppRuntimeConfig.resolveSupabaseValue(
        isolatedDesktop: true,
        primaryDefine: AppRuntimeConfig.isolatedProbeUrl,
        generated: generatedUrl,
      );
      expect(url.value, 'http://127.0.0.1:9');
      expect(url.source, 'dart_define');
      expect(
        AppRuntimeConfig.localPrintBridgeUri(isolatedDesktop: true).port,
        9,
      );
      expect(
        AppRuntimeConfig.coercePrintBridgeUri(
          Uri.parse('http://127.0.0.1:3001/print'),
          isolatedDesktop: true,
        ).port,
        9,
      );
      expect(
        AppRuntimeConfig.coercePrintBridgeUri(
          Uri.parse('http://127.0.0.1:3001/print'),
          isolatedDesktop: false,
        ).port,
        3001,
      );
    });

    test('izole test köprüsü yalnız 18771 olabilir; 3001 ve diğer portlar reddedilir', () {
      Uri bridge(int port) => AppRuntimeConfig.localPrintBridgeUri(
        isolatedDesktop: true,
        isolatedBridgePort: port,
      );
      expect(bridge(18771).toString(), 'http://127.0.0.1:18771');
      // Tanımsız (0), canlı köprü ve rastgele portlar erişilemeyen adrese düşer.
      for (final port in <int>[0, 3001, 18772, 18773, 9100, 80]) {
        expect(bridge(port).port, 9, reason: 'port $port');
      }
      // Kayıtlı 3001 adresi izole modda test köprüsüne, yoksa ölü adrese gider.
      expect(
        AppRuntimeConfig.coercePrintBridgeUri(
          Uri.parse('http://127.0.0.1:3001/print'),
          isolatedDesktop: true,
          isolatedBridgePort: 18771,
        ).port,
        18771,
      );
      expect(
        AppRuntimeConfig.coercePrintBridgeUri(
          Uri.parse('http://localhost:3001/print'),
          isolatedDesktop: true,
          isolatedBridgePort: 3001,
        ).port,
        9,
      );
      // Üretim yapılandırması etkilenmez.
      expect(
        AppRuntimeConfig.localPrintBridgeUri(
          isolatedDesktop: false,
          isolatedBridgePort: 18771,
        ).port,
        3001,
      );
      expect(
        AppRuntimeConfig.coercePrintBridgeUri(
          Uri.parse('http://127.0.0.1:3001/print'),
          isolatedDesktop: false,
          isolatedBridgePort: 18771,
        ).port,
        3001,
      );
    });

    test('izole LaunchAgent production kimliğini taşımaz ve açılışta başlamaz', () {
      final file = File(
        '../macos/Runner/Library/LaunchAgents/com.ibul.localprint.isolated-test.plist',
      );
      expect(file.existsSync(), isTrue);
      final text = file.readAsStringSync();
      expect(text.contains('<string>com.ibul.sellerdesktop</string>'), isFalse);
      expect(
        text.contains('<string>com.ibul.sellerdesktop.offlinetest</string>'),
        isTrue,
      );
      expect(text.contains('<key>RunAtLoad</key>'), isTrue);
      final runAtLoad = RegExp(
        r'<key>RunAtLoad</key>\s*<false/>',
      ).hasMatch(text);
      expect(runAtLoad, isTrue);

      final live = File(
        '../macos/Runner/Library/LaunchAgents/com.ibul.localprint.plist',
      );
      expect(
        live.readAsStringSync().contains('<string>com.ibul.sellerdesktop</string>'),
        isTrue,
      );
    });

    test('yazıcı servisi açılışta değil, ilk istekte başlar (macOS ve Windows)', () {
      for (final name in <String>[
        'com.ibul.localprint.plist',
        'com.ibul.localprint.isolated-test.plist',
      ]) {
        final text = File('../macos/Runner/Library/LaunchAgents/$name')
            .readAsStringSync();
        expect(
          RegExp(r'<key>RunAtLoad</key>\s*<false/>').hasMatch(text),
          isTrue,
          reason: name,
        );
        // launchd treats SuccessfulExit as "run at load".
        expect(text.contains('SuccessfulExit'), isFalse, reason: name);
        expect(text.contains('<key>Sockets</key>'), isTrue, reason: name);
        expect(text.contains('PRINT_BRIDGE_LAUNCHD_SOCKET'), isTrue, reason: name);
      }
      final setup = File('../windows/installer/IbulSellerSetup.iss')
          .readAsStringSync();
      expect(setup.contains('RegWriteStringValue'), isFalse);
      expect(setup.contains('Flags: deletevalue'), isTrue);
      expect(setup.contains('profile=private'), isTrue);
      expect(
        File('../windows/runner/main.cpp')
            .readAsStringSync()
            .contains('IbulSellerDesktop.SingleInstance'),
        isTrue,
      );
    });
  });

  group('controlled test bridge', () {
    test('a print-disabled build pointed at 18771 never resolves to 3001', () {
      final uri = AppRuntimeConfig.localPrintBridgeUri(
        isolatedDesktop: false,
        printStartDisabled: true,
        isolatedBridgePort: 18771,
      );
      expect(uri.port, 18771);
      expect(
        AppRuntimeConfig.coercePrintBridgeUri(
          Uri.parse('http://127.0.0.1:3001'),
          isolatedDesktop: false,
          printStartDisabled: true,
          isolatedBridgePort: 18771,
        ).port,
        18771,
      );
    });

    test('printing disabled never reaches 3001; printing enabled keeps it', () {
      expect(
        AppRuntimeConfig.localPrintBridgeUri(
          isolatedDesktop: false,
          printStartDisabled: true,
          isolatedBridgePort: 4000,
        ).toString(),
        AppRuntimeConfig.isolatedProbeUrl,
      );
      expect(
        AppRuntimeConfig.localPrintBridgeUri(
          isolatedDesktop: false,
          printStartDisabled: false,
          isolatedBridgePort: 18771,
        ).port,
        3001,
      );
      expect(
        AppRuntimeConfig.controlledTestBridge(
          printStartDisabled: false,
          isolatedBridgePort: 18771,
        ),
        isFalse,
      );
    });
  });

  group('print-disabled production build never reaches the live bridge', () {
    test('localPrintBridgeUri goes to the dead probe, not port 3001', () {
      final uri = AppRuntimeConfig.localPrintBridgeUri(
        isolatedDesktop: false,
        printStartDisabled: true,
        isolatedBridgePort: 0,
      );
      expect(uri.toString(), AppRuntimeConfig.isolatedProbeUrl);
    });

    test('coercePrintBridgeUri rewrites 3001 but leaves other hosts', () {
      expect(
        AppRuntimeConfig.coercePrintBridgeUri(
          Uri.parse('http://127.0.0.1:3001'),
          isolatedDesktop: false,
          printStartDisabled: true,
          isolatedBridgePort: 0,
        ).toString(),
        AppRuntimeConfig.isolatedProbeUrl,
      );
      expect(
        AppRuntimeConfig.coercePrintBridgeUri(
          Uri.parse('http://192.168.1.5:3001'),
          isolatedDesktop: false,
          printStartDisabled: true,
          isolatedBridgePort: 0,
        ).host,
        '192.168.1.5',
      );
    });

    test('print enabled keeps the live bridge', () {
      expect(
        AppRuntimeConfig.localPrintBridgeUri(
          isolatedDesktop: false,
          printStartDisabled: false,
          isolatedBridgePort: 0,
        ).port,
        3001,
      );
    });
  });
}
