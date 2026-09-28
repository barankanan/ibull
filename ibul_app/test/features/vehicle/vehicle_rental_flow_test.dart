import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/vehicle/domain/vehicle_pricing.dart';
import 'package:ibul_app/features/vehicle/models/vehicle_enums.dart';
import 'package:ibul_app/features/vehicle/models/vehicle_listing.dart';
import 'package:ibul_app/features/vehicle/screens/vehicle_rental_flow_steps.dart';

VehicleListing _listing() {
  return VehicleListing(
    id: 'listing-1',
    sellerId: 'seller-1',
    listingType: VehicleListingType.rental,
    status: VehicleListingStatus.active,
    specs: const VehicleSpecs(brand: 'Renault', model: 'Clio', year: 2021),
    extras: const {'title': 'Renault Clio'},
    gallery: const VehicleGallerySummary(
      sellerId: 'seller-1',
      name: 'seco',
      city: 'Hatay',
      district: 'Arsuz',
      lat: 36.41,
      lng: 35.89,
    ),
    rental: const VehicleRentalSettings(
      dailyPrice: 1166,
      minDays: 3,
      maxDays: 30,
      homeDelivery: true,
      mapPointDelivery: true,
    ),
  );
}

void main() {
  testWidgets('date step shows min duration copy instead of exception', (
    tester,
  ) async {
    final pickup = DateTime(2026, 9, 15, 10);
    final ret = DateTime(2026, 9, 17, 10);
    final days = VehicleRentalPricing.rentalDays(pickupAt: pickup, returnAt: ret);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: VehicleRentalDatesStep(
              pickup: pickup,
              returnAt: ret,
              days: days,
              datesFree: true,
              minDays: 3,
              maxDays: 30,
              busy: const [],
              month: pickup,
              selectingPickup: false,
              durationError: VehicleRentalPricing.durationMessage(
                days: days,
                minDays: 3,
                maxDays: 30,
                pickupAt: pickup,
              ),
              onSelectPickup: (_) {},
              onSelectReturn: (_) {},
              onToggleTarget: () {},
              onMonth: (_) {},
              onPickPickupTime: () {},
              onPickReturnTime: () {},
            ),
          ),
        ),
      ),
    );
    expect(find.textContaining('minimum 3 gün'), findsWidgets);
    expect(find.textContaining('Bad state'), findsNothing);
    expect(find.textContaining('outside'), findsNothing);
  });

  testWidgets('home delivery without pin asks for map location', (tester) async {
    final city = TextEditingController(text: 'Hatay');
    final district = TextEditingController(text: 'Arsuz');
    final neighborhood = TextEditingController(text: 'Gökmeydan');
    final street = TextEditingController();
    final building = TextEditingController();
    final note = TextEditingController();
    final receiverName = TextEditingController();
    final receiverPhone = TextEditingController();
    addTearDown(() {
      city.dispose();
      district.dispose();
      neighborhood.dispose();
      street.dispose();
      building.dispose();
      note.dispose();
      receiverName.dispose();
      receiverPhone.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: VehicleRentalDeliveryStep(
              listing: _listing(),
              pickupMode: VehicleDeliveryMode.homeDelivery,
              dropoffMode: VehicleDeliveryMode.galleryPickup,
              city: city,
              district: district,
              neighborhood: neighborhood,
              street: street,
              building: building,
              note: note,
              receiverSelf: true,
              receiverName: receiverName,
              receiverPhone: receiverPhone,
              airport: false,
              pin: null,
              homeEnabled: true,
              mapEnabled: true,
              airportEnabled: false,
              zoneOk: null,
              zoneMessage: 'Teslim konumunu haritada seçin.',
              onPickupMode: (_) {},
              onDropoffMode: (_) {},
              onReceiverSelf: (_) {},
              onAirport: (_) {},
              onPin: (_) {},
              onLocate: () {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('Adresime getir'), findsOneWidget);
    expect(find.text('Teslim konumunu haritada seçin.'), findsOneWidget);
    expect(find.text('out_of_zone'), findsNothing);
    expect(find.textContaining('Haritada konum seç'), findsOneWidget);
  });

  testWidgets('out of zone shows Turkish warning and alternatives', (
    tester,
  ) async {
    final city = TextEditingController(text: 'Hatay');
    final district = TextEditingController(text: 'Arsuz');
    final neighborhood = TextEditingController(text: 'Gökmeydan');
    final street = TextEditingController();
    final building = TextEditingController();
    final note = TextEditingController();
    final receiverName = TextEditingController();
    final receiverPhone = TextEditingController();
    addTearDown(() {
      city.dispose();
      district.dispose();
      neighborhood.dispose();
      street.dispose();
      building.dispose();
      note.dispose();
      receiverName.dispose();
      receiverPhone.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: VehicleRentalDeliveryStep(
              listing: _listing(),
              pickupMode: VehicleDeliveryMode.homeDelivery,
              dropoffMode: VehicleDeliveryMode.galleryPickup,
              city: city,
              district: district,
              neighborhood: neighborhood,
              street: street,
              building: building,
              note: note,
              receiverSelf: true,
              receiverName: receiverName,
              receiverPhone: receiverPhone,
              airport: false,
              pin: null,
              homeEnabled: true,
              mapEnabled: true,
              airportEnabled: false,
              zoneOk: false,
              zoneMessage: 'Bu adres teslimat bölgemizin dışında.',
              onPickupMode: (_) {},
              onDropoffMode: (_) {},
              onReceiverSelf: (_) {},
              onAirport: (_) {},
              onPin: (_) {},
              onLocate: () {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('Bu adres teslimat bölgemizin dışında.'), findsOneWidget);
    expect(find.text('Galeriden teslim al'), findsWidgets);
    expect(find.text('Farklı konum seç'), findsOneWidget);
    expect(find.text('out_of_zone'), findsNothing);
  });
}

