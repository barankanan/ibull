import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/app_state.dart';
import 'address_edit_sheet.dart';

class AddressBar extends StatelessWidget {
  final String currentAddress;
  final Function(String)? onAddressChanged;

  const AddressBar({
    super.key,
    this.currentAddress = 'Prefabrik ev-Gökmeydan Mah. Nazım Hikmet kül...',
    this.onAddressChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Adresim',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            // ...
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    currentAddress,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      builder: (context) => AddressSelectionSheet(
                        onSelected: onAddressChanged,
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.primary),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sync, size: 12, color: AppColors.primary),
                        SizedBox(width: 4),
                        Text(
                          'Değiştir',
                          style: TextStyle(fontSize: 10, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AddressSelectionSheet extends StatefulWidget {
  final Function(String)? onSelected;

  const AddressSelectionSheet({super.key, this.onSelected});

  @override
  State<AddressSelectionSheet> createState() => AddressSelectionSheetState();
}

class AddressSelectionSheetState extends State<AddressSelectionSheet> {
  int _selectedTab = 0; // 0: Teslimat, 1: Fatura

  void _openEditScreen({Map<String, String>? address, int? index}) {
    Navigator.pop(context); // Close selection sheet first
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AddressEditSheet(
        initialData: address,
        type: _selectedTab == 0 ? 'Adres' : 'Fatura',
        onSave: (Map<String, String> newAddress) async {
          final appState = context.read<AppState>();
          if (_selectedTab == 0) {
            if (index != null) {
              await appState.updateDeliveryAddress(index, newAddress);
            } else {
              await appState.addDeliveryAddress(newAddress);
              // Yeni eklenen adresi otomatik seç
              if (widget.onSelected != null && newAddress['detail'] != null) {
                widget.onSelected!(newAddress['detail']!);
              }
            }
          } else {
            if (index != null) {
              appState.updateBillingInfo(index, newAddress);
            } else {
              appState.addBillingInfo(newAddress);
            }
          }
          // Re-open selection sheet to show updated list
          // showModalBottomSheet(...) // Optional, might be annoying if it pops up again
        },
        onDelete: () {
             if (index != null) {
               final appState = context.read<AppState>();
               if (_selectedTab == 0) {
                 appState.removeDeliveryAddress(index);
               } else {
                 appState.removeBillingInfo(index);
               }
             }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final list = _selectedTab == 0 ? appState.deliveryAddresses : appState.billingInfos;
        
        return Container(
          padding: const EdgeInsets.only(top: 20, left: 16, right: 16, bottom: 40),
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Adreslerim',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildTabs(),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final item = list[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        child: Icon(
                          _selectedTab == 0 ? Icons.place : Icons.receipt,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      title: Text(item['title']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text(item['detail']!, style: const TextStyle(fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.grey),
                        onPressed: () => _openEditScreen(address: item, index: index),
                      ),
                      onTap: () {
                         if (widget.onSelected != null) {
                           widget.onSelected!(item['detail']!); 
                           Navigator.pop(context);
                         } else {
                           _openEditScreen(address: item, index: index);
                         }
                      },
                    );
                  },
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 45,
                child: ElevatedButton.icon(
                  onPressed: () => _openEditScreen(),
                  icon: const Icon(Icons.add),
                  label: Text(_selectedTab == 0 ? 'Yeni Adres Ekle' : 'Yeni Fatura Ekle'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabs() {
    return Row(
      children: [
        Expanded(
          child: _buildTabButton(
            label: 'Teslimat Adreslerim',
            isActive: _selectedTab == 0,
            onTap: () => setState(() => _selectedTab = 0),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildTabButton(
            label: 'Fatura Bilgilerim',
            isActive: _selectedTab == 1,
            onTap: () => setState(() => _selectedTab = 1),
          ),
        ),
      ],
    );
  }

  Widget _buildTabButton({required String label, required bool isActive, required VoidCallback onTap}) {
    return SizedBox(
      height: 36, // Reduced height as requested
      child: isActive
          ? ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6200EE),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: EdgeInsets.zero,
              ),
              child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            )
          : OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF6200EE),
                side: const BorderSide(color: Color(0xFF6200EE)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: EdgeInsets.zero,
              ),
              child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
    );
  }
}
