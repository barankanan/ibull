import 'package:flutter/material.dart';
import '../widgets/address_bar.dart';

class CourierInfoPage extends StatefulWidget {
  const CourierInfoPage({super.key});

  @override
  State<CourierInfoPage> createState() => _CourierInfoPageState();
}

class _CourierInfoPageState extends State<CourierInfoPage> {
  bool isAtAddress = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF4A00E0), // Deep purple matching the image
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Kurye Bilgi',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Kurye',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
            const Divider(),
            _buildInfoRow(
              icon: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFF4A00E0),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('BP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              title: 'Kurye',
              subtitle: 'Baran Kananoğulları',
            ),
            const Divider(),
            _buildInfoRow(
              icon: const SizedBox(
                 width: 40,
                child: Icon(Icons.delivery_dining, color: Color(0xFF4A00E0), size: 28),
              ),
              title: 'Teslimat',
              subtitle: 'Tahmini 4 Saate Adresteyiz',
            ),
            const Divider(),
             _buildInfoRow(
              icon: const SizedBox(
                 width: 40,
                child: Icon(Icons.phone_in_talk_outlined, color: Color(0xFF4A00E0), size: 28),
              ),
              title: 'İletişim Bilgisi',
              subtitle: '0537 624 7077',
            ),
            const Divider(),
             _buildInfoRow(
              icon: const SizedBox(
                 width: 40,
                child: Icon(Icons.moped, color: Color(0xFF4A00E0), size: 28),
              ),
              title: 'Araç',
              subtitle: 'Motor (31 İAB 111)',
            ),
             const Divider(),
             _buildInfoRow(
              icon: const SizedBox(
                 width: 40,
                child: Icon(Icons.map_outlined, color: Color(0xFF4A00E0), size: 28),
              ),
              title: 'Ücretlendirme',
              subtitle: 'Km başında 6,30 TL',
              hasArrow: true,
            ),
             const Divider(),
             const SizedBox(height: 30),
             const Text(
              'Adres',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  const SizedBox(
                    width: 40,
                    child: Icon(Icons.home_outlined, color: Color(0xFF4A00E0), size: 30),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Adresteyim',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Adresimi Doğrula',
                          style: TextStyle(fontSize: 13, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: isAtAddress, 
                    activeThumbColor: const Color(0xFF4A00E0),
                    onChanged: (val) {
                      setState(() {
                        isAtAddress = val;
                      });
                    }
                  ),
                ],
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: InkWell(
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
                child: Row(
                  children: [
                    const SizedBox(
                      width: 40,
                      child: Icon(Icons.add, color: Color(0xFF4A00E0), size: 30),
                    ),
                     const SizedBox(width: 12),
                     const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Adres Değiştir',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Yeni adres ekle',
                            style: TextStyle(fontSize: 13, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),


          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required Widget icon,
    required String title,
    required String subtitle,
    bool hasArrow = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
          ),
          if (hasArrow)
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        ],
      ),
    );
  }
}
