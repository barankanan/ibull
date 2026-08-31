import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/panel/cargo/seller_cargo_saved_addresses_section.dart';
import 'package:ibul_app/models/seller_saved_address.dart';

void main() {
  SellerSavedAddress address({
    required String id,
    required String name,
    String phone = '05551234567',
    String city = 'İstanbul',
    String district = 'Kadıköy',
    String detail = 'Moda Cad. No 12',
  }) {
    return SellerSavedAddress(
      id: id,
      sellerId: 'seller-1',
      customerName: name,
      customerPhone: phone,
      city: city,
      district: district,
      address: detail,
    );
  }

  testWidgets('search field and list select fill callback', (tester) async {
    SellerSavedAddress? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SellerCargoSavedAddressesSection(
            addresses: [
              address(id: 'a1', name: 'Ayşe Yılmaz'),
              address(
                id: 'a2',
                name: 'Can Kaya',
                phone: '05441112233',
                city: 'İzmir',
                district: 'Bornova',
                detail: 'Kazım Dirik Mah.',
              ),
            ],
            selectedId: null,
            isLoading: false,
            onSelected: (value) => selected = value,
          ),
        ),
      ),
    );

    expect(find.text('Kayıtlı Adresler'), findsOneWidget);
    expect(find.text('Adres, isim veya telefon ara...'), findsOneWidget);
    expect(find.text('Ayşe Yılmaz'), findsOneWidget);
    expect(find.text('Can Kaya'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('seller_cargo_saved_address_search')),
      'bornova',
    );
    await tester.pump();

    expect(find.text('Can Kaya'), findsOneWidget);
    expect(find.text('Ayşe Yılmaz'), findsNothing);

    await tester.tap(find.byKey(const Key('seller_cargo_saved_address_a2')));
    await tester.pump();
    expect(selected?.id, 'a2');
    expect(selected?.customerName, 'Can Kaya');
  });

  testWidgets('empty book shows save hint without crashing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SellerCargoSavedAddressesSection(
            addresses: [],
            selectedId: null,
            isLoading: false,
            onSelected: _noop,
          ),
        ),
      ),
    );

    expect(find.textContaining('Henüz kayıtlı adres yok'), findsOneWidget);
    expect(find.textContaining('Adresi Kaydet'), findsOneWidget);
  });
}

void _noop(SellerSavedAddress _) {}
