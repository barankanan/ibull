import 'package:flutter/material.dart';

import '../../../../core/constants.dart';
import '../../../../models/seller_saved_address.dart';

/// Kargo Çıkışı modalındaki kayıtlı müşteri adresleri listesi.
class SellerCargoSavedAddressesSection extends StatefulWidget {
  const SellerCargoSavedAddressesSection({
    super.key,
    required this.addresses,
    required this.selectedId,
    required this.isLoading,
    required this.onSelected,
  });

  final List<SellerSavedAddress> addresses;
  final String? selectedId;
  final bool isLoading;
  final ValueChanged<SellerSavedAddress> onSelected;

  @override
  State<SellerCargoSavedAddressesSection> createState() =>
      _SellerCargoSavedAddressesSectionState();
}

class _SellerCargoSavedAddressesSectionState
    extends State<SellerCargoSavedAddressesSection> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = filterSellerSavedAddresses(
      widget.addresses,
      _searchController.text,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Kayıtlı Adresler',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1F2A44),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('seller_cargo_saved_address_search'),
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Adres, isim veya telefon ara...',
            prefixIcon: const Icon(Icons.search_rounded, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (widget.isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (filtered.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              widget.addresses.isEmpty
                  ? 'Henüz kayıtlı adres yok. Formdaki adresi kaydetmek için "Adresi Kaydet"e basın.'
                  : 'Aramanızla eşleşen kayıtlı adres bulunamadı.',
              style: const TextStyle(fontSize: 12, color: Color(0xFF667085)),
            ),
          )
        else
          Container(
            constraints: const BoxConstraints(maxHeight: 190),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: filtered.length,
              separatorBuilder: (context, index) =>
                  Divider(height: 1, color: Colors.grey.shade200),
              itemBuilder: (context, index) {
                final address = filtered[index];
                final selected = address.id == widget.selectedId;
                return InkWell(
                  key: Key('seller_cargo_saved_address_${address.id}'),
                  onTap: () => widget.onSelected(address),
                  child: Container(
                    color: selected
                        ? const Color(0xFFF5F8FF)
                        : Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selected ? Icons.place : Icons.place_outlined,
                          size: 18,
                          color: selected
                              ? AppColors.primary
                              : const Color(0xFF667085),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                address.customerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: selected
                                      ? AppColors.primary
                                      : const Color(0xFF1F2A44),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                address.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF667085),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                [
                                  if (address.building.isNotEmpty)
                                    address.building,
                                  address.address,
                                ].join(', '),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
