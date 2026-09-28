import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/vehicle/data/vehicle_listing_repository.dart';
import 'package:ibul_app/features/vehicle/domain/vehicle_catalog.dart';
import 'package:ibul_app/features/vehicle/domain/vehicle_image_upload.dart';
import 'package:ibul_app/features/vehicle/domain/vehicle_listing_quality.dart';
import 'package:ibul_app/features/vehicle/domain/vehicle_listing_validation.dart';
import 'package:ibul_app/features/vehicle/domain/vehicle_state_machine.dart';
import 'package:ibul_app/features/vehicle/models/vehicle_enums.dart';
import 'package:ibul_app/features/vehicle/models/vehicle_listing.dart';
import 'package:ibul_app/features/vehicle/models/vehicle_wizard_draft.dart';
import 'package:ibul_app/features/vehicle/screens/wizard/vehicle_wizard_session.dart';
import 'package:ibul_app/features/vehicle/widgets/vehicle_listing_preview.dart';

void main() {
  group('VehicleCatalog', () {
    test('BMW models are filtered after brand selection', () {
      expect(VehicleCatalog.modelsFor(''), isEmpty);
      final models = VehicleCatalog.modelsFor('BMW');
      expect(models, contains('3 Serisi'));
      expect(models, contains('X5'));
      expect(
        VehicleCatalog.trimsFor('BMW', '3 Serisi'),
        contains('320i M Sport'),
      );
    });

    test('search is accent-insensitive', () {
      expect(VehicleCatalog.brands(query: 'togg'), contains('Togg'));
      expect(
        VehicleCatalog.modelsFor('Mercedes-Benz', query: 'glc'),
        contains('GLC'),
      );
    });

    test('years are dynamic and current-year based', () {
      expect(VehicleCatalog.years().first, DateTime.now().year + 1);
      expect(VehicleCatalog.years().last, VehicleCatalog.minYear);
    });
  });

  group('VehicleMoney', () {
    test('parses Turkish thousand separators', () {
      expect(VehicleMoney.parse('1.250.000'), 1250000);
      expect(VehicleMoney.parse('1250000 TL'), 1250000);
      expect(VehicleMoney.parse('1.250.000,50'), 1250000.5);
      expect(VehicleMoney.format(1250000), '1.250.000 TL');
    });
  });

  group('VehicleListingValidator', () {
    test('sale listings require price, brand, model and photos', () {
      final draft = VehicleWizardDraft();
      final issues = VehicleListingValidator.validatePublish(
        draft: draft,
        uploadedPhotoCount: 0,
      );
      expect(
        issues.map((e) => e.field),
        containsAll([
          'title',
          'description',
          'brand',
          'model',
          'salePrice',
          'photos',
        ]),
      );
      expect(issues.firstWhere((e) => e.field == 'title').step, 0);
      expect(issues.firstWhere((e) => e.field == 'salePrice').step, 4);
      expect(issues.firstWhere((e) => e.field == 'photos').step, 5);
    });

    test('draft step 0 does not require photos or price', () {
      final draft = VehicleWizardDraft()
        ..title = 'toyotta corolla 2021'
        ..description = 'Bakım geçmişi mevcut.';
      final issues = VehicleListingValidator.validateStep(
        0,
        draft: draft,
        uploadedPhotoCount: 0,
      );
      expect(issues.map((e) => e.field), isNot(contains('photos')));
      expect(issues.map((e) => e.field), isNot(contains('salePrice')));
    });

    test('preview listing uses in-memory draft and is not public', () {
      final draft = VehicleWizardDraft()
        ..title = 'toyotta corolla 2021'
        ..brand = 'Toyota'
        ..model = 'Corolla'
        ..year = 2021
        ..salePrice = 1200212
        ..mileageKm = 18000
        ..description = 'Hasarsız.';
      final preview = VehicleListingPreview.fromDraft(
        draft: draft,
        photos: const [],
        sellerId: 'seller-1',
        listingId: 'listing-1',
      );
      expect(preview.listing.status, VehicleListingStatus.draft);
      expect(preview.listing.status.isPubliclyVisible, isFalse);
      expect(preview.listing.title, 'toyotta corolla 2021');
      expect(preview.listing.salePrice, 1200212);
      expect(preview.listing.specs.mileageKm, 18000);
    });

    test('valid sale draft with photos passes', () {
      final draft = VehicleWizardDraft()
        ..brand = 'BMW'
        ..model = '3 Serisi'
        ..year = 2024
        ..mileageKm = 85000
        ..fuel = 'Benzin'
        ..transmission = 'Otomatik'
        ..salePrice = 1250000
        ..title = '2024 BMW 3 Serisi'
        ..description = 'Bakım geçmişi mevcut. Hasarsız, servis bakımlı araç.';
      expect(
        VehicleListingValidator.validatePublish(
          draft: draft,
          uploadedPhotoCount: 3,
        ),
        isEmpty,
      );
    });

    test('suggested title is generated from brand/model/year', () {
      final draft = VehicleWizardDraft()
        ..brand = 'BMW'
        ..model = '3 Serisi'
        ..version = '320i M Sport'
        ..year = 2024
        ..transmission = 'Otomatik'
        ..mileageKm = 12000;
      draft.applySuggestedTitleIfNeeded();
      expect(draft.title, contains('BMW'));
      expect(draft.title, contains('320i'));
      expect(draft.title.length, lessThanOrEqualTo(80));
    });
  });

  group('VehiclePublishErrorMapper', () {
    test('maps RPC codes to Turkish without exposing raw sql', () {
      expect(
        VehiclePublishErrorMapper.fromCode('sale_price_required'),
        contains('Satış fiyatı'),
      );
      expect(
        VehiclePublishErrorMapper.fromCode('specs_required'),
        contains('Marka'),
      );
      expect(
        VehiclePublishErrorMapper.fromCode('invalid_state'),
        contains('onaya gönderilemez'),
      );
      expect(
        VehiclePublishErrorMapper.fromCode('already_published'),
        contains('yayında'),
      );
      expect(
        VehiclePublishErrorMapper.fromObject(
          Exception('PGRST202 publish_vehicle_listing'),
        ),
        contains('Yayınlama servisi'),
      );
    });
  });

  group('VehicleStateMachine publish path', () {
    test('seller draft goes to pending_review, not active', () {
      expect(
        VehicleStateMachine.canTransitionListing(
          VehicleListingStatus.draft,
          VehicleListingStatus.pendingReview,
        ),
        isTrue,
      );
      expect(
        VehicleStateMachine.canTransitionListing(
          VehicleListingStatus.draft,
          VehicleListingStatus.active,
        ),
        isFalse,
      );
      expect(
        VehicleStateMachine.canTransitionListing(
          VehicleListingStatus.pendingReview,
          VehicleListingStatus.active,
        ),
        isTrue,
      );
      expect(
        VehicleStateMachine.canTransitionListing(
          VehicleListingStatus.active,
          VehicleListingStatus.inactive,
        ),
        isTrue,
      );
      expect(
        VehicleStateMachine.canTransitionListing(
          VehicleListingStatus.active,
          VehicleListingStatus.sold,
        ),
        isTrue,
      );
    });
  });

  group('VehicleImageUpload', () {
    test('png file names are accepted and not forced to jpeg', () {
      final png = Uint8List.fromList([
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
      ]);
      expect(
        VehicleImageUpload.contentTypeFor(
          fileName: 'screenshot.PNG',
          bytes: png,
        ),
        'image/png',
      );
      expect(VehicleImageUpload.extensionFor('image/png'), 'png');
    });

    test('storage path first folder is seller id for RLS', () {
      final path = VehicleImageUpload.objectPath(
        sellerId: 'seller-uid',
        listingId: 'listing-uid',
        fileId: '1',
        extension: 'jpg',
      );
      expect(path.startsWith('seller-uid/listing-uid/'), isTrue);
      expect(path.endsWith('.jpg'), isTrue);
    });
  });

  group('edit hydration and type config', () {
    test('fromMap unwraps vehicle_specs and media lists', () {
      final listing = VehicleListing.fromMap({
        'id': 'v1',
        'seller_id': 's1',
        'listing_type': 'sale',
        'status': 'draft',
        'description': 'Bakım geçmişi mevcut.',
        'sale_price': 1250000,
        'ai_payload': {
          'title': '2024 BMW 320i',
          'vehicle_class': 'automobile',
          'features': ['abs', 'esp'],
        },
        'vehicle_specs': [
          {
            'brand': 'BMW',
            'model': '3 Serisi',
            'year': 2024,
            'fuel': 'Benzin',
            'transmission': 'Otomatik',
            'mileage_km': 18000,
          },
        ],
        'vehicle_media': [
          {
            'id': 'm1',
            'slot': 'other',
            'url': 'https://cdn.example/a.jpg',
            'is_cover': true,
            'sort_order': 0,
          },
        ],
      });
      expect(listing.specs.brand, 'BMW');
      expect(listing.specs.model, '3 Serisi');
      expect(listing.media, isNotEmpty);
      expect(listing.media.first.url, contains('cdn.example'));
      final draft = VehicleWizardDraft()..applyListing(listing);
      expect(draft.brand, 'BMW');
      expect(draft.model, '3 Serisi');
      expect(draft.title, '2024 BMW 320i');
      expect(draft.description, 'Bakım geçmişi mevcut.');
      expect(draft.features, containsAll(['abs', 'esp']));
      expect(draft.mileageKm, 18000);
    });

    test('quality checks follow listing-first order', () {
      final checks = VehicleListingQuality.checks(
        draft: VehicleWizardDraft()
          ..title = '2024 BMW 3 Serisi'
          ..brand = 'BMW'
          ..model = '3 Serisi',
        photoCount: 1,
      );
      expect(checks.map((c) => c.id).toList(), [
        'title',
        'brand',
        'model',
        'photos',
        'description',
        'price',
      ]);
      expect(checks.first.done, isTrue);
      expect(checks.firstWhere((c) => c.id == 'photos').done, isFalse);
    });

    test('motorcycle and jetski hide car-only required fields', () {
      final moto = VehicleWizardDraft()
        ..vehicleClass = 'motorcycle'
        ..brand = 'Honda'
        ..model = 'CBR'
        ..year = 2024
        ..mileageKm = 4000
        ..fuel = 'Benzin'
        ..title = '2024 Honda CBR'
        ..description = 'Düzenli bakımlı motosiklet.';
      expect(
        VehicleListingValidator.validatePublish(
          draft: moto,
          uploadedPhotoCount: 3,
        ).map((e) => e.field),
        isNot(contains('transmission')),
      );
      expect(VehicleTypeConfig.of('jetski').shows('transmission'), isFalse);
      expect(VehicleTypeConfig.of('jetski').shows('hoursOperated'), isTrue);
      expect(VehicleTypeConfig.of('truck').shows('axles'), isTrue);
      expect(VehicleTypeConfig.of('caravan').shows('berths'), isTrue);
      expect(VehicleTypeConfig.of('automobile').shows('bodyType'), isTrue);
      expect(VehicleTypeConfig.of('motorcycle').hasDamagePanel, isFalse);
    });

    test('rejected extras stay visible to the seller', () {
      final listing = VehicleListing.fromMap({
        'id': 'v2',
        'seller_id': 's1',
        'listing_type': 'sale',
        'status': 'draft',
        'vehicle_specs': {'brand': 'Toyota', 'model': 'Corolla', 'year': 2021},
        'ai_payload': {
          'moderation': {'status': 'rejected', 'reason': 'Eksik fotoğraf'},
        },
      });
      expect(listing.isRejected, isTrue);
      expect(listing.statusLabelTr, 'Reddedildi');
      expect(listing.rejectionReason, 'Eksik fotoğraf');
      expect(listing.status.isPubliclyVisible, isFalse);
    });

    test('admin approve leftover rejection_reason does not hide Yayında', () {
      final listing = VehicleListing.fromMap({
        'id': 'v3',
        'seller_id': 's1',
        'listing_type': 'sale',
        'status': 'active',
        'published_at': '2026-09-12T00:00:00Z',
        'vehicle_specs': {'brand': 'Toyota', 'model': 'Corolla', 'year': 2021},
        'ai_payload': {
          'moderation': {'status': 'approved'},
          'rejection_reason': 'eski red notu',
        },
      });
      expect(listing.isRejected, isFalse);
      expect(listing.isLivePublished, isTrue);
      expect(listing.statusLabelTr, 'Yayında');
      expect(listing.status.isPubliclyVisible, isTrue);
    });

    test('pending review keeps seller label Onay bekliyor', () {
      final listing = VehicleListing.fromMap({
        'id': 'v4',
        'seller_id': 's1',
        'listing_type': 'sale',
        'status': 'pending_review',
        'vehicle_specs': {'brand': 'Toyota', 'model': 'Corolla', 'year': 2021},
        'ai_payload': {
          'moderation': {'status': 'pending'},
        },
      });
      expect(listing.isRejected, isFalse);
      expect(listing.isLivePublished, isFalse);
      expect(listing.statusLabelTr, 'Onay bekliyor');
    });

    test('toExtras does not drop moderation on save', () {
      final draft = VehicleWizardDraft()
        ..sourceExtras = {
          'moderation': {'status': 'rejected', 'reason': 'Yanlış bilgi'},
        };
      expect(draft.toExtras()['moderation']['reason'], 'Yanlış bilgi');
    });
  });

  group('VehicleWizardSession hydration guard', () {
    test('blocks persist when existing listing was not loaded', () {
      final session = VehicleWizardSession(listingId: 'listing-1');
      expect(session.hydrationCompleted, isFalse);
      expect(
        () => session.assertCanPersist(),
        throwsA(
          isA<VehicleRepositoryException>().having(
            (error) => error.code,
            'code',
            'hydration_incomplete',
          ),
        ),
      );
    });

    test('allows persist after create-mode hydration', () {
      final session = VehicleWizardSession();
      session.hydrationCompleted = true;
      expect(() => session.assertCanPersist(), returnsNormally);
    });
  });

  group('VehiclePublishErrorMapper load UX', () {
    test('hides PostgrestException from the user copy', () {
      final message = VehiclePublishErrorMapper.loadFailure(
        'PostgrestException: column stores.is_brand_verified does not exist',
      );
      expect(message, 'İlan bilgileri yüklenemedi. Lütfen tekrar deneyin.');
      expect(message, isNot(contains('PostgrestException')));
      expect(message, isNot(contains('is_brand_verified')));
      expect(
        VehiclePublishErrorMapper.fromObject(
          'PostgrestException code: 42703 column stores.is_brand_verified does not exist',
        ),
        'İlan bilgileri yüklenemedi. Lütfen tekrar deneyin.',
      );
    });
  });
}
