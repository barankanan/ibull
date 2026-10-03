import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/app/marketplace_paths.dart';
import 'package:ibul_app/features/mall/application/mall_application_page.dart';
import 'package:ibul_app/features/mall/models/mall_application.dart';
import 'package:ibul_app/features/mall/services/mall_application_repository.dart';
import 'package:ibul_app/features/mall/widgets/mall_application_form.dart';

void main() {
  test('status enum maps known values and survives unknown', () {
    expect(
      MallApplicationStatus.fromDb('pending_review'),
      MallApplicationStatus.pendingReview,
    );
    expect(
      MallApplicationStatus.fromDb('needs_info'),
      MallApplicationStatus.needsInfo,
    );
    expect(MallApplicationStatus.fromDb('published'), MallApplicationStatus.unknown);
    expect(MallApplicationStatus.unknown.dbValue, 'unknown');
  });

  test('fromMap reads backend columns without throwing', () {
    final application = MallApplication.fromMap({
      'id': 'app-1',
      'applicant_user_id': 'user-1',
      'mall_name': 'Prime Mall',
      'city': 'Hatay',
      'district': 'İskenderun',
      'address_text': 'Sahil',
      'latitude': 36.58,
      'longitude': 36.17,
      'authorized_person_name': 'Ayşe',
      'authorized_person_title': 'Müdür',
      'document_paths': ['uid/mall-applications/app-1/belge.pdf'],
      'status': 'approved',
      'created_mall_id': 'mall-1',
      'is_verified_noise': true,
    });
    expect(application.mallName, 'Prime Mall');
    expect(application.status, MallApplicationStatus.approved);
    expect(application.createdMallId, 'mall-1');
    expect(application.documentPaths, hasLength(1));
  });

  test('draft payload omits status and audit fields', () {
    const draft = MallApplicationDraft(
      mallName: 'Prime Mall',
      city: 'Hatay',
      district: 'İskenderun',
      addressText: 'Sahil',
      latitude: 36.5,
      longitude: 36.1,
      authorizedPersonName: 'Ayşe',
      authorizedPersonTitle: 'Müdür',
      documentPaths: ['uid/mall-applications/app/belge.pdf'],
    );
    final row = draft.toContentRow('user-1');
    expect(row['applicant_user_id'], 'user-1');
    expect(row.containsKey('status'), isFalse);
    expect(row.containsKey('admin_note'), isFalse);
    expect(row.containsKey('created_mall_id'), isFalse);
    expect(row['mall_name'], 'Prime Mall');
  });

  test('validation matches required backend fields', () {
    const empty = MallApplicationDraft(
      mallName: '',
      city: '',
      district: '',
      addressText: '',
      authorizedPersonName: '',
      authorizedPersonTitle: '',
    );
    final errors = MallApplicationValidation.submitErrors(empty);
    expect(errors, contains('AVM adı zorunlu'));
    expect(errors, contains('Haritadan konum seçin'));
    expect(errors, contains('Faaliyet Belgesi yükleyin'));
    expect(
      MallApplicationValidation.optionalWebsiteError('https://prime.example'),
      isNull,
    );
    expect(MallApplicationValidation.optionalWebsiteError('primemall.com.tr'), isNull);
    expect(MallApplicationValidation.normalizeWebsite('primemall.com.tr'), 'https://primemall.com.tr');
    expect(MallApplicationValidation.optionalWebsiteError('abc xyz'), isNotNull);
    final withWebsite = MallApplicationDraft(
      mallName: 'Prime',
      city: 'Hatay',
      district: 'İskenderun',
      addressText: 'Sahil',
      latitude: 36,
      longitude: 36,
      authorizedPersonName: 'Ayşe',
      authorizedPersonTitle: 'Müdür',
      website: 'not a url',
    );
    expect(
      MallApplicationValidation.uploadDraftErrors(withWebsite),
      isNot(contains('Geçerli bir web sitesi girin (ör. primall.com).')),
    );
    expect(
      MallApplicationValidation.draftErrors(withWebsite),
      isEmpty,
      reason: 'drafts only follow DB constraints',
    );
    expect(
      MallApplicationValidation.submitErrors(withWebsite),
      contains('Geçerli bir web sitesi girin (ör. primall.com).'),
    );
    expect(MallApplicationValidation.optionalPhoneError(''), isNull);
    expect(MallApplicationValidation.optionalPhoneError('123'), isNotNull);
    expect(MallApplicationValidation.parseDeclaredFloorCount(''), isNull);
    expect(MallApplicationValidation.parseDeclaredFloorCount('0'), 0);
    expect(MallApplicationValidation.floorCountError(''), isNull);
    expect(MallApplicationValidation.floorCountError('0'), isNotNull);
    expect(MallApplicationValidation.floorCountError('41'), isNotNull);
    expect(MallApplicationValidation.floorCountError('3'), isNull);
    final draft = MallApplicationValidation.draftErrors(empty);
    expect(draft, isNot(contains('En az bir yetki belgesi yükleyin')));
    expect(draft, isNot(contains('Kat sayısı 1 ile 40 arasında olmalı')));
    expect(
      MallApplicationValidation.documentFileAllowed(
        fileName: 'yetki.pdf',
        byteLength: 100,
      ),
      isTrue,
    );
    expect(
      MallApplicationValidation.documentFileAllowed(
        fileName: 'not.txt',
        byteLength: 100,
      ),
      isFalse,
    );
  });

  test('submit issues use uploaded slots, not path count', () {
    const full = MallApplicationDraft(
      mallName: 'Prime',
      legalName: 'Prime A.Ş.',
      taxNumber: '1234567890',
      taxOffice: 'Çankaya',
      mersisNo: '0123456789012345',
      tradeRegistryNo: '1234',
      city: 'Ankara',
      district: 'Çankaya',
      addressText: 'Sahil',
      latitude: 39.9,
      longitude: 32.8,
      authorizedPersonName: 'Ayşe Yılmaz',
      authorizedPersonTitle: 'Müdür',
    );
    final allKinds = [for (final slot in MallDocumentSlot.all) slot.kind];
    expect(
      MallApplicationValidation.submitIssues(full, documentKinds: allKinds),
      isEmpty,
    );
    final missing = MallApplicationValidation.submitIssues(
      full,
      documentKinds: allKinds.where((kind) => kind != 'activity'),
    );
    expect(missing.map((issue) => issue.field), ['Faaliyet Belgesi']);
    expect(missing.single.step, 4);
    expect(MallApplicationValidation.draftErrors(full), isEmpty);
    expect(
      MallApplicationValidation.draftErrors(
        const MallApplicationDraft(
          mallName: 'Prime',
          city: 'Ankara',
          district: 'Çankaya',
          addressText: 'Sahil',
          latitude: 39.9,
          longitude: 32.8,
          authorizedPersonName: 'Ayşe',
          authorizedPersonTitle: 'Müdür',
        ),
      ),
      isEmpty,
      reason: 'half-filled draft without tax, MERSİS or documents saves',
    );
  });

  test('primary application prefers needs_info over approved', () {
    final picked = pickPrimaryMallApplication([
      _sample(MallApplicationStatus.approved, 'approved'),
      _sample(MallApplicationStatus.needsInfo, 'needs'),
    ]);
    expect(picked?.id, 'needs');
  });

  testWidgets('empty mall application home offers start', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MallApplicationHome(
            application: null,
            onStart: () {},
          ),
        ),
      ),
    );
    expect(find.text('Başvuru Başlat'), findsOneWidget);
    expect(find.textContaining('haritasına'), findsOneWidget);
  });

  test('logo and cover accept the same image types as the media bucket', () {
    expect(
      MallApplicationValidation.imageFileAllowed(
        fileName: 'logo.webp',
        byteLength: 1000,
      ),
      isTrue,
    );
    expect(
      MallApplicationValidation.imageFileAllowed(
        fileName: 'logo.gif',
        byteLength: 1000,
      ),
      isFalse,
    );
    expect(
      MallApplicationValidation.imageFileAllowed(
        fileName: 'logo.jpg',
        byteLength: MallApplicationValidation.maxImageBytes + 1,
      ),
      isFalse,
    );
  });

  testWidgets('document step shows logo and cover upload without the old warning', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MallApplicationWizard(
              repository: MallApplicationRepository(),
              initialStep: 4,
              onFinished: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('hazır değil'), findsNothing);
    expect(find.text('Logo Yükle'), findsOneWidget);
    expect(find.text('Kapak Yükle'), findsOneWidget);
    expect(find.text('Yetki Belgesi Yükle'), findsOneWidget);
    expect(find.textContaining('AVM Yönetim Yetki Belgesi'), findsOneWidget);
    expect(MarketplacePaths.mallApplication, '/avm/basvuru');
    expect(MarketplacePaths.legacyPublicMallApplication, '/avm-basvurusu');
    expect(find.text('Ticaret Sicil Gazetesi'), findsOneWidget);
    expect(find.text('Vergi Levhası'), findsOneWidget);
    expect(find.text('Faaliyet Belgesi'), findsOneWidget);
    expect(find.text('İmza Sirküleri / Beyannamesi'), findsOneWidget);
    expect(find.text('Yetkili Kimlik Belgesi'), findsOneWidget);
  });

  testWidgets('logged out wizard starts on the account step', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MallApplicationWizard(
              repository: MallApplicationRepository(),
              onFinished: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Şifre *'), findsOneWidget);
    expect(find.text('Şifre tekrar *'), findsOneWidget);
    expect(find.text('İşletme Bilgileri'), findsNothing);
    expect(find.text('/login'), findsNothing);
    expect(find.text('/register'), findsNothing);
  });

  testWidgets('signed in wizard hides password fields', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MallApplicationWizard(
              repository: MallApplicationRepository(),
              forceSignedIn: true,
              onFinished: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Şifre *'), findsNothing);
    expect(find.text('Yetkili görevi / ünvanı *'), findsOneWidget);
    expect(find.text('Ad *'), findsOneWidget);
  });

  test('business validators follow the DB rules and accept an empty KEP', () {
    expect(
      MallApplicationValidation.taxNumberError('21231232'),
      'Vergi numarası 10 veya 11 haneli olmalıdır.',
    );
    expect(MallApplicationValidation.taxNumberError('1234567890'), isNull);
    expect(MallApplicationValidation.taxNumberError('12345678901'), isNull);
    expect(
      MallApplicationValidation.mersisError('1231334'),
      'MERSİS numarası 16 haneli olmalıdır.',
    );
    expect(MallApplicationValidation.mersisError('0123456789012345'), isNull);
    expect(MallApplicationValidation.optionalKepError(''), isNull);
    expect(MallApplicationValidation.optionalKepError('ornek@hs01.kep.tr'), isNull);
    expect(
      MallApplicationValidation.optionalKepError('hatay iskenderun numune mahallesi'),
      isNotNull,
    );
    expect(MallApplicationValidation.stepForError('KEP adresi e-posta biçiminde'), 1);
    expect(
      MallApplicationValidation.normalizeWebsite('primall.com'),
      'https://primall.com',
    );
    expect(MallApplicationValidation.optionalWebsiteError('primall.com'), isNull);
  });

  testWidgets('business step shows errors under inputs and blocks Devam Et', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MallApplicationWizard(
              repository: MallApplicationRepository(),
              forceSignedIn: true,
              initialStep: 1,
              onFinished: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    Finder input(String label) => find.widgetWithText(TextField, label);
    String text(String label) => tester.widget<TextField>(input(label)).controller!.text;

    await tester.enterText(input('Vergi numarası *'), '21ab231232');
    await tester.enterText(input('MERSİS numarası *'), '1231334');
    await tester.enterText(input('KEP adresi'), 'hatay iskenderun numune mahallesi');
    await tester.pump();
    expect(text('Vergi numarası *'), '21231232', reason: 'letters are filtered');
    expect(find.text('Vergi numarası 10 veya 11 haneli olmalıdır.'), findsOneWidget);
    expect(find.text('MERSİS numarası 16 haneli olmalıdır.'), findsOneWidget);
    expect(find.textContaining('KEP adresi e-posta biçiminde'), findsOneWidget);
    expect(find.text('Unvan zorunlu'), findsNothing, reason: 'untouched until Devam Et');

    await tester.tap(find.widgetWithText(FilledButton, 'Devam Et'));
    await tester.pump();
    expect(find.text('İşletme Bilgileri'), findsOneWidget);
    expect(find.text('Unvan zorunlu'), findsOneWidget);
    expect(find.text('Vergi dairesi zorunlu'), findsOneWidget);
    expect(find.text('Ticaret sicil numarası zorunlu'), findsOneWidget);
    final legal = tester.widget<TextField>(input('Şirket / ticari unvan *'));
    expect(legal.focusNode!.hasFocus, isTrue, reason: 'first invalid input is focused');

    await tester.enterText(input('Vergi numarası *'), '123456789012');
    await tester.enterText(input('MERSİS numarası *'), '01234567890123456789');
    await tester.pump();
    expect(text('Vergi numarası *'), '12345678901');
    expect(text('MERSİS numarası *'), '0123456789012345');
    await tester.enterText(input('Şirket / ticari unvan *'), 'Prime AVM A.Ş.');
    await tester.enterText(input('Vergi dairesi *'), 'İskenderun');
    await tester.enterText(input('Ticaret sicil numarası *'), '12345');
    await tester.enterText(input('KEP adresi'), '');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Devam Et'));
    await tester.pump();
    expect(find.text('AVM Bilgileri'), findsOneWidget);
    expect(find.text('✓'), findsOneWidget, reason: 'İşletme step is complete');
  });

  test('account errors stay on step 1 and drafts never store a password', () {
    expect(MallApplicationValidation.stepForError('Yetkili görevi zorunlu'), 0);
    expect(MallApplicationValidation.stepForError('Vergi numarası zorunlu'), 1);
    expect(
      MallApplicationValidation.stepForError('Kat sayısı 1 ile 40 arasında olmalı'),
      2,
    );
    final row = const MallApplicationDraft(
      mallName: 'Prime',
      city: 'Hatay',
      district: 'İskenderun',
      addressText: 'Sahil',
      authorizedPersonName: 'Ayşe Yılmaz',
      authorizedPersonTitle: 'Müdür',
    ).toContentRow('user');
    expect(row.containsKey('password'), isFalse);
    expect(
      MallDocumentSlot.storagePathAllowed(
        userId: 'user-1',
        applicationId: 'app-1',
        path: 'user-1/mall-applications/app-1/authority_1_yetki.pdf',
      ),
      isTrue,
    );
    expect(
      MallDocumentSlot.storagePathAllowed(
        userId: 'user-1',
        applicationId: 'app-1',
        path: 'user-1/mall-applications/app-1/authority/yetki.pdf',
      ),
      isFalse,
    );
    expect(
      MallDocumentSlot.kindOf('user-1/mall-applications/app-1/gazette_1_sicil.pdf'),
      'gazette',
    );
    expect(row.containsKey('şifre'), isFalse);
  });
}

MallApplication _sample(MallApplicationStatus status, String id) {
  return MallApplication(
    id: id,
    applicantUserId: 'user',
    mallName: 'Prime',
    city: 'Hatay',
    district: 'İskenderun',
    addressText: 'Sahil',
    latitude: 36,
    longitude: 36,
    authorizedPersonName: 'Ayşe',
    authorizedPersonTitle: 'Müdür',
    documentPaths: const [],
    status: status,
  );
}
