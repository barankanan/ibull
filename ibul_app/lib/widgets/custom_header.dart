import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../core/constants.dart';
import '../screens/notifications_page.dart';
import '../screens/camera_page.dart';

class CustomHeader extends StatefulWidget {
  final ValueChanged<String> onSearch;

  const CustomHeader({super.key, required this.onSearch});

  @override
  State<CustomHeader> createState() => _CustomHeaderState();
}

class _CustomHeaderState extends State<CustomHeader> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
            setState(() => _isListening = false);
          }
        },
        onError: (val) {
          setState(() => _isListening = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: ${val.errorMsg}')),
          );
        },
      );

      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) {
            setState(() {
              _searchController.text = val.recognizedWords;
              if (val.hasConfidenceRating && val.confidence > 0) {
                // Optional: Show confidence
              }
            });
            
            // Otomatik arama yap (kullanıcı durakladığında veya konuşma bittiğinde)
            if (val.finalResult) {
              widget.onSearch(val.recognizedWords);
              setState(() => _isListening = false);
            }
          },
          localeId: 'tr_TR', // Türkçe desteği için
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mikrofon izni verilmedi veya cihaz desteklemiyor.')),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          _IconCircleButton(
            icon: Icons.notifications_none,
            onPressed: () {
               Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationsPage()),
              );
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _isListening ? Colors.red : Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onSubmitted: (value) {
                        final query = value.trim();
                        if (query.isNotEmpty) widget.onSearch(query);
                      },
                      decoration: InputDecoration(
                        hintText: _isListening ? 'Dinleniyor...' : 'Marka, ürün veya kategori ara',
                        hintStyle: TextStyle(
                          color: _isListening ? Colors.red : Colors.grey[600], 
                          fontSize: 12
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  IconButton(
                    onPressed: _listen,
                    icon: Icon(
                      _isListening ? Icons.mic : Icons.mic_none, 
                      color: _isListening ? Colors.red : AppColors.primary
                    ),
                    splashRadius: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          _IconCircleButton(
            icon: Icons.camera_alt_outlined,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CameraPage()),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _IconCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _IconCircleButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, color: Colors.grey[800], size: 22),
        onPressed: onPressed,
      ),
    );
  }
}
