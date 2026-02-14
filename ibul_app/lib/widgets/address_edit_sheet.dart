import 'package:flutter/material.dart';
import '../core/constants.dart';

class AddressEditSheet extends StatefulWidget {
  final Map<String, String>? initialData;
  final String type;
  final Function(Map<String, String>) onSave;
  final VoidCallback onDelete;

  const AddressEditSheet({
    super.key,
    this.initialData, 
    required this.type,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<AddressEditSheet> createState() => _AddressEditSheetState();
}

class _AddressEditSheetState extends State<AddressEditSheet> {
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