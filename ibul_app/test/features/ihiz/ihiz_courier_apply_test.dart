import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/ihiz/apply/ihiz_courier_apply_page.dart';
import 'package:ibul_app/features/ihiz/apply/ihiz_courier_apply_validator.dart';
import 'package:ibul_app/features/ihiz/apply/ihiz_courier_apply_widgets.dart';
import 'package:ibul_app/screens/ihiz_courier_page.dart';
import 'package:ibul_app/services/ihiz_courier_application_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const testSupabaseUrl = String.fromEnvironment(
    'IBUL_SUPABASE_URL',
    defaultValue: 'https://example.supabase.co',
  );
  const testSupabaseAnonKey = String.fromEnvironment(
    'IBUL_SUPABASE_ANON_KEY',
    defaultValue: 'test-anon-key',
  );

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: testSupabaseUrl,
      anonKey: testSupabaseAnonKey,
    );
  });

  group('IhizCourierApplyValidator', () {
    test('step one rejects short phone/tc/password', () {
      final invalid = IhizCourierApplyValidator.validateStepOne(
        firstName: '',
        lastName: 'Yılmaz',
        phone: '05',
        tcNumber: '123',
        birthDate: '',
        email: 'bad',
        password: '123',
      );
      expect(invalid, containsAll([
        'first_name',
        'phone',
        'tc_number',
        'birth_date',
        'email',
        'password',
      ]));
    });

    test('step five requires TR IBAN with 24 digits', () {
      final invalid = IhizCourierApplyValidator.validateStepFive(
        paymentAccountHolder: 'Ali',
        paymentBankName: 'Banka',
        paymentIban: 'TR00',
      );
      expect(invalid, contains('payment_iban'));

      final ok = IhizCourierApplyValidator.validateStepFive(
        paymentAccountHolder: 'Ali',
        paymentBankName: 'Banka',
        paymentIban: 'TR330006100519786457841326',
      );
      expect(ok, isEmpty);
    });

    test('company without tax number fails when company selected', () {
      final invalid = IhizCourierApplyValidator.validateStepTwo(
        licenseType: 'A1',
        motorType: '50 CC',
        criminalRecord: 'Yok',
        companyType: 'Limited Şirket',
        taxNumber: '123',
      );
      expect(invalid, contains('tax_number'));
    });
  });

  group('IhizCourierApplicationService payload', () {
    test('buildApplicationRow uses exact ihiz_web field names', () {
      final service = IhizCourierApplicationService();
      final bytes = Uint8List.fromList([1, 2, 3]);
      final doc = IhizPickedDocument(name: 'a.jpg', bytes: bytes);
      final meta = const IhizUploadedDocumentMeta(
        fileName: 'a.jpg',
        fileSize: 3,
        publicUrl: 'https://example.com/a.jpg',
      );
      final row = service.buildApplicationRow(
        userId: 'user-1',
        input: IhizCourierApplicationSubmitInput(
          fullName: 'Ali Veli',
          phone: '05551112233',
          tcNumber: '12345678901',
          birthDate: '01 / 01 / 1990',
          licenseType: 'A1',
          motorType: '50 CC',
          criminalRecord: 'Yok',
          companyType: 'Şirketim yok',
          taxNumber: '',
          city: 'İstanbul',
          district: 'Kadıköy',
          availability: 'Akşam',
          email: 'Ali@Example.com',
          password: 'secret1',
          note: 'Not',
          paymentAccountHolder: 'Ali Veli',
          paymentBankName: 'Banka',
          paymentIban: 'tr 330006100519786457841326',
          driverLicenseFront: doc,
          driverLicenseBack: doc,
          vehicleRegistration: doc,
        ),
        driverFront: meta,
        driverBack: meta,
        vehicleRegistration: meta,
        nowIso: '2026-08-11T00:00:00.000Z',
      );

      expect(row['user_id'], 'user-1');
      expect(row['status'], 'pending');
      expect(row['full_name'], 'Ali Veli');
      expect(row['tc_number'], '12345678901');
      expect(row['email'], 'ali@example.com');
      expect(row['payment_iban'], 'TR330006100519786457841326');
      expect(row['driver_license_front_url'], 'https://example.com/a.jpg');
      expect(row['driver_license_back_file_name'], 'a.jpg');
      expect(row['vehicle_registration_url'], 'https://example.com/a.jpg');
      expect(row['rejection_reason'], isNull);
      expect(row['approved_at'], isNull);
      expect(row['push_notifications_enabled'], isTrue);
      expect(row.containsKey('license_type'), isTrue);
      expect(row.containsKey('motor_type'), isTrue);
      expect(row.containsKey('criminal_record'), isTrue);
    });

    test('normalizeSubmissionError hides Postgrest/Storage noise', () {
      final service = IhizCourierApplicationService();
      expect(
        service.normalizeSubmissionError(
          const PostgrestException(message: 'duplicate key', code: '23505'),
        ),
        isNot(contains('Postgrest')),
      );
      expect(
        service.normalizeSubmissionError(
          const StorageException('bucket missing'),
        ),
        contains('Belge'),
      );
    });
  });

  Widget wrap(Size viewport, Widget child) {
    return MaterialApp(
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(size: viewport),
          child: child!,
        );
      },
      home: child,
    );
  }

  testWidgets('Kurye Ol opens courier application page', (tester) async {
    const viewport = Size(390, 844);
    await tester.binding.setSurfaceSize(viewport);
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(wrap(viewport, const IhizCourierPage()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final kuryeOl = find.text('Kurye Ol').at(0);
    await tester.ensureVisible(kuryeOl);
    await tester.tap(kuryeOl);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(IhizCourierApplyPage), findsOneWidget);
    expect(find.text('Kurye başvuru formu'), findsOneWidget);
    expect(find.text('Kurye başvurusu yakında açılacak.'), findsNothing);
  });

  testWidgets('Giriş Yap opens LoginPage', (tester) async {
    const viewport = Size(390, 844);
    await tester.binding.setSurfaceSize(viewport);
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(wrap(viewport, const IhizCourierPage()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final loginCta = find.text('Giriş Yap').at(0);
    await tester.ensureVisible(loginCta);
    await tester.tap(loginCta);
    await tester.pump();
    // Deferred login library + route push.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
    expect(find.text('İhız kurye paneline giriş'), findsOneWidget);
    expect(find.text('Kurye Paneline Gir'), findsOneWidget);
  });

  testWidgets('apply page mobile has no overflow on first step', (tester) async {
    const viewport = Size(360, 720);
    await tester.binding.setSurfaceSize(viewport);
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(wrap(viewport, const IhizCourierApplyPage()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
    expect(find.text('Kurye başvuru formu'), findsOneWidget);
    expect(find.text('Ad'), findsOneWidget);

    await tester.tap(find.text('Devam'));
    await tester.pump();
    expect(find.textContaining('zorunlu'), findsWidgets);
  });

  testWidgets('success state shows professional copy', (tester) async {
    const viewport = Size(800, 900);
    await tester.binding.setSurfaceSize(viewport);
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      wrap(
        viewport,
        Scaffold(
          body: IhizApplySuccessView(
            onLogin: () {},
            onDone: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Başvurunuz başarıyla alındı.'), findsOneWidget);
    expect(
      find.textContaining('incelendikten sonra sonuç'),
      findsOneWidget,
    );
    expect(find.text('Giriş Yap'), findsOneWidget);
  });
}
