import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../widgets/web_header.dart';
import '../widgets/web_footer.dart';
import '../widgets/account_sidebar.dart';

class AddressesPage extends StatefulWidget {
  const AddressesPage({super.key});

  @override
  State<AddressesPage> createState() => _AddressesPageState();
}

class _AddressesPageState extends State<AddressesPage> {
  int _selectedTab = 0;
  
  final List<Map<String, String>> _deliveryAddresses = [
    {'title': 'Ev', 'detail': 'Prefabrik ev - Gökmeydan Mah. Nazım Hikmet Kültür Merkezi Karşısı Prefabrik Ev No: 5, Eskişehir / Odunpazarı'},
    {'title': 'İş', 'detail': 'Teknopark - Organize Sanayi Bölgesi, Eskişehir / Odunpazarı'},
  ];

  final List<Map<String, String>> _billingInfos = [
    {'title': 'Kişisel Fatura', 'detail': 'Baran Kananogullari - 1234567890\nGökmeydan Mah. No:5, Eskişehir'},
  ];

  void _openEditScreen({Map<String, String>? address, int? index}) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: _AddressEditSheet(
            initialData: address,
            type: _selectedTab == 0 ? 'Adres' : 'Fatura',
            onSave: (Map<String, String> newAddress) {
              setState(() {
                if (_selectedTab == 0) {
                  if (index != null) {
                    _deliveryAddresses[index] = newAddress;
                  } else {
                    _deliveryAddresses.add(newAddress);
                  }
                } else {
                  if (index != null) {
                    _billingInfos[index] = newAddress;
                  } else {
                    _billingInfos.add(newAddress);
                  }
                }
              });
            },
            onDelete: () {
              if (index != null) {
                setState(() {
                  if (_selectedTab == 0) {
                    _deliveryAddresses.removeAt(index);
                  } else {
                    _billingInfos.removeAt(index);
                  }
                });
              }
            },
          ),
        ),
      ),
    );
  }

  void _deleteAddress(int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Adresi Sil"),
          content: const Text("Bu adresi silmek istediğinizden emin misiniz?"),
          actions: [
            TextButton(
              child: const Text("İptal"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text("Sil", style: TextStyle(color: Colors.red)),
              onPressed: () {
                setState(() {
                  if (_selectedTab == 0) {
                    _deliveryAddresses.removeAt(index);
                  } else {
                    _billingInfos.removeAt(index);
                  }
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width >= 800;

    if (isWeb) {
      return _buildWebView();
    }

    return _buildMobileView();
  }

  Widget _buildWebView() {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          WebHeader(onSearch: (q) {}),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left Sidebar
                            const SizedBox(
                              width: 280,
                              child: AccountSidebar(activePage: 'Adreslerim'),
                            ),
                            const SizedBox(width: 32),
                            // Right Content
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Adreslerim',
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1F2937),
                                        ),
                                      ),
                                      ElevatedButton.icon(
                                        onPressed: () => _openEditScreen(),
                                        icon: const Icon(Icons.add, size: 18),
                                        label: Text(_selectedTab == 0 ? 'Yeni Adres Ekle' : 'Yeni Fatura Ekle'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  
                                  // Web Tabs
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.grey.shade200),
                                    ),
                                    child: Column(
                                      children: [
                                        // Custom Tab Bar
                                        Container(
                                          decoration: BoxDecoration(
                                            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 24),
                                          child: Row(
                                            children: [
                                              _buildWebTabItem('Teslimat Adreslerim', 0),
                                              const SizedBox(width: 32),
                                              _buildWebTabItem('Fatura Bilgilerim', 1),
                                            ],
                                          ),
                                        ),
                                        
                                        // Content Grid
                                        Padding(
                                          padding: const EdgeInsets.all(24),
                                          child: _buildWebAddressGrid(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const WebFooter(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebTabItem(String label, int index) {
    final isActive = _selectedTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          border: isActive ? const Border(bottom: BorderSide(color: AppColors.primary, width: 2)) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? AppColors.primary : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildWebAddressGrid() {
    final list = _selectedTab == 0 ? _deliveryAddresses : _billingInfos;
    
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(Icons.location_off_outlined, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                'Kayıtlı ${_selectedTab == 0 ? 'adres' : 'fatura bilgisi'} bulunamadı',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.2,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
      ),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _selectedTab == 0 ? Icons.place : Icons.receipt,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    item['title']!,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                    onPressed: () => _deleteAddress(index),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.grey),
                    onPressed: () => _openEditScreen(address: item, index: index),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Text(
                  item['detail']!,
                  style: TextStyle(color: Colors.grey.shade600, height: 1.5),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 3,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMobileView() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Adreslerim',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
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
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _selectedTab == 0 ? _deliveryAddresses.length : _billingInfos.length,
              itemBuilder: (context, index) {
                final item = _selectedTab == 0 ? _deliveryAddresses[index] : _billingInfos[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      child: Icon(
                        _selectedTab == 0 ? Icons.place : Icons.receipt,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    title: Text(item['title']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(item['detail']!, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                          onPressed: () => _deleteAddress(index),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.grey),
                          onPressed: () => _openEditScreen(address: item, index: index),
                        ),
                      ],
                    ),
                    onTap: () {
                       _openEditScreen(address: item, index: index);
                    },
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
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
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({required String label, required bool isActive, required VoidCallback onTap}) {
    return SizedBox(
      height: 40,
      child: isActive
          ? ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
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
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: EdgeInsets.zero,
              ),
              child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
    );
  }
}

class _AddressEditSheet extends StatefulWidget {
  final Map<String, String>? initialData;
  final String type;
  final Function(Map<String, String>) onSave;
  final VoidCallback onDelete;

  const _AddressEditSheet({
    this.initialData, 
    required this.type,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<_AddressEditSheet> createState() => _AddressEditSheetState();
}

class _AddressEditSheetState extends State<_AddressEditSheet> {
  late TextEditingController _titleController;
  late TextEditingController _nameController;
  late TextEditingController _surnameController;
  late TextEditingController _phoneController;
  late TextEditingController _cityController;
  late TextEditingController _buildingController; // Bina, site, iş yeri, kurum ismi
  late TextEditingController _detailController; // Açık adres (Sokak, Mahalle vb.)
  
  String _addressType = 'Ev'; // 'Ev' or 'İş Yeri'

  @override
  void initState() {
    super.initState();
    // Mevcut verileri doldur (Basit string parsing yapılmadığı için sadece başlık ve detay var varsayıyoruz)
    _titleController = TextEditingController(text: widget.initialData?['title'] ?? '');
    _detailController = TextEditingController(text: widget.initialData?['detail'] ?? '');
    
    // Diğer alanlar boş başlatılıyor (Gerçek uygulamada modelden gelmeli)
    _nameController = TextEditingController();
    _surnameController = TextEditingController();
    _phoneController = TextEditingController();
    _cityController = TextEditingController();
    _buildingController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _nameController.dispose();
    _surnameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _buildingController.dispose();
    _detailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isEditing = widget.initialData != null;
    bool isAddress = widget.type == 'Adres';
    
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
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
            
            // Ad ve Soyad
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Ad',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _surnameController,
                    decoration: InputDecoration(
                      labelText: 'Soyad',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Telefon
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Telefon Numarası',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                prefixIcon: const Icon(Icons.phone_android, size: 20, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 16),
            
            // Adres Tipi Seçimi (Sadece Adres için)
            if (isAddress) ...[
              const Text(
                'Ev Bilginiz',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildTypeSelection('Ev', Icons.home),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTypeSelection('İş Yeri', Icons.work),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Şehir ve İlçe (Basitlik için tek Şehir alanı)
            TextField(
              controller: _cityController,
              decoration: InputDecoration(
                labelText: 'Şehir',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
            ),
            const SizedBox(height: 16),
            
            // Bina / Site / Kurum İsmi
            TextField(
              controller: _buildingController,
              decoration: InputDecoration(
                labelText: 'Bina, Site, İş Yeri, Kurum İsmi',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
            ),
            const SizedBox(height: 16),

            // Açık Adres
            TextField(
              controller: _detailController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Açık Adres (Mahalle, Sokak, Kapı No)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),

            // Adres Başlığı
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Bu Adrese İsim Ver (Örn: Evim, Ofisim)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                prefixIcon: const Icon(Icons.bookmark_border, size: 20, color: Colors.grey),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Butonlar
            Row(
              children: [
                if (isEditing) 
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        widget.onDelete();
                        Navigator.pop(context);
                      },
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
                      // Validate and Save
                      if (_titleController.text.isNotEmpty && _detailController.text.isNotEmpty) {
                        final newAddress = {
                          'title': _titleController.text,
                          'detail': _detailController.text,
                          // Gerçek uygulamada diğer alanlar da eklenmeli
                          // 'name': _nameController.text,
                          // 'phone': _phoneController.text,
                          // ...
                        };
                        widget.onSave(newAddress);
                        Navigator.pop(context);
                      } else {
                        // Show validation error
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Lütfen zorunlu alanları doldurun')),
                        );
                      }
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
      ),
    );
  }

  Widget _buildTypeSelection(String label, IconData icon) {
    bool isSelected = _addressType == label;
    return InkWell(
      onTap: () {
        setState(() {
          _addressType = label;
          // Otomatik başlık önerisi
          if (_titleController.text.isEmpty || _titleController.text == 'Ev' || _titleController.text == 'İş Yeri') {
            _titleController.text = label;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? AppColors.primary : Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppColors.primary : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
