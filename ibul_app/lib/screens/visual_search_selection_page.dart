import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/constants.dart';
import 'visual_intelligence_result_page.dart';

class VisualSearchSelectionPage extends StatelessWidget {
  const VisualSearchSelectionPage({super.key});

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source);

      if (image != null) {
        if (!context.mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VisualIntelligenceResultPage(
              detectedProduct: image.name,
              missingPart: 'Parça ve Uyumlu Ürünler',
              imagePath: image.path,
              imageName: image.name,
              mode: VisualIntelligenceMode.parts,
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width >= 800;
    const double webMaxWidth = 900;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Görsel Zeka',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isWeb ? webMaxWidth : double.infinity,
          ),
          child: ListView(
            children: [
              _buildOptionTile(
                context,
                title: 'Fotoğraf Çek',
                onTap: () => _pickImage(context, ImageSource.camera),
              ),
              const Divider(height: 1, color: Color(0xFFEEEEEE)),
              _buildOptionTile(
                context,
                title: 'Fotoğraf Yükle',
                onTap: () => _pickImage(context, ImageSource.gallery),
              ),
              const Divider(height: 1, color: Color(0xFFEEEEEE)),
              _buildOptionTile(
                context,
                title: 'Barkod Okut',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Barkod okuma özelliği yakında eklenecek.'),
                    ),
                  );
                },
              ),
              const Divider(height: 1, color: Color(0xFFEEEEEE)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile(
    BuildContext context, {
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 14,
        color: Colors.grey[400],
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: onTap,
      tileColor: Colors.white,
    );
  }
}
