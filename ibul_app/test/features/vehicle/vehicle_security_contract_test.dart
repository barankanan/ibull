import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/home_quick_action.dart';
import 'package:ibul_app/features/seller/panel/helpers/seller_panel_module_helpers.dart';
import 'package:ibul_app/features/seller/panel/models/seller_panel_types.dart';
import 'package:ibul_app/features/vehicle/data/vehicle_listing_repository.dart';

void main() {
  test('Araç shortcut is registered without replacing existing chips', () {
    final action = HomeQuickActionRegistry.fromHomeShortcutTitle('Araç');
    expect(action, isNotNull);
    expect(action!.type, HomeQuickActionType.vehicle);
    expect(
      HomeQuickActionRegistry.fromHomeShortcutTitle('Elektronik'),
      isNotNull,
    );
  });

  test('gallery sellers see Araçlar module, food sellers do not', () {
    expect(visibleSellerModules('Galerici'), contains(SellerModule.vehicles));
    expect(
      visibleSellerModules('Yemek'),
      isNot(contains(SellerModule.vehicles)),
    );
    expect(sellerModuleLabel(SellerModule.vehicles), 'Araçlar');
  });

  test('vehicle SQL keeps reservations insert-blocked', () {
    final rls = File(
      'supabase/migrations/20260902_vehicle_gallery_rls.sql',
    ).readAsStringSync();
    expect(rls, contains('vehicle_reservations_no_client_insert'));
    expect(rls, contains('vehicle_kyc_owner_select'));
    final kycPolicy = rls
        .split('vehicle_kyc_owner_select')
        .last
        .split('vehicle_kyc_owner_insert')
        .first;
    expect(kycPolicy, contains('customer_id'));
    expect(kycPolicy, contains('vehicle_is_admin'));
    expect(kycPolicy, isNot(contains('seller_id')));
  });

  test('public listing select stays status-gated in RLS', () {
    final rls = File(
      'supabase/migrations/20260902_vehicle_gallery_rls.sql',
    ).readAsStringSync();
    expect(rls, contains("status in ('active', 'reserved', 'rented')"));
    expect(rls, contains('vehicle_is_admin()'));
    expect(
      rls,
      contains(
        'grant execute on function public.vehicle_is_admin() to anon, authenticated',
      ),
    );
    final grant = File(
      'supabase/migrations/20260911_vehicle_is_admin_anon_execute.sql',
    ).readAsStringSync();
    expect(grant, contains('to anon, authenticated'));
  });

  test(
    'gallery photos do not use product-video StorageUploadService jpeg-name gate',
    () {
      final session = File(
        'lib/features/vehicle/screens/wizard/vehicle_wizard_session.dart',
      ).readAsStringSync();
      expect(session, isNot(contains('StorageUploadService')));
      expect(session, contains('VehicleImageUpload'));
      expect(session, contains('uploadBytes'));
      expect(session, contains('submitForReview'));
      final upload = File(
        'lib/services/media/storage_upload_service.dart',
      ).readAsStringSync();
      expect(upload, contains("name.endsWith('.jpg')"));
    },
  );

  test('publish RPC rejects empty specs and missing photos', () {
    final ops = File(
      'supabase/migrations/20260910_publish_vehicle_listing_guard.sql',
    ).readAsStringSync();
    expect(ops, contains('publish_vehicle_listing'));
    expect(ops, contains('specs_required'));
    expect(ops, contains('photos_required'));
    expect(ops, contains("nullif(trim(coalesce(v_spec.brand, '')), '')"));
    expect(ops, contains('v_listing.seller_id <> v_uid'));
  });

  test(
    'later moderation migration submits for review instead of publishing',
    () {
      final ops = File(
        'supabase/migrations/20260910_vehicle_listing_moderation.sql',
      ).readAsStringSync();
      expect(ops, contains('submit_vehicle_listing_for_review'));
      expect(ops, contains("status = 'pending_review'"));
      expect(ops, contains('moderate_vehicle_listing'));
      expect(ops, contains('seller_cannot_publish'));
      expect(ops, contains('return public.submit_vehicle_listing_for_review'));
      final submit = File(
        'supabase/migrations/20260911_vehicle_listing_submit_state.sql',
      ).readAsStringSync();
      expect(submit, contains('already_published'));
      expect(submit, contains("'status', 'pending_review'"));
      expect(submit, isNot(contains("'status', 'active'")));
      final approve = File(
        'supabase/migrations/20260912_vehicle_moderate_clear_rejection.sql',
      ).readAsStringSync();
      expect(approve, contains("- 'rejection_reason'"));
      expect(approve, contains("status = 'active'"));
      expect(approve, contains("'status', 'approved'"));
      final latest = File(
        'supabase/migrations/20260913_vehicle_admin_pending_public.sql',
      ).readAsStringSync();
      expect(
        latest,
        contains('return public.submit_vehicle_listing_for_review'),
      );
      expect(latest, contains('admin_list_vehicle_listings'));
      expect(latest, contains('seller_cannot_publish'));
      expect(latest, contains('or public.vehicle_is_admin()'));
      final adminUi = File(
        'lib/screens/admin/vehicle_listing_approval_page.dart',
      ).readAsStringSync();
      expect(adminUi, contains("'pending_review' => 'pending_review'"));
      expect(adminUi, contains("'approved' => 'active'"));
      expect(
        File('lib/screens/business_detail_page.dart').readAsStringSync(),
        contains('StorefrontVehicleGrid'),
      );
      expect(
        File('lib/screens/business_detail_page.dart').readAsStringSync(),
        contains('_storefrontCopy.catalogTab'),
      );
      expect(
        File('lib/screens/map_page.dart').readAsStringSync(),
        contains('PublicGalleryStoreView'),
      );
      expect(
        File(
          'lib/features/seller/storefront/storefront_copy.dart',
        ).readAsStringSync(),
        contains('Tüm Araçlar'),
      );
      expect(
        File(
          'lib/features/vehicle/screens/vehicle_gallery_page.dart',
        ).readAsStringSync(),
        contains('PublicGalleryStoreView'),
      );
    },
  );

  test('handover RPC hashes the code and does not store plaintext', () {
    final ops = File(
      'supabase/migrations/20260902_vehicle_gallery_ops_rpc.sql',
    ).readAsStringSync();
    expect(ops, contains('complete_vehicle_handover'));
    expect(ops, contains("digest(trim(coalesce(p_code, '')), 'sha256')"));
    expect(ops, isNot(contains('handover_code_hint')));
    expect(ops, contains('confirm_vehicle_rental_payment'));
  });

  test('create reservation checks overlap server-side', () {
    final rpc = File(
      'supabase/migrations/20260902_vehicle_gallery_rpc.sql',
    ).readAsStringSync();
    expect(rpc, contains('create_vehicle_rental_reservation'));
    expect(rpc, contains('tstzrange'));
    expect(rpc, contains('not_available'));
    expect(rpc, contains('quote_vehicle_delivery_fee'));
  });

  test('vehicle queries do not select missing stores brand-badge columns', () {
    final repo = File(
      'lib/features/vehicle/data/vehicle_listing_repository.dart',
    ).readAsStringSync();
    final galleryRepo = File(
      'lib/features/vehicle/data/vehicle_gallery_repository.dart',
    ).readAsStringSync();
    expect(VehicleListingRepository.listingSelect, contains('vehicle_specs'));
    expect(VehicleListingRepository.listingSelect, contains('vehicle_media'));
    expect(VehicleListingRepository.listingSelect, isNot(contains('stores')));
    expect(VehicleGalleryRepository.storeSelect, contains('is_verified'));
    expect(
      VehicleGalleryRepository.storeSelect,
      isNot(contains('is_brand_verified')),
    );
    expect(repo, isNot(contains('is_brand_verified')));
    expect(galleryRepo, isNot(contains('is_brand_verified')));
    expect(repo, contains('isLivePublished'));
    final setup = File('../SUPABASE_SETUP.sql').readAsStringSync();
    expect(setup, contains('is_verified boolean'));
    expect(setup, isNot(contains('is_brand_verified')));
    final schema = File(
      'supabase/migrations/20260902_vehicle_gallery_schema.sql',
    ).readAsStringSync();
    for (final column in [
      'sale_price',
      'home_delivery_sale',
      'cover_url',
      'ai_payload',
      'published_at',
      'favorite_count',
      'view_count',
    ]) {
      expect(schema, contains(column));
      expect(VehicleListingRepository.listingSelect, contains(column));
    }
  });

  test('wizard blocks empty-form overwrite and shows retry copy', () {
    final page = File(
      'lib/features/vehicle/screens/vehicle_add_wizard_page.dart',
    ).readAsStringSync();
    expect(page, contains('_hydrationCompleted'));
    expect(page, contains('_canMutate'));
    expect(page, contains('VehicleWizardLoadError'));
    final session = File(
      'lib/features/vehicle/screens/wizard/vehicle_wizard_session.dart',
    ).readAsStringSync();
    expect(session, contains('hydrationCompleted'));
    expect(session, contains('assertCanPersist'));
    expect(session, contains('getForEdit'));
    final shell = File(
      'lib/features/vehicle/screens/wizard/vehicle_wizard_shell.dart',
    ).readAsStringSync();
    expect(
      shell,
      contains('İlan bilgileri yüklenemedi. Lütfen tekrar deneyin.'),
    );
    expect(shell, contains('IbulPageState.error'));
  });

  test('wizard UI submits for review and keeps live preview', () {
    final page = File(
      'lib/features/vehicle/screens/vehicle_add_wizard_page.dart',
    ).readAsStringSync();
    expect(page, contains('Onaya Gönder'));
    expect(page, contains('VehicleEditorSidePanel'));
    expect(page, contains('_openPreview'));
    expect(page, contains('previewMode: true'));
    expect(page, contains('VehicleListingDetailView'));
    expect(page, isNot(contains('İlanınız yayınlandı')));
    expect(page, contains("'İlan'"));
    expect(page, contains("'Fotoğraflar'"));
    final shell = File(
      'lib/features/vehicle/screens/wizard/vehicle_wizard_shell.dart',
    ).readAsStringSync();
    expect(shell, contains('Yeni Araç İlanı'));
    expect(shell, contains('İlanı Düzenle'));
    expect(shell, contains('İlanınız incelemeye gönderildi'));
    expect(shell, contains('Onay Bekliyor'));
    final admin = File(
      'lib/screens/admin/vehicle_listing_approval_page.dart',
    ).readAsStringSync();
    expect(admin, contains('Araç İlanları'));
    expect(admin, contains('ONAYLA'));
  });

  test('rental flow never stubs payment capture', () {
    final flow = File(
      'lib/features/vehicle/screens/vehicle_rental_flow_page.dart',
    ).readAsStringSync();
    expect(flow, contains('submitForReview'));
    expect(flow, isNot(contains('confirmPayment(')));
    expect(flow, isNot(contains('assertDurationAllowed')));
    expect(flow, contains('VehicleRentalPaymentStep'));
    expect(flow, isNot(contains('cardHolder')));
    expect(flow, isNot(contains('Kart numarası')));
    expect(flow, isNot(contains('_cardCvv')));
    expect(flow, contains('_pin!.latitude'));
    expect(flow, isNot(contains('_pin?.latitude ?? _listing')));
    expect(flow, contains('sanitizeForUi'));
    expect(flow, contains('_discardStalePin'));
    final confirm = File(
      'lib/features/vehicle/data/vehicle_commerce_repository.dart',
    ).readAsStringSync();
    expect(confirm, contains('payment_provider_required'));
    expect(confirm, contains("orderId == null || orderId.trim().isEmpty"));
    expect(confirm, contains("cacheControl: 'private, max-age=0'"));
  });

  test('rental SQL keeps overlap + private docs + seller kyc scoped', () {
    final ops = File(
      'supabase/migrations/20260914_vehicle_rental_ops.sql',
    ).readAsStringSync();
    expect(ops, contains('vehicle_rental_blocks'));
    expect(ops, contains('vehicle_rental_refunds'));
    expect(ops, contains('vehicle_kyc_seller_select'));
    expect(ops, contains("bucket_id = 'vehicle-documents'"));
    final rpc = File(
      'supabase/migrations/20260914_vehicle_rental_rpcs.sql',
    ).readAsStringSync();
    expect(rpc, contains('vehicle_rental_window_blocked'));
    expect(rpc, contains('not_available'));
    expect(rpc, contains('pending_seller_review'));
    expect(rpc, contains('reason_required'));
    final pay = File(
      'supabase/migrations/20260914_vehicle_rental_payment.sql',
    ).readAsStringSync();
    expect(pay, contains('payment_provider_required'));
    expect(rpc, contains('IBR-'));
  });

  test('delivery quote distinguishes missing coords from out of zone', () {
    final sql = File(
      'supabase/migrations/20260914_vehicle_delivery_zone_quote.sql',
    ).readAsStringSync();
    expect(sql, contains('location_required'));
    expect(sql, contains('delivery_zone_missing'));
    expect(sql, contains('out_of_zone'));
    expect(sql, contains('gallery_location_missing'));
    expect(sql, contains("'Adrese teslim', 0, 50, 0, false"));
  });

  test('web vehicle detail hides sticky contact bar', () {
    final page = File(
      'lib/features/vehicle/screens/vehicle_detail_page.dart',
    ).readAsStringSync();
    expect(page, contains('width > 1100'));
    expect(page, contains('bottomNavigationBar: isWide'));
    expect(page, contains('? null'));
    expect(page, contains('WebHeader'));
  });
}
