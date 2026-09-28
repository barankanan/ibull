import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/vehicle_listing_repository.dart';
import '../../domain/vehicle_image_upload.dart';
import '../../models/vehicle_enums.dart';
import '../../models/vehicle_listing.dart';
import '../../models/vehicle_wizard_draft.dart';
import '../../services/vehicle_service.dart';

class VehicleWizardSession {
  VehicleWizardSession({this.listingId, this.sellerId});

  final draft = VehicleWizardDraft();
  final photos = <VehicleDraftPhoto>[];
  String? listingId;
  String? sellerId;
  VehicleGallerySummary? gallery;
  DateTime? lastSavedAt;
  bool hydrationCompleted = false;

  int get readyPhotoCount => photos.where((p) => p.ready).length;

  void assertCanPersist() {
    if (listingId != null && !hydrationCompleted) {
      throw VehicleRepositoryException(
        'İlan bilgileri yüklenemedi. Lütfen tekrar deneyin.',
        code: 'hydration_incomplete',
      );
    }
  }

  Future<void> persist({
    required String title,
    required String description,
  }) async {
    assertCanPersist();
    draft.title = title.trim().isEmpty ? draft.displayTitle : title.trim();
    draft.description = description.trim();
    await ensureDraft();
    final id = listingId!;
    try {
      final latest = await VehicleService.instance.listings.getById(
        id,
        includeGallery: false,
      );
      if (latest != null) {
        draft.publishStatus = latest.status;
        draft.sourceExtras = Map<String, dynamic>.from(latest.extras);
      }
    } catch (error, stack) {
      debugPrint(
        '[VehicleListing][saveDraft] latest status refresh skipped: $error\n$stack',
      );
    }
    debugPrint(
      '[VehicleListing][saveDraft] listingId=$id sellerId=$sellerId '
      'status=${draft.publishStatus.wire}',
    );
    await VehicleService.instance.listings.upsertSpecs(id, draft.toSpecs());
    final cover =
        photos
            .where((p) => p.isCover && p.ready)
            .map((p) => p.url)
            .firstOrNull ??
        photos.where((p) => p.ready).map((p) => p.url).firstOrNull;
    final patch = <String, dynamic>{
      'listing_type': draft.listingType.wire,
      'sale_price': draft.salePrice,
      'negotiable': draft.negotiable,
      'financing': draft.financing,
      'trade_in': draft.tradeIn,
      'description': draft.description,
      'city': draft.city,
      'district': draft.district,
      'ai_payload': draft.toExtras(),
    };
    if (cover != null && cover.isNotEmpty) {
      patch['cover_url'] = cover;
    }
    await VehicleService.instance.listings.updateListing(id, patch);
    final rental = draft.rental;
    if (rental != null && sellerId != null && draft.listingType.allowsRental) {
      await VehicleService.instance.listings.upsertRental(
        id,
        sellerId!,
        rental,
      );
    }
    if (sellerId != null) {
      try {
        await VehicleService.instance.operations.replaceDamageRecords(
          listingId: id,
          sellerId: sellerId!,
          parts: draft.damageParts,
        );
      } catch (error, stack) {
        debugPrint(
          '[VehicleListing][saveDraft] damage skipped: $error\n$stack',
        );
      }
    }
    await _verifyPersisted(id);
  }

  Future<void> _verifyPersisted(String id) async {
    final saved = await VehicleService.instance.listings.getById(id);
    if (saved == null) {
      debugPrint(
        '[VehicleListing][saveDraft] listingId=$id result=failed code=not_found',
      );
      throw VehicleRepositoryException(
        'Taslak kaydedilemedi.',
        code: 'not_found',
      );
    }
    draft.publishStatus = saved.status;
    draft.sourceExtras = Map<String, dynamic>.from(saved.extras);
    lastSavedAt = DateTime.now();
    final brandOk =
        draft.brand.trim().isEmpty ||
        saved.specs.brand.trim() == draft.brand.trim();
    final modelOk =
        draft.model.trim().isEmpty ||
        saved.specs.model.trim() == draft.model.trim();
    final titleOk =
        draft.displayTitle.trim().isEmpty ||
        saved.title.trim() == draft.displayTitle.trim() ||
        (saved.extras['title']?.toString().trim() == draft.displayTitle.trim());
    final priceOk =
        draft.salePrice == null ||
        (saved.salePrice != null &&
            (saved.salePrice! - draft.salePrice!).abs() < 1);
    if (!brandOk || !modelOk || !titleOk || !priceOk) {
      debugPrint(
        '[VehicleListing][saveDraft] listingId=$id result=failed '
        'code=state_drift brand=${saved.specs.brand}/${draft.brand} '
        'model=${saved.specs.model}/${draft.model} '
        'title=${saved.title}/${draft.displayTitle} '
        'price=${saved.salePrice}/${draft.salePrice}',
      );
      throw VehicleRepositoryException(
        'Taslak kaydedilemedi.',
        code: 'state_drift',
      );
    }
    debugPrint(
      '[VehicleListing][saveDraft] listingId=$id status=${saved.status.wire} '
      'result=success photos=${saved.media.length}',
    );
  }

  Future<void> ensureDraft() async {
    if (listingId != null) return;
    if (sellerId == null) {
      throw VehicleRepositoryException(
        'Satıcı oturumu gerekli',
        code: 'auth_required',
      );
    }
    listingId = await VehicleService.instance.listings.createDraft(
      sellerId: sellerId!,
      type: draft.listingType,
      specs: draft.toSpecs(),
      extras: draft.toExtras(),
    );
    draft.publishStatus = VehicleListingStatus.draft;
    debugPrint(
      '[VehicleListing][saveDraft] created vehicleId=$listingId sellerId=$sellerId',
    );
  }

  Future<void> loadExisting() async {
    hydrationCompleted = listingId == null;
    if (sellerId != null) {
      try {
        gallery = await VehicleService.instance.galleries.getBySellerId(
          sellerId!,
        );
        draft.city ??= gallery?.city;
        draft.district ??= gallery?.district;
      } catch (error, stack) {
        debugPrint('[vehicle] gallery enrichment skipped: $error\n$stack');
      }
    }
    if (listingId == null) {
      hydrationCompleted = true;
      return;
    }
    final listing = await VehicleService.instance.listings.getForEdit(
      listingId!,
    );
    if (listing == null) {
      throw VehicleRepositoryException('İlan bulunamadı.', code: 'not_found');
    }
    draft.applyListing(listing);
    lastSavedAt = listing.createdAt;
    photos
      ..clear()
      ..addAll(
        listing.media.map(
          (m) => VehicleDraftPhoto(
            localId: m.id,
            id: m.id,
            url: m.url,
            objectPath: m.objectPath,
            isCover: m.isCover || m.url == listing.coverUrl,
            sortOrder: m.sortOrder,
          ),
        ),
      );
    if (photos.isNotEmpty && !photos.any((p) => p.isCover)) {
      photos.first.isCover = true;
    }
    hydrationCompleted = true;
  }

  Future<void> upload(XFile file) async {
    await ensureDraft();
    if (sellerId == null || listingId == null) {
      debugPrint(
        '[VehicleListing][saveDraft] upload missing_ids '
        'sellerId=$sellerId vehicleId=$listingId',
      );
      return;
    }
    final photo = VehicleDraftPhoto(
      localId: '${DateTime.now().microsecondsSinceEpoch}',
      uploading: true,
      isCover: photos.isEmpty,
      sortOrder: photos.length,
    );
    photos.add(photo);
    try {
      final bytes = await file.readAsBytes();
      photo.previewBytes = bytes;
      if (bytes.isEmpty) {
        throw VehicleRepositoryException(
          'Dosya boş görünüyor.',
          code: 'empty_file',
        );
      }
      final contentType = VehicleImageUpload.contentTypeFor(
        fileName: file.name,
        bytes: bytes,
        mimeType: file.mimeType,
      );
      final path = VehicleImageUpload.objectPath(
        sellerId: sellerId!,
        listingId: listingId!,
        fileId: photo.localId,
        extension: VehicleImageUpload.extensionFor(contentType),
      );
      final uploaded = await VehicleService.instance.media.uploadBytes(
        bytes: bytes,
        objectPath: path,
        contentType: contentType,
        sellerId: sellerId!,
        listingId: listingId!,
        fileName: file.name,
      );
      final mediaId = await VehicleService.instance.media.attach(
        listingId: listingId!,
        sellerId: sellerId!,
        slot: VehicleMediaSlot.other,
        objectPath: uploaded.path,
        url: uploaded.publicUrl,
        isCover: photo.isCover,
        sortOrder: photo.sortOrder,
      );
      photo
        ..id = mediaId
        ..url = uploaded.publicUrl
        ..objectPath = uploaded.path
        ..uploading = false
        ..failed = false;
    } catch (error, stack) {
      debugPrint('[vehicle] photo upload failed: $error\n$stack');
      photo.uploading = false;
      photo.failed = true;
      photo.error = error.toString();
    }
  }

  Future<void> deletePhoto(VehicleDraftPhoto photo) async {
    if (photo.id != null) {
      try {
        await VehicleService.instance.media.detach(
          mediaId: photo.id!,
          objectPath: photo.objectPath,
        );
      } catch (error, stack) {
        debugPrint('[vehicle] photo detach failed: $error\n$stack');
      }
    }
    photos.remove(photo);
    if (photo.isCover && photos.isNotEmpty) {
      await setCover(photos.first);
    }
  }

  Future<void> setCover(VehicleDraftPhoto photo) async {
    for (final item in photos) {
      item.isCover = item.localId == photo.localId;
    }
    if (!photo.ready || photo.id == null || listingId == null) return;
    await VehicleService.instance.media.setCover(
      listingId: listingId!,
      mediaId: photo.id!,
      url: photo.url!,
    );
  }

  Future<void> movePhoto(int from, int to) async {
    if (to < 0 || to >= photos.length) return;
    final item = photos.removeAt(from);
    photos.insert(to, item);
    for (var i = 0; i < photos.length; i++) {
      photos[i].sortOrder = i;
      if (photos[i].id == null) continue;
      try {
        await VehicleService.instance.media.updateSortOrder(
          mediaId: photos[i].id!,
          sortOrder: photos[i].sortOrder,
        );
      } catch (error) {
        debugPrint('[vehicle] sort update skipped: $error');
      }
    }
  }

  Future<void> publish() async {
    await submitForReview();
  }

  Future<void> submitForReview() async {
    assertCanPersist();
    await persist(title: draft.title, description: draft.description ?? '');
    await VehicleService.instance.listings.submitForReview(listingId!);
    draft.publishStatus = VehicleListingStatus.pendingReview;
  }
}
