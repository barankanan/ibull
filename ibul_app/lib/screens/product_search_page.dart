import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/constants.dart';
import 'visual_intelligence_result_page.dart';

class ProductSearchPage extends StatelessWidget {
  const ProductSearchPage({super.key});

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
              missingPart: 'Benzer Ürünler',
              imagePath: image.path,
              imageName: image.name,
              mode: VisualIntelligenceMode.similar,
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Ürünü Arat',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isWeb ? webMaxWidth : double.infinity,
          ),
          child: Column(
            children: [
              const Divider(height: 1, thickness: 1),
              _buildOption(
                context,
                title: 'Fotoğraf Çek',
                onTap: () => _pickImage(context, ImageSource.camera),
              ),
              const Divider(height: 1, thickness: 1),
              _buildOption(
                context,
                title: 'Fotoğraf Yükle',
                onTap: () => _pickImage(context, ImageSource.gallery),
              ),
              const Divider(height: 1, thickness: 1),
              _buildOption(
                context,
                title: 'Barkod Okut',
                onTap: () {
                  // Barkod okuyucu
                },
              ),
              const Divider(height: 1, thickness: 1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
            const Icon(Icons.chevron_right, color: Colors.black54, size: 24),
          ],
        ),
      ),
    );
  }
}
