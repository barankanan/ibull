import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants.dart';
import '../domain/vehicle_availability.dart';
import '../domain/vehicle_catalog.dart';
import '../models/vehicle_enums.dart';
import '../models/vehicle_listing.dart';
import '../widgets/vehicle_rental_calendar.dart';
import '../widgets/vehicle_rental_chrome.dart';

class VehicleRentalDatesStep extends StatelessWidget {
  const VehicleRentalDatesStep({
    super.key,
    required this.pickup,
    required this.returnAt,
    required this.days,
    required this.datesFree,
    required this.minDays,
    required this.maxDays,
    required this.busy,
    required this.month,
    required this.selectingPickup,
    required this.durationError,
    required this.onSelectPickup,
    required this.onSelectReturn,
    required this.onToggleTarget,
    required this.onMonth,
    required this.onPickPickupTime,
    required this.onPickReturnTime,
  });

  final DateTime pickup;
  final DateTime returnAt;
  final int days;
  final bool datesFree;
  final int minDays;
  final int maxDays;
  final List<VehicleBusyInterval> busy;
  final DateTime month;
  final bool selectingPickup;
  final String? durationError;
  final ValueChanged<DateTime> onSelectPickup;
  final ValueChanged<DateTime> onSelectReturn;
  final VoidCallback onToggleTarget;
  final ValueChanged<DateTime> onMonth;
  final VoidCallback onPickPickupTime;
  final VoidCallback onPickReturnTime;

  @override
  Widget build(BuildContext context) {
    return VehicleRentalSectionCard(
      title: 'Kiralama Tarihi',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _DateField(
                  label: 'Başlangıç',
                  date: pickup,
                  selected: selectingPickup,
                  onTap: selectingPickup ? null : onToggleTarget,
                  onTime: onPickPickupTime,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DateField(
                  label: 'Bitiş',
                  date: returnAt,
                  selected: !selectingPickup,
                  onTap: selectingPickup ? onToggleTarget : null,
                  onTime: onPickReturnTime,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('$days gün', style: const TextStyle(fontWeight: FontWeight.w800)),
          Text(
            'Minimum: $minDays gün   ·   Maksimum: $maxDays gün',
            style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
          ),
          const SizedBox(height: 10),
          if (durationError != null)
            VehicleRentalErrorBanner(message: durationError!)
          else if (datesFree)
            const Text(
              '✓ Tarihler uygun',
              style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w700),
            )
          else
            const Text(
              '⚠ Bu tarihlerde araç müsait değil',
              style: TextStyle(color: AppColors.orangeDark, fontWeight: FontWeight.w700),
            ),
          const SizedBox(height: 12),
          VehicleRentalCalendar(
            month: month,
            firstDate: selectingPickup
                ? DateTime.now()
                : DateTime(pickup.year, pickup.month, pickup.day).add(Duration(days: minDays)),
            lastDate: selectingPickup
                ? DateTime.now().add(const Duration(days: 180))
                : DateTime(pickup.year, pickup.month, pickup.day).add(Duration(days: maxDays)),
            busy: busy,
            selected: selectingPickup ? pickup : returnAt,
            rangeStart: pickup,
            rangeEnd: returnAt,
            onSelect: selectingPickup ? onSelectPickup : onSelectReturn,
            onMonth: onMonth,
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.date,
    required this.selected,
    required this.onTime,
    this.onTap,
  });

  final String label;
  final DateTime date;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback onTime;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
            const SizedBox(height: 4),
            Text(
              rentalDateLabel(date),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            TextButton(
              onPressed: onTime,
              child: Text(rentalTimeLabel(date)),
            ),
          ],
        ),
      ),
    );
  }
}

class VehicleRentalDeliveryStep extends StatelessWidget {
  const VehicleRentalDeliveryStep({
    super.key,
    required this.listing,
    required this.pickupMode,
    required this.dropoffMode,
    required this.city,
    required this.district,
    required this.neighborhood,
    required this.street,
    required this.building,
    required this.note,
    required this.receiverSelf,
    required this.receiverName,
    required this.receiverPhone,
    required this.airport,
    required this.pin,
    required this.homeEnabled,
    required this.mapEnabled,
    required this.airportEnabled,
    required this.zoneOk,
    required this.zoneMessage,
    required this.onPickupMode,
    required this.onDropoffMode,
    required this.onReceiverSelf,
    required this.onAirport,
    required this.onPin,
    required this.onLocate,
  });

  final VehicleListing listing;
  final VehicleDeliveryMode pickupMode;
  final VehicleDeliveryMode dropoffMode;
  final TextEditingController city;
  final TextEditingController district;
  final TextEditingController neighborhood;
  final TextEditingController street;
  final TextEditingController building;
  final TextEditingController note;
  final bool receiverSelf;
  final TextEditingController receiverName;
  final TextEditingController receiverPhone;
  final bool airport;
  final LatLng? pin;
  final bool homeEnabled;
  final bool mapEnabled;
  final bool airportEnabled;
  final bool? zoneOk;
  final String? zoneMessage;
  final ValueChanged<VehicleDeliveryMode> onPickupMode;
  final ValueChanged<VehicleDeliveryMode> onDropoffMode;
  final ValueChanged<bool> onReceiverSelf;
  final ValueChanged<bool> onAirport;
  final ValueChanged<LatLng> onPin;
  final VoidCallback onLocate;

  bool get _needAddress => pickupMode != VehicleDeliveryMode.galleryPickup;

  @override
  Widget build(BuildContext context) {
    final gallery = listing.gallery;
    return Column(
      children: [
        VehicleRentalSectionCard(
          title: 'Teslim alma',
          child: Column(
            children: [
              RadioListTile<VehicleDeliveryMode>(
                title: const Text('Galeriden teslim al'),
                subtitle: Text(
                  [
                    gallery?.name,
                    gallery?.address,
                    gallery?.city,
                    gallery?.district,
                  ].where((e) => e != null && e.toString().trim().isNotEmpty).join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                value: VehicleDeliveryMode.galleryPickup,
                groupValue: pickupMode,
                onChanged: (v) => onPickupMode(v!),
              ),
              if (homeEnabled)
                RadioListTile<VehicleDeliveryMode>(
                  title: const Text('Adresime getir'),
                  value: VehicleDeliveryMode.homeDelivery,
                  groupValue: pickupMode,
                  onChanged: (v) => onPickupMode(v!),
                ),
              if (mapEnabled)
                RadioListTile<VehicleDeliveryMode>(
                  title: const Text('Farklı teslim noktası'),
                  value: VehicleDeliveryMode.mapPoint,
                  groupValue: pickupMode,
                  onChanged: (v) => onPickupMode(v!),
                ),
              if (airportEnabled)
                SwitchListTile(
                  title: const Text('Havalimanı teslimi'),
                  value: airport,
                  onChanged: onAirport,
                ),
              if (zoneMessage != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Text(
                      zoneMessage!,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: zoneOk == true
                            ? AppColors.success
                            : zoneOk == false
                                ? AppColors.orangeDark
                                : AppColors.textGrey,
                      ),
                    ),
                  ),
                ),
              if (zoneOk == false && pickupMode != VehicleDeliveryMode.galleryPickup)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => onPickupMode(VehicleDeliveryMode.galleryPickup),
                        child: const Text('Galeriden teslim al'),
                      ),
                      TextButton(
                        onPressed: onLocate,
                        child: const Text('Farklı konum seç'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (_needAddress) ...[
          const SizedBox(height: 12),
          VehicleRentalSectionCard(
            title: 'Teslim adresi',
            child: Column(
              children: [
                TextField(controller: city, decoration: const InputDecoration(labelText: 'İl')),
                TextField(controller: district, decoration: const InputDecoration(labelText: 'İlçe')),
                TextField(controller: neighborhood, decoration: const InputDecoration(labelText: 'Mahalle')),
                TextField(controller: street, decoration: const InputDecoration(labelText: 'Açık adres')),
                TextField(controller: building, decoration: const InputDecoration(labelText: 'Bina / daire')),
                TextField(controller: note, decoration: const InputDecoration(labelText: 'Adres tarifi')),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: onLocate,
                  icon: const Icon(Icons.my_location_outlined),
                  label: Text(
                    pin == null
                        ? 'Haritada konum seç / bul'
                        : 'Haritada göster / konumu düzenle',
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 180,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: FlutterMap(
                      key: ValueKey(
                        '${pin?.latitude ?? gallery?.lat}_${pin?.longitude ?? gallery?.lng}',
                      ),
                      options: MapOptions(
                        initialCenter: pin ??
                            LatLng(gallery?.lat ?? 36.4, gallery?.lng ?? 35.9),
                        initialZoom: pin == null ? 11 : 14,
                        onTap: (tap, point) => onPin(point),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.ibul.app',
                        ),
                        if (pin != null)
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: pin!,
                                width: 32,
                                height: 32,
                                child: const Icon(Icons.location_on, color: AppColors.primary),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        VehicleRentalSectionCard(
          title: 'Aracı kim teslim alacak?',
          child: Column(
            children: [
              RadioListTile<bool>(
                title: const Text('Ben'),
                value: true,
                groupValue: receiverSelf,
                onChanged: (v) => onReceiverSelf(v ?? true),
              ),
              RadioListTile<bool>(
                title: const Text('Başka biri'),
                value: false,
                groupValue: receiverSelf,
                onChanged: (v) => onReceiverSelf(v ?? true),
              ),
              if (!receiverSelf) ...[
                TextField(controller: receiverName, decoration: const InputDecoration(labelText: 'Ad soyad')),
                TextField(
                  controller: receiverPhone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Telefon'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        VehicleRentalSectionCard(
          title: 'Teslim etme / iade',
          child: Column(
            children: [
              RadioListTile<VehicleDeliveryMode>(
                title: const Text('Galeriye bırakacağım'),
                value: VehicleDeliveryMode.galleryPickup,
                groupValue: dropoffMode,
                onChanged: (v) => onDropoffMode(v!),
              ),
              RadioListTile<VehicleDeliveryMode>(
                title: const Text('Aldığım adresten teslim edeceğim'),
                value: VehicleDeliveryMode.homeDelivery,
                groupValue: dropoffMode,
                onChanged: (v) => onDropoffMode(v!),
              ),
              RadioListTile<VehicleDeliveryMode>(
                title: const Text('Farklı noktada bırakacağım'),
                value: VehicleDeliveryMode.mapPoint,
                groupValue: dropoffMode,
                onChanged: (v) => onDropoffMode(v!),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class VehicleRentalCustomerStep extends StatelessWidget {
  const VehicleRentalCustomerStep({
    super.key,
    required this.firstName,
    required this.lastName,
    required this.nationalId,
    required this.phone,
    required this.email,
    required this.licenseClass,
    required this.birthDate,
    required this.licenseIssued,
    required this.minAge,
    required this.minLicenseYears,
    required this.consent,
    required this.onBirthDate,
    required this.onLicenseIssued,
    required this.onLicenseClass,
    required this.onConsent,
  });

  final TextEditingController firstName;
  final TextEditingController lastName;
  final TextEditingController nationalId;
  final TextEditingController phone;
  final TextEditingController email;
  final String licenseClass;
  final DateTime? birthDate;
  final DateTime? licenseIssued;
  final int minAge;
  final int minLicenseYears;
  final bool consent;
  final VoidCallback onBirthDate;
  final VoidCallback onLicenseIssued;
  final ValueChanged<String> onLicenseClass;
  final ValueChanged<bool> onConsent;

  @override
  Widget build(BuildContext context) {
    return VehicleRentalSectionCard(
      title: 'Kiralayan bilgileri',
      child: Column(
        children: [
          TextField(controller: firstName, decoration: const InputDecoration(labelText: 'Ad *')),
          TextField(controller: lastName, decoration: const InputDecoration(labelText: 'Soyad *')),
          TextField(
            controller: nationalId,
            keyboardType: TextInputType.number,
            maxLength: 11,
            decoration: const InputDecoration(
              labelText: 'TC Kimlik No *',
              helperText: 'Format ve checksum kontrolü yapılır. Devlet doğrulaması değildir.',
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Doğum tarihi *'),
            subtitle: Text(
              birthDate == null
                  ? 'Seçin  ·  Minimum yaş $minAge'
                  : '${birthDate!.day}.${birthDate!.month}.${birthDate!.year}',
            ),
            onTap: onBirthDate,
          ),
          TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Telefon *'),
          ),
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'E-posta *'),
          ),
          DropdownButtonFormField<String>(
            initialValue: licenseClass,
            items: const [
              DropdownMenuItem(value: 'B', child: Text('B')),
              DropdownMenuItem(value: 'B1', child: Text('B1')),
              DropdownMenuItem(value: 'C', child: Text('C')),
              DropdownMenuItem(value: 'A', child: Text('A')),
            ],
            onChanged: (v) => onLicenseClass(v ?? 'B'),
            decoration: const InputDecoration(labelText: 'Ehliyet sınıfı *'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Ehliyet alınma tarihi *'),
            subtitle: Text(
              licenseIssued == null
                  ? (minLicenseYears > 0
                        ? 'Seçin  ·  En az $minLicenseYears yıl'
                        : 'Seçin')
                  : '${licenseIssued!.day}.${licenseIssued!.month}.${licenseIssued!.year}',
            ),
            onTap: onLicenseIssued,
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: consent,
            onChanged: (v) => onConsent(v ?? false),
            title: const Text(
              'Kimlik ve ehliyet bilgilerimin kiralama doğrulaması için işlenmesini kabul ediyorum.',
            ),
          ),
        ],
      ),
    );
  }
}

String deliveryModeLabel(VehicleDeliveryMode mode, {required bool dropoff}) {
  return switch (mode) {
    VehicleDeliveryMode.galleryPickup => dropoff ? 'Galeride' : 'Galeriden teslim',
    VehicleDeliveryMode.homeDelivery => dropoff ? 'Aldığım adresten' : 'Adresime getir',
    VehicleDeliveryMode.mapPoint => dropoff ? 'Farklı bırakış' : 'Farklı teslim noktası',
  };
}

String moneyLabel(num value) => VehicleMoney.format(value);
