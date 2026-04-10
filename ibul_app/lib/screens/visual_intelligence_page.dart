import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../services/visual_intelligence_service.dart';
import 'visual_intelligence_result_page.dart';

class VisualIntelligencePage extends StatefulWidget {
  const VisualIntelligencePage({super.key});

  @override
  State<VisualIntelligencePage> createState() => _VisualIntelligencePageState();
}

class _VisualIntelligencePageState extends State<VisualIntelligencePage> {
  String? _capturedImagePath;
  int _selectedMode = 2; // FOTOĞRAF mode selected by default

  final List<String> _modes = [
    'AĞIR ÇEKİM',
    'VİDEO',
    'FOTOĞRAF',
    'PORTRE',
    'PANORAMA',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview area (mock)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.grey.shade300, Colors.grey.shade400],
                ),
              ),
              child: _capturedImagePath == null
                  ? Center(
                      child: Icon(
                        Icons.camera_alt_outlined,
                        size: 100,
                        color: Colors.grey.shade600,
                      ),
                    )
                  : Image.asset(
                      'assets/images/sample_bike.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Icon(
                            Icons.directions_bike,
                            size: 150,
                            color: Colors.green.shade700,
                          ),
                        );
                      },
                    ),
            ),
          ),

          // Top bar with back button
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 28,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Zoom indicator (bottom left)
          if (_capturedImagePath != null)
            Positioned(
              bottom: 180,
              left: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Text(
                      '0,5',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '1,9×',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Mode selector
                  Container(
                    height: 60,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _modes.length,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemBuilder: (context, index) {
                        final isSelected = index == _selectedMode;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedMode = index;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            alignment: Alignment.center,
                            child: Text(
                              _modes[index],
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.orange
                                    : Colors.white.withValues(alpha: 0.6),
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Camera controls
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Gallery preview
                        GestureDetector(
                          onTap: () {
                            // Open gallery
                          },
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade800,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: _capturedImagePath != null
                                ? Icon(
                                    Icons.directions_bike,
                                    color: Colors.green.shade700,
                                    size: 30,
                                  )
                                : Icon(
                                    Icons.image,
                                    color: Colors.grey.shade600,
                                  ),
                          ),
                        ),

                        // Capture button
                        GestureDetector(
                          onTap: _capturePhoto,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 5),
                            ),
                            child: Container(
                              margin: const EdgeInsets.all(5),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),

                        // Flip camera button
                        GestureDetector(
                          onTap: () {
                            // Flip camera
                          },
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade800,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.cameraswitch,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Continue button (shows after capture)
                  if (_capturedImagePath != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                      child: SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _analyzeAndContinue,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Devam Et',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _capturePhoto() {
    final capture = VisualIntelligenceService.capturePlaceholder();
    setState(() {
      _capturedImagePath = capture.previewToken;
    });
  }

  void _analyzeAndContinue() {
    final capture = VisualIntelligenceService.capturePlaceholder();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VisualIntelligenceResultPage(
          detectedProduct: capture.detectedProduct,
          missingPart: capture.missingPart,
        ),
      ),
    );
  }
}
