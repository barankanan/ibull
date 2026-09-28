import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../widgets/ibul_page_state.dart';
import '../models/vehicle_listing.dart';
import '../services/vehicle_service.dart';
import 'vehicle_appointment_sheet.dart';

class VehicleChatPage extends StatefulWidget {
  const VehicleChatPage({
    super.key,
    required this.listingId,
    required this.sellerId,
    required this.sellerName,
  });

  final String listingId;
  final String sellerId;
  final String sellerName;

  @override
  State<VehicleChatPage> createState() => _VehicleChatPageState();
}

class _VehicleChatPageState extends State<VehicleChatPage> {
  final _controller = TextEditingController();
  String? _conversationId;
  List<Map<String, dynamic>> _messages = const [];
  bool _loading = true;
  String? _error;
  VehicleListing? _listing;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    try {
      final listing = await VehicleService.instance.listings.getById(
        widget.listingId,
      );
      final id = await VehicleService.instance.chats.openConversation(
        listingId: widget.listingId,
        sellerId: widget.sellerId,
      );
      final messages = await VehicleService.instance.chats.messages(id);
      if (!mounted) return;
      setState(() {
        _listing = listing;
        _conversationId = id;
        _messages = messages;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  Future<void> _send({String? actionType}) async {
    final text = _controller.text.trim();
    if (text.isEmpty && actionType == null) return;
    final id = _conversationId;
    if (id == null) return;
    await VehicleService.instance.chats.send(
      conversationId: id,
      body: text.isEmpty ? (actionType ?? '') : text,
      actionType: actionType,
    );
    _controller.clear();
    final messages = await VehicleService.instance.chats.messages(id);
    if (mounted) setState(() => _messages = messages);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.sellerName),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink,
      ),
      body: _loading
          ? const IbulPageState.loading()
          : _error != null
          ? IbulPageState.error(title: _error!, onAction: _boot)
          : Column(
              children: [
                if (_listing != null)
                  ListTile(
                    dense: true,
                    title: Text(_listing!.title),
                    subtitle: const Text('Bu araç hakkında konuşma'),
                  ),
                _actions(),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadii.md),
                          ),
                          child: Text('${msg['body'] ?? ''}'),
                        ),
                      );
                    },
                  ),
                ),
                SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          decoration: const InputDecoration(
                            hintText: 'Mesaj yazın',
                            contentPadding: EdgeInsets.all(12),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send, color: AppColors.primary),
                        onPressed: _send,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _actions() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          _chip('Fotoğraf', 'photo'),
          _chip('Ekspertiz', 'expertise'),
          _chip('Konum', 'location'),
          ActionChip(
            label: const Text('Randevu'),
            onPressed: _listing == null
                ? null
                : () => showVehicleAppointmentSheet(context, _listing!),
          ),
          ActionChip(
            label: const Text('Teklif'),
            onPressed: _listing == null
                ? null
                : () => showVehicleQuoteSheet(context, _listing!),
          ),
          ActionChip(
            label: const Text('Ara'),
            onPressed: _listing == null
                ? null
                : () => VehicleService.instance.callGallery(_listing!),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String action) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        label: Text(label),
        onPressed: () => _send(actionType: action),
      ),
    );
  }
}
