import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../domain/vehicle_catalog.dart';
import '../models/vehicle_enums.dart';
import '../models/vehicle_listing.dart';
import '../widgets/vehicle_rental_chrome.dart';

class VehicleRentalDocsStep extends StatelessWidget {
  const VehicleRentalDocsStep({
    super.key,
    required this.uploaded,
    required this.busyType,
    required this.onUpload,
    required this.onReplace,
    required this.onDelete,
    this.previews = const {},
    this.onView,
    this.uploadFailed,
    this.onRetry,
  });

  final Set<VehicleDocumentType> uploaded;
  final VehicleDocumentType? busyType;
  final Future<void> Function(VehicleDocumentType type) onUpload;
  final Future<void> Function(VehicleDocumentType type) onReplace;
  final Future<void> Function(VehicleDocumentType type) onDelete;
  final Map<VehicleDocumentType, Uint8List> previews;
  final Future<void> Function(VehicleDocumentType type)? onView;
  final VehicleDocumentType? uploadFailed;
  final Future<void> Function(VehicleDocumentType type)? onRetry;

  static const types = [
    VehicleDocumentType.driverLicenseFront,
    VehicleDocumentType.driverLicenseBack,
    VehicleDocumentType.identityFront,
    VehicleDocumentType.identityBack,
  ];

  @override
  Widget build(BuildContext context) {
    return VehicleRentalSectionCard(
      title: 'Belgeler',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kimlik ve ehliyet özel depoda tutulur. Herkese açık bağlantı oluşturulmaz.',
            style: TextStyle(fontSize: 12, color: AppColors.textGrey),
          ),
          const SizedBox(height: 12),
          for (final type in types)
            _DocCard(
              type: type,
              uploaded: uploaded.contains(type),
              busy: busyType == type,
              preview: previews[type],
              failed: uploadFailed == type,
              onUpload: () => onUpload(type),
              onReplace: () => onReplace(type),
              onDelete: () => onDelete(type),
              onView: onView == null ? null : () => onView!(type),
              onRetry: onRetry == null ? null : () => onRetry!(type),
            ),
        ],
      ),
    );
  }
}

class _DocCard extends StatelessWidget {
  const _DocCard({
    required this.type,
    required this.uploaded,
    required this.busy,
    required this.onUpload,
    required this.onReplace,
    required this.onDelete,
    this.preview,
    this.failed = false,
    this.onView,
    this.onRetry,
  });

  final VehicleDocumentType type;
  final bool uploaded;
  final bool busy;
  final VoidCallback onUpload;
  final VoidCallback onReplace;
  final VoidCallback onDelete;
  final Uint8List? preview;
  final bool failed;
  final VoidCallback? onView;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final status = busy
        ? 'Yükleniyor...'
        : failed
            ? 'Yükleme başarısız'
            : uploaded
                ? '✓ Yüklendi'
                : 'Yükle';
    final thumb = Container(
      width: 56,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: preview != null
          ? Image.memory(preview!, fit: BoxFit.cover, width: 56, height: 40)
          : Icon(
              uploaded ? Icons.check_circle : Icons.image_outlined,
              color: uploaded ? AppColors.success : AppColors.iconMuted,
            ),
    );
    final title = Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            type.labelTr,
            softWrap: true,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Text(
            status,
            style: TextStyle(
              fontSize: 12,
              color: uploaded ? AppColors.success : AppColors.textGrey,
            ),
          ),
        ],
      ),
    );
    final actions = _actions();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [thumb, const SizedBox(width: 10), title]),
                if (actions != null) ...[
                  const SizedBox(height: 8),
                  actions,
                ],
              ],
            )
          : Row(
              children: [
                thumb,
                const SizedBox(width: 10),
                title,
                ?actions,
              ],
            ),
    );
  }

  Widget? _actions() {
    if (busy) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (failed) {
      return TextButton(
        onPressed: onRetry,
        child: const Text('Tekrar dene'),
      );
    }
    if (!uploaded) {
      return FilledButton(onPressed: onUpload, child: const Text('Yükle'));
    }
    return Wrap(
      spacing: 4,
      runSpacing: 0,
      children: [
        if (onView != null)
          TextButton(onPressed: onView, child: const Text('Görüntüle')),
        TextButton(onPressed: onReplace, child: const Text('Değiştir')),
        TextButton(
          onPressed: onDelete,
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          child: const Text('Sil'),
        ),
      ],
    );
  }
}

class VehicleRentalSummaryStep extends StatelessWidget {
  const VehicleRentalSummaryStep({
    super.key,
    required this.listing,
    required this.days,
    required this.pickup,
    required this.returnAt,
    required this.pickupLabel,
    required this.dropoffLabel,
    required this.customerName,
    required this.customerPhone,
    required this.customerEmail,
    required this.nationalIdMasked,
    required this.address,
    required this.rental,
    required this.delivery,
    required this.deposit,
    required this.total,
    required this.terms,
    required this.onTerms,
    this.contractTitle,
    this.contractMissing = false,
    this.onViewContract,
  });

  final VehicleListing listing;
  final int days;
  final DateTime pickup;
  final DateTime returnAt;
  final String pickupLabel;
  final String dropoffLabel;
  final String customerName;
  final String customerPhone;
  final String customerEmail;
  final String nationalIdMasked;
  final String address;
  final double rental;
  final double delivery;
  final double deposit;
  final double total;
  final bool terms;
  final ValueChanged<bool> onTerms;
  final String? contractTitle;
  final bool contractMissing;
  final VoidCallback? onViewContract;

  @override
  Widget build(BuildContext context) {
    return VehicleRentalSectionCard(
      title: 'Rezervasyon özeti',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(listing.title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('${rentalDateLabel(pickup)} ${rentalTimeLabel(pickup)}  →  ${rentalDateLabel(returnAt)} ${rentalTimeLabel(returnAt)}'),
          Text('$days gün', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Teslim: $pickupLabel'),
          if (address.trim().isNotEmpty) Text(address),
          Text('İade: $dropoffLabel'),
          const SizedBox(height: 8),
          const Text('Kiralayan', style: TextStyle(fontWeight: FontWeight.w700)),
          Text(customerName),
          if (customerPhone.trim().isNotEmpty) Text(customerPhone),
          if (customerEmail.trim().isNotEmpty) Text(customerEmail),
          if (nationalIdMasked.trim().isNotEmpty) Text('TC  $nationalIdMasked'),
          const Divider(height: 24),
          Text('Kiralama  ${VehicleMoney.format(rental)}'),
          Text('Teslim    ${VehicleMoney.format(delivery)}'),
          Text('Depozito  ${VehicleMoney.format(deposit)}  ·  İade edilebilir'),
          Text(
            'Toplam    ${VehicleMoney.format(total)}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: terms,
            onChanged: contractMissing ? null : (v) => onTerms(v ?? false),
            title: const Text(
              'Araç Kiralama Sözleşmesini okudum ve kabul ediyorum',
            ),
          ),
          if (contractMissing)
            const Text(
              'Bu mağaza henüz araç kiralama sözleşmesi tanımlamamış.',
              style: TextStyle(color: AppColors.textGrey, fontSize: 12),
            )
          else
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onViewContract,
                child: const Text('Sözleşmeyi Görüntüle'),
              ),
            ),
        ],
      ),
    );
  }
}

class VehicleRentalPaymentStep extends StatelessWidget {
  const VehicleRentalPaymentStep({
    super.key,
    required this.total,
  });

  final double total;

  @override
  Widget build(BuildContext context) {
    return VehicleRentalSectionCard(
      title: 'Ödeme / Talep',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Online ödeme altyapısı henüz aktif değil.\n'
            'Bu aşamada kartınızdan ücret çekilmeyecek.\n'
            'Kiralama talebiniz satıcıya gönderilecektir.',
          ),
          const SizedBox(height: 16),
          Text(
            'Ödenecek toplam  ${VehicleMoney.format(total)}',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class VehicleRentalDoneStep extends StatelessWidget {
  const VehicleRentalDoneStep({
    super.key,
    required this.status,
    this.rentalCode,
  });

  final String? status;
  final String? rentalCode;

  @override
  Widget build(BuildContext context) {
    final review = status == 'pending_seller_review' || status == 'pending_payment';
    return VehicleRentalSectionCard(
      title: 'Talep alındı',
      child: Column(
        children: [
          const Icon(Icons.check_circle, color: AppColors.success, size: 56),
          const SizedBox(height: 12),
          Text(
            review
                ? 'Kiralama talebiniz satıcıya gönderildi.'
                : 'Talep kaydedildi',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ödeme, satıcı onayından ve bağlı tahsilat altyapısından sonra alınır.',
            textAlign: TextAlign.center,
          ),
          if (rentalCode != null && rentalCode!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Kiralama kodu: $rentalCode'),
            ),
        ],
      ),
    );
  }
}
