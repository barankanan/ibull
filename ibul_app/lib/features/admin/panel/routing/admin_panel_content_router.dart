import 'package:flutter/material.dart';

import '../../../../ads/presentation/pages/admin_ads_manager_content.dart';
import '../../../../screens/admin/admin_security_logs_page.dart';
import '../../../../screens/admin/data_analytics_page.dart';
import '../../../../screens/admin/finance_page.dart';
import '../../../../screens/admin/general_overview_page.dart';
import '../../../../screens/admin/ihiz_admin_page.dart';
import '../../../../screens/admin/ihiz_application_approval_page.dart';
import '../../../../screens/admin/ihiz_pricing_management_page.dart';
import '../../../../screens/admin/map_admin_page.dart';
import '../../../../screens/admin/permission_system_page.dart';
import '../../../../screens/admin/product_approval/product_approval_page.dart';
import '../../../../screens/admin/store_management_page.dart';
import '../../../../screens/admin/support_complaints_page.dart';
import '../widgets/admin_panel_state_widgets.dart';

Widget buildAdminPanelContent({
  required String selectedMenu,
  required bool hasSelectedMenuAccess,
  required Widget systemLayoutPage,
}) {
  if (!hasSelectedMenuAccess) {
    return const AdminAccessDeniedState();
  }

  switch (selectedMenu) {
    case 'Genel Bakış':
      return const GeneralOverviewPage();
    case 'Veriler':
      return const DataAnalyticsPage();
    case 'Sistem Düzeni':
      return systemLayoutPage;
    case 'Mağaza Yönetimi':
      return const StoreManagementPage();
    case 'Ürün Onay':
      return const ProductApprovalPage();
    case 'Harita & Arama':
      return const MapAdminPage();
    case 'Finans':
      return const FinanceAdminPage();
    case 'Reklam':
      return const AdminAdsManagerContent(embedded: true);
    case 'Destek & Şikayet':
      return const AdminSupportComplaintsPage();
    case 'İHIZ':
      return const IhizAdminPage();
    case 'Yetki Sistemi':
      return const PermissionSystemPage();
    case 'Log & Güvenlik':
      return const AdminSecurityLogsPage();
    default:
      return AdminPreparingState(sectionTitle: selectedMenu);
  }
}

Widget buildIhizAdminPanelContent({required String selectedMenu}) {
  switch (selectedMenu) {
    case 'Genel Bakış':
      return const IhizAdminPage();
    case 'Ücretlendirme':
      return const IhizPricingManagementPage();
    case 'Veriler':
      return const IhizAdminPage();
    case 'Başvuru Onay':
      return const IhizApplicationApprovalPage();
    case 'Finans':
      return const SizedBox.expand();
    case 'Destek & Şikayet':
      return const AdminSupportComplaintsPage(
        scope: AdminSupportScope.ihizCourierOnly,
      );
    case 'Yetki Sistemi':
      return const SizedBox.expand();
    case 'Log & Güvenlik':
      return const SizedBox.expand();
    default:
      return const SizedBox.expand();
  }
}
