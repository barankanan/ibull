import 'package:flutter/material.dart';

import '../models/vehicle_enums.dart';
import '../models/vehicle_listing.dart';
import '../services/vehicle_service.dart';

Future<void> showVehicleAppointmentSheet(
  BuildContext context,
  VehicleListing listing,
) async {
  DateTime scheduled = DateTime.now().add(const Duration(days: 1));
  var kind = VehicleAppointmentKind.gallery;
  final note = TextEditingController();
  try {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: StatefulBuilder(
            builder: (context, setModal) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Randevu Al',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<VehicleAppointmentKind>(
                    initialValue: kind,
                    items: const [
                      DropdownMenuItem(
                        value: VehicleAppointmentKind.gallery,
                        child: Text('Galeride görüşme'),
                      ),
                      DropdownMenuItem(
                        value: VehicleAppointmentKind.customerLocation,
                        child: Text('Seçtiğim konum'),
                      ),
                      DropdownMenuItem(
                        value: VehicleAppointmentKind.meetingPoint,
                        child: Text('Buluşma noktası'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setModal(() => kind = value);
                    },
                    decoration: const InputDecoration(labelText: 'Tür'),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${scheduled.day}.${scheduled.month}.${scheduled.year}  ${scheduled.hour.toString().padLeft(2, '0')}:${scheduled.minute.toString().padLeft(2, '0')}',
                    ),
                    trailing: const Icon(Icons.event),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 60)),
                        initialDate: scheduled,
                      );
                      if (date == null || !context.mounted) return;
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(scheduled),
                      );
                      if (time == null) return;
                      setModal(() {
                        scheduled = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          time.hour,
                          time.minute,
                        );
                      });
                    },
                  ),
                  TextField(
                    controller: note,
                    decoration: const InputDecoration(labelText: 'Not'),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Gönder'),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
    if (confirmed != true) return;
    await VehicleService.instance.appointments.create(
      listingId: listing.id,
      sellerId: listing.sellerId,
      kind: kind,
      scheduledAt: scheduled,
      note: note.text.trim().isEmpty ? null : note.text.trim(),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Randevu gönderildi')));
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Randevu gönderilemedi: $error')));
    }
  } finally {
    note.dispose();
  }
}

Future<void> showVehicleQuoteSheet(
  BuildContext context,
  VehicleListing listing,
) async {
  final amount = TextEditingController();
  try {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Teklif Ver',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Teklif (₺)',
                  prefixText: '₺ ',
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Gönder'),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (confirmed != true) return;
    final parsed = double.tryParse(
      amount.text.replaceAll('.', '').replaceAll(',', '.'),
    );
    if (parsed == null || parsed <= 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Geçerli bir tutar girin')),
        );
      }
      return;
    }
    await VehicleService.instance.quotes.submit(
      listingId: listing.id,
      sellerId: listing.sellerId,
      amount: parsed,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Teklif gönderildi')));
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Teklif gönderilemedi: $error')));
    }
  } finally {
    amount.dispose();
  }
}
