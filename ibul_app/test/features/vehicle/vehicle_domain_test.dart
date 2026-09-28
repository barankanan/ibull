import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/vehicle/domain/vehicle_availability.dart';
import 'package:ibul_app/features/vehicle/domain/vehicle_cancellation_policy.dart';
import 'package:ibul_app/features/vehicle/domain/vehicle_category.dart';
import 'package:ibul_app/features/vehicle/domain/vehicle_delivery_fee.dart';
import 'package:ibul_app/features/vehicle/domain/vehicle_delivery_geocode.dart';
import 'package:ibul_app/features/vehicle/domain/vehicle_pricing.dart';
import 'package:ibul_app/features/vehicle/domain/vehicle_rental_validation.dart';
import 'package:ibul_app/features/vehicle/domain/vehicle_state_machine.dart';
import 'package:ibul_app/features/vehicle/models/vehicle_enums.dart';
import 'package:ibul_app/features/vehicle/models/vehicle_listing.dart';
import 'package:ibul_app/features/vehicle/widgets/vehicle_card.dart';

void main() {
  group('VehicleRentalPricing', () {
    test('same calendar day counts as 1', () {
      final pickup = DateTime(2026, 9, 2, 10);
      final ret = DateTime(2026, 9, 2, 18);
      expect(
        VehicleRentalPricing.rentalDays(pickupAt: pickup, returnAt: ret),
        1,
      );
    });

    test('multi-day span uses calendar days', () {
      expect(
        VehicleRentalPricing.rentalDays(
          pickupAt: DateTime(2026, 9, 2, 10),
          returnAt: DateTime(2026, 9, 5, 9),
        ),
        3,
      );
    });

    test('duration bounds are enforced', () {
      expect(
        () => VehicleRentalPricing.assertDurationAllowed(
          days: 2,
          minDays: 3,
          maxDays: 10,
        ),
        throwsStateError,
      );
      expect(
        VehicleRentalPricing.assertDurationAllowed(
          days: 3,
          minDays: 1,
          maxDays: 10,
        ),
        3,
      );
    });

    test('15 Sep to 17 Sep is 2 days; min 3 requires 18 Sep', () {
      final pickup = DateTime(2026, 9, 15, 10);
      expect(
        VehicleRentalPricing.rentalDays(
          pickupAt: pickup,
          returnAt: DateTime(2026, 9, 17, 10),
        ),
        2,
      );
      expect(
        VehicleRentalPricing.rentalDays(
          pickupAt: pickup,
          returnAt: DateTime(2026, 9, 18, 10),
        ),
        3,
      );
      expect(
        VehicleRentalPricing.earliestReturnAt(pickup, 3),
        DateTime(2026, 9, 18, 10),
      );
      final message = VehicleRentalPricing.durationMessage(
        days: 2,
        minDays: 3,
        maxDays: 30,
        pickupAt: pickup,
      );
      expect(message, contains('minimum 3 gün'));
      expect(message, contains('18 Eylül'));
    });

    test('weekly band can beat daily', () {
      final daily = VehicleRentalPricing.rentalSubtotal(
        days: 7,
        dailyPrice: 1000,
      );
      final weekly = VehicleRentalPricing.rentalSubtotal(
        days: 7,
        dailyPrice: 1000,
        weeklyPrice: 5000,
      );
      expect(daily, 7000);
      expect(weekly, 5000);
    });

    test('checkout total sums rental + delivery + deposit', () {
      expect(
        VehicleRentalPricing.checkoutTotal(
          rentalSubtotal: 1000,
          deliveryFee: 200,
          deposit: 300,
        ),
        1500,
      );
    });
  });

  group('VehicleDeliveryFeeCalculator', () {
    const zones = [
      VehicleDeliveryZoneQuote(label: '0-10', minKm: 0, maxKm: 10, fee: 200),
      VehicleDeliveryZoneQuote(label: '10-25', minKm: 10, maxKm: 25, fee: 350),
      VehicleDeliveryZoneQuote(label: '25-50', minKm: 25, maxKm: 50, fee: 600),
      VehicleDeliveryZoneQuote(
        label: 'Havalimanı',
        minKm: 0,
        maxKm: 0,
        fee: 500,
        isAirport: true,
      ),
    ];

    test('picks matching km band', () {
      expect(
        VehicleDeliveryFeeCalculator.quote(zones: zones, distanceKm: 8),
        200,
      );
      expect(
        VehicleDeliveryFeeCalculator.quote(zones: zones, distanceKm: 18),
        350,
      );
    });

    test('airport uses airport zone', () {
      expect(
        VehicleDeliveryFeeCalculator.quote(
          zones: zones,
          distanceKm: 40,
          airport: true,
        ),
        500,
      );
    });

    test('out of zone throws', () {
      expect(
        () => VehicleDeliveryFeeCalculator.quote(zones: zones, distanceKm: 80),
        throwsStateError,
      );
      expect(
        VehicleDeliveryFeeCalculator.tryQuote(zones: zones, distanceKm: 80),
        isNull,
      );
    });

    test('haversine is symmetric and positive', () {
      final km = VehicleDeliveryFeeCalculator.haversineKm(
        fromLat: 41.0082,
        fromLng: 28.9784,
        toLat: 40.9827,
        toLng: 29.0684,
      );
      expect(km, greaterThan(5));
      expect(km, lessThan(20));
    });
  });

  group('VehicleAvailability', () {
    test('rejects overlapping windows', () {
      final busy = [
        VehicleBusyInterval(
          start: DateTime(2026, 9, 2, 10),
          end: DateTime(2026, 9, 5, 10),
        ),
      ];
      expect(
        VehicleAvailability.isFree(
          pickupAt: DateTime(2026, 9, 4),
          returnAt: DateTime(2026, 9, 6),
          busy: busy,
        ),
        isFalse,
      );
      expect(
        VehicleAvailability.isFree(
          pickupAt: DateTime(2026, 9, 5, 10),
          returnAt: DateTime(2026, 9, 8),
          busy: busy,
        ),
        isTrue,
      );
      expect(
        VehicleBusyInterval.kindOnDay(DateTime(2026, 10, 22), const []),
        isNull,
      );
    });
  });

  test('only confirmed inventory statuses block the calendar', () {
    expect(VehicleReservationStatus.pendingDocs.blocksCalendar, isFalse);
    expect(VehicleReservationStatus.pendingSellerReview.blocksCalendar, isFalse);
    expect(VehicleReservationStatus.pendingPayment.blocksCalendar, isFalse);
    expect(VehicleReservationStatus.rejected.blocksCalendar, isFalse);
    expect(VehicleReservationStatus.cancelled.blocksCalendar, isFalse);
    expect(VehicleReservationStatus.reserved.blocksCalendar, isTrue);
    expect(VehicleReservationStatus.confirmed.blocksCalendar, isTrue);
    expect(VehicleReservationStatus.activeRental.blocksCalendar, isTrue);
    expect(VehicleReservationStatus.returnPending.blocksCalendar, isTrue);
    expect(VehicleReservationStatus.completed.blocksCalendar, isFalse);
  });

  group('VehicleStateMachine', () {
    test('allows reserved → rented and blocks sold → active', () {
      expect(
        VehicleStateMachine.canTransitionListing(
          VehicleListingStatus.reserved,
          VehicleListingStatus.rented,
        ),
        isTrue,
      );
      expect(
        VehicleStateMachine.canTransitionListing(
          VehicleListingStatus.sold,
          VehicleListingStatus.active,
        ),
        isFalse,
      );
    });

    test('handover is reserved → active_rental only', () {
      expect(
        VehicleStateMachine.canTransitionReservation(
          VehicleReservationStatus.reserved,
          VehicleReservationStatus.activeRental,
        ),
        isTrue,
      );
      expect(
        VehicleStateMachine.canTransitionReservation(
          VehicleReservationStatus.pendingPayment,
          VehicleReservationStatus.activeRental,
        ),
        isFalse,
      );
      expect(
        VehicleStateMachine.canTransitionReservation(
          VehicleReservationStatus.pendingDocs,
          VehicleReservationStatus.pendingSellerReview,
        ),
        isTrue,
      );
      expect(
        VehicleStateMachine.canTransitionReservation(
          VehicleReservationStatus.pendingSellerReview,
          VehicleReservationStatus.rejected,
        ),
        isTrue,
      );
    });
  });

  test('isLivePublished is the public visibility rule', () {
    const specs = VehicleSpecs(brand: 'Toyota', model: 'Corolla', year: 2021);
    final live = VehicleListing(
      id: 'v1',
      sellerId: 's1',
      listingType: VehicleListingType.sale,
      status: VehicleListingStatus.active,
      specs: specs,
    );
    expect(live.isLivePublished, isTrue);
    expect(
      live.copyWith(status: VehicleListingStatus.pendingReview).isLivePublished,
      isFalse,
    );
    expect(
      live.copyWith(status: VehicleListingStatus.draft).isLivePublished,
      isFalse,
    );
    final rejected = VehicleListing(
      id: 'v2',
      sellerId: 's1',
      listingType: VehicleListingType.sale,
      status: VehicleListingStatus.draft,
      specs: specs,
      extras: const {
        'moderation': {'status': 'rejected', 'reason': 'Eksik fotoğraf'},
      },
    );
    expect(rejected.isRejected, isTrue);
    expect(rejected.isLivePublished, isFalse);
  });

  group('vehicle category', () {
    test('Galerici is a gallery, Otomotiv parts shop is not', () {
      expect(isSellerVehicleGalleryCategory('Galerici'), isTrue);
      expect(isSellerVehicleGalleryCategory('Oto Galeri'), isTrue);
      expect(isSellerVehicleGalleryCategory('Otomotiv & Motosiklet'), isFalse);
      expect(isVehicleHubShortcutTitle('Araç'), isTrue);
    });
  });

  test(
    'gallery summary uses canonical is_verified without brand-badge column',
    () {
      final summary = VehicleGallerySummary.fromMap({
        'seller_id': 's1',
        'business_name': 'Test Galeri',
        'is_verified': true,
      });
      expect(summary.verified, isTrue);
      expect(summary.name, 'Test Galeri');
    },
  );

  testWidgets('VehicleCard shows title', (tester) async {
    final listing = VehicleListing(
      id: 'v1',
      sellerId: 's1',
      listingType: VehicleListingType.sale,
      status: VehicleListingStatus.active,
      specs: const VehicleSpecs(
        brand: 'Toyota',
        model: 'Corolla',
        year: 2021,
        mileageKm: 86500,
      ),
      salePrice: 1180000,
      city: 'İstanbul',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: VehicleCard(listing: listing)),
      ),
    );
    expect(find.textContaining('Toyota'), findsOneWidget);
    expect(find.textContaining('2021'), findsOneWidget);
  });

  testWidgets('verified chip distinguishes dealer vs document', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: VehicleVerifiedChip(verified: true)),
      ),
    );
    expect(find.text('Doğrulanmış'), findsOneWidget);
  });

  group('VehicleCancellationPolicy', () {
    const policy = VehicleCancellationPolicy();
    final start = DateTime(2026, 9, 14, 12);

    test('seller cancel is always full refund', () {
      expect(
        policy.refundPercent(
          startAt: start,
          now: start.add(const Duration(hours: 1)),
          sellerCaused: true,
        ),
        100,
      );
    });

    test('customer cancel uses hour bands', () {
      expect(
        policy.refundPercent(
          startAt: start,
          now: start.subtract(const Duration(hours: 30)),
          sellerCaused: false,
        ),
        100,
      );
      expect(
        policy.refundPercent(
          startAt: start,
          now: start.subtract(const Duration(hours: 18)),
          sellerCaused: false,
        ),
        50,
      );
      expect(
        policy.refundPercent(
          startAt: start,
          now: start.subtract(const Duration(hours: 2)),
          sellerCaused: false,
        ),
        0,
      );
    });
  });

  group('VehicleRentalValidation', () {
    const settings = VehicleRentalSettings(
      dailyPrice: 1166,
      minDays: 3,
      maxDays: 30,
      minDriverAge: 23,
      minLicenseYears: 2,
    );

    test('blocks 15-17 Oct before continue', () {
      final message = VehicleRentalValidation.dates(
        pickupAt: DateTime(2026, 10, 15, 10),
        returnAt: DateTime(2026, 10, 17, 10),
        settings: settings,
        busy: const [],
      );
      expect(message, contains('minimum 3 gün'));
      expect(message, contains('18 Ekim'));
    });

    test('allows 15-18 Oct', () {
      expect(
        VehicleRentalValidation.dates(
          pickupAt: DateTime(2026, 10, 15, 10),
          returnAt: DateTime(2026, 10, 18, 10),
          settings: settings,
          busy: const [],
        ),
        isNull,
      );
    });

    test('home delivery requires customer coordinates not store fallback', () {
      expect(
        VehicleRentalValidation.pickup(
          mode: VehicleDeliveryMode.homeDelivery,
          address: 'Hatay / Arsuz / Gökmeydan',
          settings: settings.copyWith(homeDelivery: true),
          zonesConfigured: true,
        ),
        contains('Teslim konumunu haritada seçin'),
      );
      expect(
        VehicleRentalValidation.pickup(
          mode: VehicleDeliveryMode.homeDelivery,
          address: 'Hatay / Arsuz / Gökmeydan',
          settings: settings.copyWith(homeDelivery: true),
          lat: 36.41,
          lng: 35.89,
          zonesConfigured: true,
          quoteError: 'out_of_zone',
        ),
        contains('teslimat bölgemizin dışında'),
      );
      expect(
        VehicleRentalValidation.pickup(
          mode: VehicleDeliveryMode.galleryPickup,
          address: '',
          settings: settings,
        ),
        isNull,
      );
    });

    test('raw delivery codes are never shown', () {
      expect(
        VehicleDeliveryQuoteError.message('out_of_zone'),
        isNot(contains('out_of_zone')),
      );
      expect(
        VehicleDeliveryQuoteError.sanitizeForUi('out_of_zone'),
        'Bu adres teslimat bölgemizin dışında.',
      );
      expect(
        VehicleDeliveryQuoteError.sanitizeForUi(
          "VehicleRepositoryException: out_of_zone",
        ),
        isNot(contains('out_of_zone')),
      );
      expect(
        VehicleRentalValidation.friendlyError('out_of_zone'),
        isNot(contains('out_of_zone')),
      );
      expect(
        VehicleDeliveryQuoteError.message('missing_coordinates'),
        contains('Haritadan konum seçin'),
      );
    });

    test('saved address keeps coordinates when present', () {
      final resolved = VehicleResolvedDelivery.fromSaved({
        'city': 'Hatay',
        'district': 'Arsuz',
        'detail': 'Gökmeydan',
        'lat': '36.3331',
        'lng': '35.8902',
      });
      expect(resolved?.city, 'Hatay');
      expect(resolved?.point?.latitude, closeTo(36.3331, 0.0001));
      expect(
        VehicleResolvedDelivery.fromSaved({'city': 'Hatay'})?.point,
        isNull,
      );
    });

    test('age and license rules', () {
      expect(
        VehicleRentalValidation.customer(
          firstName: 'Baran',
          lastName: 'Test',
          phone: '5551112233',
          email: 'a@b.com',
          nationalId: '12345678950',
          birthDate: DateTime(2005, 1, 1),
          licenseIssued: DateTime(2020, 1, 1),
          settings: settings,
        ),
        contains('minimum yaş 23'),
      );
      expect(
        VehicleRentalValidation.friendlyError(
          StateError('Rental duration 2 is outside [3, 30]'),
        ),
        isNot(contains('Bad state')),
      );
    });
  });
}
