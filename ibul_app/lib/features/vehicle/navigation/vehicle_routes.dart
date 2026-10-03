import 'package:flutter/material.dart';

import '../../../app/ibul_router.dart';
import '../../../app/marketplace_paths.dart';

import '../models/vehicle_commerce.dart';
import '../screens/vehicle_add_wizard_page.dart' deferred as vehicle_wizard;
import '../screens/vehicle_chat_page.dart' deferred as vehicle_chat;
import '../screens/vehicle_compare_page.dart' deferred as vehicle_compare;
import '../screens/vehicle_detail_page.dart' deferred as vehicle_detail;
import '../screens/vehicle_gallery_page.dart' deferred as vehicle_gallery;
import '../screens/vehicle_hub_page.dart' deferred as vehicle_hub;
import '../screens/vehicle_rental_flow_page.dart' deferred as vehicle_rental;
import '../screens/vehicle_search_page.dart' deferred as vehicle_search;

/// Navigation helpers. Page libraries stay deferred so the home rail does not
/// compile gallery, rental, or seller graphs on first paint.
abstract final class VehicleRoutes {
  static const hub = '/arac';
  static const search = '/arac/arama';

  static Future<void> openHub(BuildContext context) async {
    if (IbulRouter.usesRootRouter) {
      await IbulRouter.push(context, hub);
      return;
    }
    await vehicle_hub.loadLibrary();
    if (!context.mounted) return;
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(builder: (_) => vehicle_hub.VehicleHubPage()),
    );
  }

  static Future<void> openSearch(
    BuildContext context, {
    VehicleSearchQuery? query,
  }) async {
    await vehicle_search.loadLibrary();
    if (!context.mounted) return;
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => vehicle_search.VehicleSearchPage(initial: query),
      ),
    );
  }

  static Future<void> openDetail(
    BuildContext context,
    String listingId, {
    bool preview = false,
    String? slug,
    bool focusContact = false,
  }) async {
    if (preview) {
      await vehicle_detail.loadLibrary();
      if (!context.mounted) return;
      await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(
          builder: (_) => vehicle_detail.VehicleDetailPage(
            listingId: listingId,
            previewMode: true,
            focusContact: focusContact,
          ),
        ),
      );
      return;
    }
    if (IbulRouter.usesRootRouter) {
      final path = MarketplacePaths.vehicle(listingId, slug: slug);
      await IbulRouter.push(context, focusContact ? '$path?iletisim=1' : path);
      return;
    }
    await vehicle_detail.loadLibrary();
    if (!context.mounted) return;
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => vehicle_detail.VehicleDetailPage(
          listingId: listingId,
          focusContact: focusContact,
        ),
      ),
    );
  }

  static Future<void> openCompare(BuildContext context) async {
    await vehicle_compare.loadLibrary();
    if (!context.mounted) return;
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => vehicle_compare.VehicleComparePage(),
      ),
    );
  }

  static Future<void> openGallery(BuildContext context, String sellerId) async {
    await vehicle_gallery.loadLibrary();
    if (!context.mounted) return;
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => vehicle_gallery.VehicleGalleryPage(sellerId: sellerId),
      ),
    );
  }

  static Future<void> openMap(BuildContext context) async {
    await vehicle_gallery.loadLibrary();
    if (!context.mounted) return;
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(builder: (_) => vehicle_gallery.VehicleMapPage()),
    );
  }

  static Future<bool?> openWizard(
    BuildContext context, {
    String? listingId,
  }) async {
    await vehicle_wizard.loadLibrary();
    if (!context.mounted) return null;
    return Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            vehicle_wizard.VehicleAddWizardPage(listingId: listingId),
      ),
    );
  }

  static Future<void> openRental(
    BuildContext context, {
    required String listingId,
  }) async {
    await vehicle_rental.loadLibrary();
    if (!context.mounted) return;
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            vehicle_rental.VehicleRentalFlowPage(listingId: listingId),
      ),
    );
  }

  static Future<void> openChat(
    BuildContext context, {
    required String listingId,
    required String sellerId,
    required String sellerName,
  }) async {
    await vehicle_chat.loadLibrary();
    if (!context.mounted) return;
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => vehicle_chat.VehicleChatPage(
          listingId: listingId,
          sellerId: sellerId,
          sellerName: sellerName,
        ),
      ),
    );
  }
}
