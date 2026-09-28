import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/vehicle_commerce_repository.dart';
import '../data/vehicle_listing_repository.dart';
import '../data/vehicle_support_repository.dart';
import '../models/vehicle_listing.dart';

/// Phone channel is abstracted so in-app calling can replace tel: later.
abstract class VehicleContactChannel {
  Future<bool> callPhone(String phone);
}

class UrlLauncherVehicleContact implements VehicleContactChannel {
  const UrlLauncherVehicleContact();

  @override
  Future<bool> callPhone(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.isEmpty) return false;
    final uri = Uri(scheme: 'tel', path: cleaned);
    return launchUrl(uri);
  }
}

class VehicleService {
  VehicleService({
    VehicleListingRepository? listings,
    VehicleGalleryRepository? galleries,
    VehicleReservationRepository? reservations,
    VehicleQuoteRepository? quotes,
    VehicleAppointmentRepository? appointments,
    VehicleChatRepository? chats,
    VehicleFavoriteRepository? favorites,
    VehicleOperationsRepository? operations,
    VehicleMediaRepository? media,
    VehicleContactChannel? contact,
  }) : listings = listings ?? VehicleListingRepository(),
       galleries = galleries ?? VehicleGalleryRepository(),
       reservations = reservations ?? VehicleReservationRepository(),
       quotes = quotes ?? VehicleQuoteRepository(),
       appointments = appointments ?? VehicleAppointmentRepository(),
       chats = chats ?? VehicleChatRepository(),
       favorites = favorites ?? VehicleFavoriteRepository(),
       operations = operations ?? VehicleOperationsRepository(),
       media = media ?? VehicleMediaRepository(),
       contact = contact ?? const UrlLauncherVehicleContact();

  final VehicleListingRepository listings;
  final VehicleGalleryRepository galleries;
  final VehicleReservationRepository reservations;
  final VehicleQuoteRepository quotes;
  final VehicleAppointmentRepository appointments;
  final VehicleChatRepository chats;
  final VehicleFavoriteRepository favorites;
  final VehicleOperationsRepository operations;
  final VehicleMediaRepository media;
  final VehicleContactChannel contact;

  static final VehicleService instance = VehicleService();

  Future<bool> callGallery(VehicleListing listing) async {
    final phone = listing.gallery?.phone;
    if (phone == null || phone.trim().isEmpty) return false;
    try {
      await listings.recordEvent(listing, 'phone_click');
    } catch (error) {
      debugPrint('[vehicle] phone analytics skipped: $error');
    }
    return contact.callPhone(phone);
  }
}
