import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/panel/helpers/seller_panel_module_helpers.dart';
import 'package:ibul_app/features/seller/panel/models/seller_panel_types.dart';
import 'package:ibul_app/features/vehicle/domain/turkish_national_id.dart';
import 'package:ibul_app/features/vehicle/domain/vehicle_rental_account.dart';
import 'package:ibul_app/features/vehicle/domain/vehicle_rental_validation.dart';
import 'package:ibul_app/features/vehicle/models/vehicle_commerce.dart';
import 'package:ibul_app/features/vehicle/models/vehicle_enums.dart';
import 'package:ibul_app/features/vehicle/models/vehicle_listing.dart';
import 'package:ibul_app/features/vehicle/screens/vehicle_rental_flow_checkout.dart';
import 'package:ibul_app/features/vehicle/widgets/vehicle_rental_calendar.dart';
import 'package:ibul_app/features/vehicle/widgets/vehicle_rental_chrome.dart';
import 'package:ibul_app/features/vehicle/widgets/vehicle_rental_payment_bar.dart';

void main() {
  const settings = VehicleRentalSettings(dailyPrice: 1000, minDays: 1);

  test('valid and invalid TC checksum', () {
    expect(TurkishNationalId.isValid('12345678950'), isTrue);
    expect(TurkishNationalId.isValid('12345678900'), isFalse);
    expect(TurkishNationalId.validate('123'), contains('11 haneli'));
    expect(TurkishNationalId.validate(''), contains('zorunludur'));
    expect(TurkishNationalId.mask('12345678950'), '*******8950');
    expect(VehicleReservationStatus.pendingDocs.isAccountVisible, isFalse);
    expect(VehicleReservationStatus.pendingSellerReview.isAccountVisible, isTrue);
    expect(VehicleReservationStatus.pendingDocs.blocksInventory, isFalse);
    expect(VehicleReservationStatus.reserved.blocksInventory, isTrue);
  });

  test('rental customer info requires name phone email and TC', () {
    expect(
      VehicleRentalValidation.customer(
        firstName: '',
        lastName: 'Kanan',
        phone: '5551112233',
        email: 'a@b.com',
        nationalId: '12345678950',
        birthDate: DateTime(1990, 1, 1),
        licenseIssued: DateTime(2010, 1, 1),
        settings: settings,
      ),
      contains('Ad ve soyad'),
    );
    expect(
      VehicleRentalValidation.customer(
        firstName: 'Baran',
        lastName: 'Kanan',
        phone: '5551112233',
        email: 'a@b.com',
        nationalId: '11111111111',
        birthDate: DateTime(1990, 1, 1),
        licenseIssued: DateTime(2010, 1, 1),
        settings: settings,
      ),
      contains('checksum'),
    );
  });

  test('documents require all four faces', () {
    expect(
      VehicleRentalValidation.documents({
        VehicleDocumentType.identityFront,
        VehicleDocumentType.driverLicenseFront,
      }),
      isNotNull,
    );
    expect(
      VehicleRentalValidation.documents({
        VehicleDocumentType.identityFront,
        VehicleDocumentType.identityBack,
        VehicleDocumentType.driverLicenseFront,
        VehicleDocumentType.driverLicenseBack,
      }),
      isNull,
    );
  });

  test('friendly error hides PostgrestException and gen_random_bytes', () {
    expect(
      VehicleRentalValidation.friendlyError(
        'PostgrestException(message: function gen_random_bytes(integer) does not exist, code: 42883)',
      ),
      'Kiralama talebi oluşturulamadı. Lütfen tekrar deneyin.',
    );
    expect(
      VehicleRentalValidation.friendlyError(
        'x',
        code: 'document_upload_failed',
      ),
      contains('Belge yüklenemedi'),
    );
  });

  testWidgets('payment step has no raw card inputs', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: VehicleRentalPaymentStep(total: 8498),
          ),
        ),
      ),
    );
    expect(find.textContaining('kartınızdan ücret çekilmeyecek'), findsOneWidget);
    expect(find.text('Kart numarası'), findsNothing);
    expect(find.text('CVV'), findsNothing);
    expect(find.textContaining('8.498'), findsOneWidget);
  });

  testWidgets('selected range is not painted as reserved', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VehicleRentalCalendar(
            month: DateTime(2026, 10, 1),
            firstDate: DateTime(2026, 10, 1),
            lastDate: DateTime(2026, 10, 31),
            busy: const [],
            selected: DateTime(2026, 10, 22),
            rangeStart: DateTime(2026, 10, 22),
            rangeEnd: DateTime(2026, 10, 25),
            onSelect: (_) {},
            onMonth: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('Müsait'), findsOneWidget);
    expect(find.text('Rezerve'), findsOneWidget);
    expect(find.text('22'), findsWidgets);
  });

  testWidgets('summary uses contract checkbox copy', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: VehicleRentalSummaryStep(
            listing: VehicleListing(
              id: '1',
              sellerId: 's',
              listingType: VehicleListingType.rental,
              status: VehicleListingStatus.active,
              specs: const VehicleSpecs(brand: 'Renault', model: 'Clio', year: 2021),
            ),
            days: 3,
            pickup: DateTime(2026, 9, 24),
            returnAt: DateTime(2026, 9, 27),
            pickupLabel: 'Galeriden teslim',
            dropoffLabel: 'Galeride',
            customerName: 'Baran Kanan',
            customerPhone: '05xx',
            customerEmail: 'ba***@x.com',
            nationalIdMasked: '*******1234',
            address: 'Arsuz',
            rental: 3498,
            delivery: 0,
            deposit: 5000,
            total: 8498,
            terms: false,
            onTerms: (_) {},
            onViewContract: () {},
          ),
          ),
        ),
      ),
    );
    expect(find.textContaining('Araç Kiralama Sözleşmesini'), findsOneWidget);
    expect(find.text('Sözleşmeyi Görüntüle'), findsOneWidget);
    expect(find.textContaining('*******1234'), findsOneWidget);
  });

  test('pgcrypto search_path is set on rental code generator', () {
    final sql = File(
      'supabase/migrations/20260921_vehicle_rental_complete.sql',
    ).readAsStringSync();
    expect(sql, contains('create extension if not exists pgcrypto'));
    expect(sql, contains('set search_path = public, extensions, pg_catalog'));
    expect(sql, contains('gen_random_bytes(4)'));
    expect(sql, contains('accept_vehicle_rental_terms'));
    expect(sql, isNot(contains("pending_docs' then 'pending_payment")));
    expect(sql, contains('store_contracts'));
    expect(sql, contains('store_contract_acceptances'));
    expect(sql, contains("'store-contracts'"));
    final submit = File(
      'supabase/migrations/20260921_vehicle_rental_submit.sql',
    ).readAsStringSync();
    expect(submit, contains('idempotent'));
    expect(submit, contains('contract_required'));
    expect(submit, contains('invalid_national_id'));
    expect(submit, contains('pending_seller_review'));
  });

  test('seller panel exposes contracts module', () {
    expect(visibleSellerModules('Galerici'), contains(SellerModule.contracts));
    expect(sellerModuleLabel(SellerModule.contracts), 'Sözleşmeler');
  });

  test('availability RPC ignores draft and pending statuses', () {
    final sql = File(
      'supabase/migrations/20260921_vehicle_rental_availability.sql',
    ).readAsStringSync();
    expect(sql, contains('get_vehicle_unavailable_ranges'));
    expect(
      sql,
      contains("'confirmed', 'reserved', 'active_rental', 'return_pending'"),
    );
    expect(
      sql,
      isNot(
        contains(
          "'pending_payment', 'pending_docs', 'pending_seller_review'",
        ),
      ),
    );
    expect(sql, contains('for update'));
    expect(sql, contains('payment_provider_required'));
    expect(sql, contains('rental_accepted_contract'));
  });

  test('payment window SQL is server-side and does not fake paid', () {
    final sql = File(
      'supabase/migrations/20260922_vehicle_rental_payment_window.sql',
    ).readAsStringSync();
    expect(sql, contains('payment_due_at'));
    expect(sql, contains("interval '3 hours'"));
    expect(sql, contains('expire_unpaid_vehicle_rentals'));
    expect(sql, contains('payment_window_expired'));
    expect(sql, contains('vehicle_kyc_one_doc_per_type_uidx'));
    expect(sql, contains('skip locked'));
    expect(sql, contains("'vehicle_rental_seller_approved'"));
    expect(sql, contains('vehicle_specs'));
    expect(sql, isNot(contains('l.specs->>')));
    expect(sql, isNot(contains('fake_paid')));
  });

  test('in-app notifications keep vehicle rental types visible', () {
    final page = File('lib/screens/notifications_page.dart').readAsStringSync();
    expect(page, contains("type.startsWith('vehicle_rental')"));
    expect(page, contains('_openVehicleRentalFromNotification'));
  });

  test('pay CTA only while pending payment and before deadline', () {
    final due = DateTime.utc(2026, 9, 21, 20, 30);
    final item = VehicleReservation(
      id: 'r1',
      listingId: 'l1',
      customerId: 'c1',
      sellerId: 's1',
      status: VehicleReservationStatus.pendingPayment,
      pickupAt: DateTime.utc(2026, 9, 22),
      returnAt: DateTime.utc(2026, 9, 25),
      deliveryMode: VehicleDeliveryMode.galleryPickup,
      rentalSubtotal: 3498,
      deliveryFee: 0,
      deposit: 5000,
      total: 8498,
      paymentStatus: 'unpaid',
      paymentDueAt: due,
    );
    expect(
      VehicleRentalPaymentCopy.canPay(
        item,
        now: DateTime.utc(2026, 9, 21, 18, 0),
      ),
      isTrue,
    );
    expect(
      VehicleRentalPaymentCopy.canPay(
        item,
        now: DateTime.utc(2026, 9, 21, 21, 0),
      ),
      isFalse,
    );
    expect(
      VehicleRentalPaymentCopy.canPay(
        item.copyWith(paymentStatus: 'paid'),
        now: DateTime.utc(2026, 9, 21, 18, 0),
      ),
      isFalse,
    );
    expect(
      VehicleRentalPaymentCopy.canPay(
        item.copyWith(status: VehicleReservationStatus.rejected),
        now: DateTime.utc(2026, 9, 21, 18, 0),
      ),
      isFalse,
    );
    expect(
      VehicleDocumentTypeX.labelOf('driver_license_back'),
      'Ehliyet arka yüz',
    );
    expect(VehicleRentalPaymentCopy.statusLabel('unpaid'), 'Ödeme bekleniyor');
  });

  testWidgets('document cards wrap titles at 320 without overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: VehicleRentalDocsStep(
              uploaded: {
                VehicleDocumentType.driverLicenseFront,
                VehicleDocumentType.driverLicenseBack,
                VehicleDocumentType.identityFront,
                VehicleDocumentType.identityBack,
              },
              busyType: null,
              onUpload: _noopDoc,
              onReplace: _noopDoc,
              onDelete: _noopDoc,
              onView: _noopDoc,
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Ehliyet ön yüz'), findsOneWidget);
    expect(find.text('Ehliyet arka yüz'), findsOneWidget);
    expect(find.text('Kimlik ön yüz'), findsOneWidget);
    expect(find.text('Görüntüle'), findsWidgets);
    expect(find.text('Değiştir'), findsWidgets);
    expect(find.text('Sil'), findsWidgets);
  });

  testWidgets('pay bar shows pay and cancel for awaiting payment', (tester) async {
    final item = VehicleReservation(
      id: 'r1',
      listingId: 'l1',
      customerId: 'c1',
      sellerId: 's1',
      status: VehicleReservationStatus.pendingPayment,
      pickupAt: DateTime.utc(2026, 9, 22),
      returnAt: DateTime.utc(2026, 9, 25),
      deliveryMode: VehicleDeliveryMode.galleryPickup,
      rentalSubtotal: 3498,
      deliveryFee: 0,
      deposit: 5000,
      total: 8498,
      paymentStatus: 'unpaid',
      paymentDueAt: DateTime.now().toUtc().add(const Duration(hours: 2)),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VehicleRentalPaymentActionBar(
            item: item,
            now: DateTime.now(),
            busy: false,
            onPay: () {},
            onCancel: () {},
          ),
        ),
      ),
    );
    expect(find.text('ÖDEME YAP'), findsOneWidget);
    expect(find.text('KİRALAMAYI İPTAL ET'), findsOneWidget);
  });

  testWidgets('mobile stepper keeps current label without overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VehicleRentalStepper(
            labels: ['Tarih', 'Teslim', 'Bilgiler', 'Belgeler', 'Özet', 'Ödeme'],
            index: 3,
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Belgeler'), findsOneWidget);
    expect(find.text('Tarih'), findsNothing);
  });
}

Future<void> _noopDoc(VehicleDocumentType type) async {}
