import '../domain/store_vertical.dart';
import '../panel/helpers/seller_panel_module_helpers.dart';
import '../panel/models/seller_panel_types.dart';
import '../../../models/sub_admin.dart';

/// Operational staff catalog. Legal `stores.business_type` is not used.
/// A category label becomes a staff kind only together with the modules that
/// vertical actually enables.
enum StaffBusinessKind { retail, restaurant, gallery, unknown }

const staffPermissionsStoredOnServer = <SellerPermission>{
  SellerPermission.manageProducts,
  SellerPermission.viewOrders,
  SellerPermission.manageOrders,
  SellerPermission.manageCampaigns,
  SellerPermission.viewFinance,
  SellerPermission.manageSupport,
  SellerPermission.manageStoreProfile,
  SellerPermission.takePartialPayment,
  SellerPermission.transferTable,
  SellerPermission.splitBill,
  SellerPermission.closeBill,
  SellerPermission.managePrintSettings,
  SellerPermission.manageTables,
  SellerPermission.manageStaff,
};

/// Operations a page's "Tam Erişim" writes into `permissions`.
/// `manageStoreProfile` stays out because it is owner-only.
/// `manageStaff` is not included in Tam Erişim; it is saved only when chosen.
Set<SellerPermission> pageFullAccessOperations(SellerModule module) {
  switch (module) {
    case SellerModule.garson:
      return const <SellerPermission>{
        SellerPermission.viewOrders,
        SellerPermission.manageOrders,
        SellerPermission.closeBill,
        SellerPermission.transferTable,
        SellerPermission.takePartialPayment,
      };
    case SellerModule.dashboard:
      return const <SellerPermission>{SellerPermission.viewOrders};
    case SellerModule.orders:
      return const <SellerPermission>{
        SellerPermission.viewOrders,
        SellerPermission.manageOrders,
      };
    case SellerModule.products:
    case SellerModule.collections:
      return const <SellerPermission>{SellerPermission.manageProducts};
    case SellerModule.finance:
      return const <SellerPermission>{SellerPermission.viewFinance};
    case SellerModule.campaigns:
      return const <SellerPermission>{SellerPermission.manageCampaigns};
    case SellerModule.support:
      return const <SellerPermission>{SellerPermission.manageSupport};
    case SellerModule.system:
      return const <SellerPermission>{
        SellerPermission.managePrintSettings,
        SellerPermission.manageTables,
      };
    case SellerModule.store:
    case SellerModule.team:
    case SellerModule.vehicles:
    case SellerModule.mallRequests:
    case SellerModule.contracts:
    case SellerModule.achievements:
    case SellerModule.reviews:
    case SellerModule.downloadApp:
      return const <SellerPermission>{};
  }
}

const restaurantFloorPermissions = <SellerPermission>{
  SellerPermission.transferTable,
  SellerPermission.splitBill,
  SellerPermission.takePartialPayment,
  SellerPermission.closeBill,
  SellerPermission.managePrintSettings,
  SellerPermission.manageTables,
};

bool staffPermissionPersists(SellerPermission permission) {
  return staffPermissionsStoredOnServer.contains(permission);
}

/// Garson carries the live four permissions plus an explicit table transfer.
/// Hesap kesme and personel yönetimi stay outside that ceiling.
const waiterPermissionCeiling = <SellerPermission>{
  SellerPermission.viewOrders,
  SellerPermission.manageOrders,
  SellerPermission.manageProducts,
  SellerPermission.manageSupport,
  SellerPermission.transferTable,
  SellerPermission.takePartialPayment,
};

Set<SellerPermission> staffStoredRoleCeiling(String? storedRole) {
  if (storedRole == 'waiter') return waiterPermissionCeiling;
  if (storedRole == 'sub_admin') {
    return SellerPermission.values.toSet().difference(ownerOnlyGrantPermissions);
  }
  return const <SellerPermission>{};
}

Set<SellerPermission> permissionsWithinRoleCeiling({
  required String? storedRole,
  required Iterable<SellerPermission> permissions,
}) {
  final ceiling = staffStoredRoleCeiling(storedRole);
  return permissions.where(ceiling.contains).toSet();
}

StaffBusinessKind resolveStaffBusinessKind({
  required String? category,
  required Set<SellerModule> enabledModules,
}) {
  final vertical = resolveStoreVertical(category);
  final restaurantEnabled =
      vertical == StoreVertical.restaurant &&
      enabledModules.contains(SellerModule.garson);
  final galleryEnabled =
      vertical == StoreVertical.gallery &&
      enabledModules.contains(SellerModule.vehicles);
  if (restaurantEnabled) return StaffBusinessKind.restaurant;
  if (galleryEnabled) return StaffBusinessKind.gallery;
  final label = (category ?? '').trim();
  if (label.isEmpty || vertical == StoreVertical.unknown) {
    return StaffBusinessKind.unknown;
  }
  if (enabledModules.contains(SellerModule.garson) ||
      enabledModules.contains(SellerModule.vehicles)) {
    return StaffBusinessKind.unknown;
  }
  return StaffBusinessKind.retail;
}

class StaffRoleTemplate {
  const StaffRoleTemplate({
    required this.id,
    required this.label,
    required this.storedRole,
    required this.description,
    required this.suggested,
  });

  final String id;
  final String label;
  final String storedRole;
  final String description;
  final Set<SellerPermission> suggested;
}

const _orderView = SellerPermission.viewOrders;
const _orderManage = SellerPermission.manageOrders;
const _products = SellerPermission.manageProducts;
const _campaigns = SellerPermission.manageCampaigns;
const _finance = SellerPermission.viewFinance;
const _support = SellerPermission.manageSupport;

List<StaffRoleTemplate> staffRoleTemplates(StaffBusinessKind kind) {
  switch (kind) {
    case StaffBusinessKind.restaurant:
      return const <StaffRoleTemplate>[
        StaffRoleTemplate(
          id: 'restaurant_manager',
          label: 'Restoran Müdürü',
          storedRole: 'sub_admin',
          description: 'Sipariş, ürün, kampanya, finans ve destek.',
          suggested: {
            _orderView,
            _orderManage,
            _products,
            _campaigns,
            _finance,
            _support,
          },
        ),
        StaffRoleTemplate(
          id: 'assistant_manager',
          label: 'Alt Yönetici',
          storedRole: 'sub_admin',
          description:
              'Sipariş, ürün ve destek. Masa aktarma, hesap kesme ve personel yetkisi ayrıdır.',
          suggested: {_orderView, _orderManage, _products, _support},
        ),
        StaffRoleTemplate(
          id: 'waiter',
          label: 'Garson',
          storedRole: 'waiter',
          description:
              'Sipariş görür, sipariş alır ve mutfak fişi gönderir. Hesap kesmez ve personel yönetmez.',
          suggested: {_orderView, _orderManage},
        ),
        StaffRoleTemplate(
          id: 'cashier',
          label: 'Kasiyer',
          storedRole: 'sub_admin',
          description: 'Sipariş görür. Hesap kesme ayrı bir yetkidir.',
          suggested: {_orderView},
        ),
        StaffRoleTemplate(
          id: 'order_owner',
          label: 'Sipariş Sorumlusu',
          storedRole: 'sub_admin',
          description: 'Sipariş görür ve yönetir. Hesap kesmez.',
          suggested: {_orderView, _orderManage},
        ),
        StaffRoleTemplate(
          id: 'custom',
          label: 'Özel Yetki',
          storedRole: 'sub_admin',
          description: 'İzinleri tek tek siz seçersiniz.',
          suggested: <SellerPermission>{},
        ),
      ];
    case StaffBusinessKind.gallery:
      return const <StaffRoleTemplate>[
        StaffRoleTemplate(
          id: 'gallery_manager',
          label: 'Galeri Müdürü',
          storedRole: 'sub_admin',
          description: 'Sipariş, ürün, finans ve destek.',
          suggested: {_orderView, _orderManage, _products, _finance, _support},
        ),
        StaffRoleTemplate(
          id: 'sales_advisor',
          label: 'Satış Danışmanı',
          storedRole: 'sub_admin',
          description: 'Sipariş görür ve yönetir.',
          suggested: {_orderView, _orderManage},
        ),
      ];
    case StaffBusinessKind.retail:
      return const <StaffRoleTemplate>[
        StaffRoleTemplate(
          id: 'store_manager',
          label: 'Mağaza Müdürü',
          storedRole: 'sub_admin',
          description: 'Sipariş, ürün, kampanya, finans ve destek.',
          suggested: {
            _orderView,
            _orderManage,
            _products,
            _campaigns,
            _finance,
            _support,
          },
        ),
        StaffRoleTemplate(
          id: 'assistant_manager',
          label: 'Müdür Yardımcısı',
          storedRole: 'sub_admin',
          description: 'Yalnızca işaretlenen izinler geçerlidir.',
          suggested: {_orderView, _orderManage, _products, _support},
        ),
        StaffRoleTemplate(
          id: 'sales',
          label: 'Satış Personeli',
          storedRole: 'sub_admin',
          description: 'Sipariş görür ve yönetir.',
          suggested: {_orderView, _orderManage},
        ),
        StaffRoleTemplate(
          id: 'stock',
          label: 'Ürün ve Stok Sorumlusu',
          storedRole: 'sub_admin',
          description: 'Ürün kayıtlarını yönetir.',
          suggested: {_products},
        ),
        StaffRoleTemplate(
          id: 'orders',
          label: 'Sipariş Sorumlusu',
          storedRole: 'sub_admin',
          description: 'Sipariş görür ve yönetir.',
          suggested: {_orderView, _orderManage},
        ),
        StaffRoleTemplate(
          id: 'support',
          label: 'Müşteri Destek Personeli',
          storedRole: 'sub_admin',
          description: 'Destek kayıtlarını ve siparişleri görür.',
          suggested: {_support, _orderView},
        ),
      ];
    case StaffBusinessKind.unknown:
      return const <StaffRoleTemplate>[];
  }
}

List<String> staffCapabilityGaps(StaffBusinessKind kind) {
  switch (kind) {
    case StaffBusinessKind.restaurant:
      return const <String>[
        'Ara ödeme garsona ayrıca işaretlenirse kaydedilir. Hesap kesme garson rolüne verilmez.',
        'Mutfak personeli için ayrı bir yetki yok. Mutfak fişi, sipariş yönetme yetkisiyle gider.',
      ];
    case StaffBusinessKind.gallery:
      return const <String>[
        'Kiralama ve araç ilanı için ayrı personel yetkisi yok. Araç modülü personel izniyle açılmıyor.',
      ];
    case StaffBusinessKind.retail:
      return const <String>[];
    case StaffBusinessKind.unknown:
      return const <String>[
        'İşletme türü belli değil. Personel hesabı oluşturulamaz.',
        'AVM rolleri için mağazadan ayrı, güvenilir bir AVM kaydı yok.',
      ];
  }
}

Set<SellerPermission> staffPermissionsForKind(StaffBusinessKind kind) {
  final shared = <SellerPermission>{
    SellerPermission.viewOrders,
    SellerPermission.manageOrders,
    SellerPermission.manageProducts,
    SellerPermission.manageCampaigns,
    SellerPermission.viewFinance,
    SellerPermission.manageSupport,
    SellerPermission.manageStaff,
  };
  if (kind == StaffBusinessKind.restaurant) {
    return {...shared, ...restaurantFloorPermissions};
  }
  if (kind == StaffBusinessKind.unknown) return const <SellerPermission>{};
  return shared;
}

List<SellerPermissionGroup> staffGroupsForBusiness({
  required StaffBusinessKind kind,
  required bool isOwner,
  required Set<String> held,
}) {
  final ceiling = staffGrantCeiling(isOwner: isOwner, held: held);
  final visible = staffPermissionsForKind(kind);
  return <SellerPermissionGroup>[
    for (final group in sellerPermissionGroups)
      if (group.permissions.any(
        (permission) => ceiling.contains(permission) && visible.contains(permission),
      ))
        SellerPermissionGroup(
          group.title,
          group.permissions
              .where(
                (permission) =>
                    ceiling.contains(permission) && visible.contains(permission),
              )
              .toList(growable: false),
        ),
  ];
}

/// The title is a label. The stored role is the smallest ceiling that can
/// hold the grants. A restaurant grant set inside the waiter ceiling is
/// `waiter`. Anything wider, and every non-restaurant account, is `sub_admin`.
/// An existing wider role stays until the grants themselves fit the narrower
/// ceiling. The typed title is not an input.
String securityRoleForStaffGrants({
  required StaffBusinessKind kind,
  required Set<SellerPermission> grants,
  String? existingRole,
}) {
  final food = kind == StaffBusinessKind.restaurant;
  final fitsWaiter = grants.isNotEmpty &&
      grants.every(waiterPermissionCeiling.contains);
  if (!food) return 'sub_admin';
  if (existingRole == 'waiter' && !fitsWaiter) return 'sub_admin';
  if (fitsWaiter) return 'waiter';
  return 'sub_admin';
}

List<SellerModule> pagesForStaffKind(StaffBusinessKind kind) {
  switch (kind) {
    case StaffBusinessKind.restaurant:
      return visibleSellerModules('Yemek');
    case StaffBusinessKind.gallery:
      return visibleSellerModules('Galerici');
    case StaffBusinessKind.retail:
    case StaffBusinessKind.unknown:
      return visibleSellerModules('Mağaza');
  }
}

Set<SellerPermission> staffTemplateSelection({
  required StaffRoleTemplate template,
  required bool isOwner,
  required Set<String> held,
}) {
  final ceiling = staffGrantCeiling(isOwner: isOwner, held: held);
  return template.suggested
      .where(
        (permission) =>
            ceiling.contains(permission) && staffPermissionPersists(permission),
      )
      .toSet();
}

/// Permissions an edit must send back even though the dialog cannot persist
/// them yet. Dropping them on save would remove a grant the server already
/// stored, including transferTable after the atomic transition.
Set<SellerPermission> staffPermissionsRetainedOnEdit({
  required StaffBusinessKind kind,
  required Iterable<SellerPermission> current,
}) {
  final offered = staffPermissionsForKind(kind);
  return current
      .where(
        (permission) =>
            !offered.contains(permission) || !staffPermissionPersists(permission),
      )
      .toSet();
}

String staffMemberRoleLabel({
  required StaffBusinessKind kind,
  required String? storedRole,
  required Set<SellerPermission> permissions,
}) {
  for (final template in staffRoleTemplates(kind)) {
    if (template.storedRole == storedRole &&
        template.suggested.length == permissions.length &&
        template.suggested.containsAll(permissions)) {
      return template.label;
    }
  }
  if (storedRole == 'waiter') {
    return kind == StaffBusinessKind.restaurant
        ? 'Garson'
        : 'Garson kaydı';
  }
  if (storedRole == 'sub_admin') return 'Alt yönetici';
  return 'Personel';
}

String sellerPermissionDescription(SellerPermission permission) {
  switch (permission) {
    case SellerPermission.manageProducts:
      return 'Ürün ekler ve düzenler.';
    case SellerPermission.viewOrders:
      return 'Siparişleri görüntüler.';
    case SellerPermission.manageOrders:
      return 'Sipariş alır ve mutfak fişi gönderir. Hesap kesmez.';
    case SellerPermission.manageCampaigns:
      return 'Kampanyaları yönetir.';
    case SellerPermission.viewFinance:
      return 'Finans özetini görür.';
    case SellerPermission.manageSupport:
      return 'Destek kayıtlarını yönetir.';
    case SellerPermission.manageStoreProfile:
      return 'Mağaza profilini değiştirir.';
    case SellerPermission.transferTable:
      return 'Yalnız kendi şubesindeki masalar arasında aktarır.';
    case SellerPermission.splitBill:
      return 'Eski ad. Kişi başı tutar ödeme kaydı açmaz.';
    case SellerPermission.takePartialPayment:
      return 'Ara ödeme alır.';
    case SellerPermission.closeBill:
      return 'Hesabı kapatır. Sipariş yetkisi bunu vermez.';
    case SellerPermission.managePrintSettings:
      return 'Yazıcı ayarlarını değiştirir.';
    case SellerPermission.manageTables:
      return 'Alan, masa ve QR düzenini yönetir. Sipariş, ödeme ve personel yetkisi vermez.';
    case SellerPermission.manageStaff:
      return 'Personel ekler ve yetki değiştirir.';
  }
}

bool staffPermissionNeedsConfirm(SellerPermission permission) {
  return permission == SellerPermission.closeBill ||
      permission == SellerPermission.manageStaff ||
      permission == SellerPermission.transferTable;
}
