import 'package:flutter/material.dart';
import '../core/constants.dart';

class AddressBar extends StatelessWidget {
  const AddressBar({super.key});

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
                const Expanded(
                  child: Text(
                    'Prefabrik ev-Gökmeydan Mah. Nazım Hikmet kül...',
                    style: TextStyle(fontSize: 12),
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
                      builder: (context) => const AddressSelectionSheet(),
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
  const AddressSelectionSheet({super.key});

  @override
  State<AddressSelectionSheet> createState() => AddressSelectionSheetState();
}

class AddressSelectionSheetState extends State<AddressSelectionSheet> {
  int _selectedTab = 0; // 0: Teslimat, 1: Fatura
  
  // Dummy data
  final List<Map<String, String>> _deliveryAddresses = [
    {'title': 'Ev', 'detail': 'Prefabrik ev - Gökmeydan Mah..'},
    {'title': 'İş', 'detail': 'Teknopark - Organize Sanayi Bölgesi'},
  ];

  final List<Map<String, String>> _billingInfos = [
    {'title': 'Kişisel Fatura', 'detail': 'Baran Kananogullari - 1234567890'},
  ];

  void _openEditScreen({Map<String, String>? address}) {
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 20, left: 16, right: 16, bottom: 40),
      // Dynamic height handling
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
              itemCount: _selectedTab == 0 ? _deliveryAddresses.length : _billingInfos.length,
              itemBuilder: (context, index) {
                final item = _selectedTab == 0 ? _deliveryAddresses[index] : _billingInfos[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    child: Icon(
                      _selectedTab == 0 ? Icons.place : Icons.receipt,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  title: Text(item['title']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text(item['detail']!, style: const TextStyle(fontSize: 12)),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.grey),
                    onPressed: () => _openEditScreen(address: item),
                  ),
                  onTap: () {
                     // Select logic here usually
                     _openEditScreen(address: item);
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

class AddressEditSheet extends StatefulWidget {
  final Map<String, String>? initialData;
  final String type; // 'Adres' or 'Fatura'

  const AddressEditSheet({super.key, this.initialData, required this.type});

  @override
  State<AddressEditSheet> createState() => AddressEditSheetState();
}

class AddressEditSheetState extends State<AddressEditSheet> {
  late TextEditingController _titleController;
  late TextEditingController _detailController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialData?['title'] ?? '');
    _detailController = TextEditingController(text: widget.initialData?['detail'] ?? '');
  }

  @override
  Widget build(BuildContext context) {
    bool isEditing = widget.initialData != null;
    
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20, right: 20, top: 20
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
             Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isEditing ? '${widget.type} Düzenle' : 'Yeni ${widget.type} Ekle',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              )
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'Başlık (Örn: Ev, İş)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _detailController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Detaylı Adres',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              if (isEditing) 
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.delete, size: 18),
                    label: const Text('Sil'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              if (isEditing) const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Save logic
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.save, size: 18),
                  label: Text(isEditing ? 'Güncelle' : 'Kaydet'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
