import 'package:flutter/material.dart';

import '../../../../models/admin_permissions.dart';
import 'admin_panel_definitions.dart';

const List<AdminPanelMenuDefinition> ibulAdminMenuDefinitions = [
  AdminPanelMenuDefinition(
    icon: Icons.dashboard_outlined,
    title: 'Genel Bakış',
    groupLabel: 'Kontrol Merkezi',
    groupIcon: Icons.dashboard_customize_outlined,
    moduleKey: AdminModules.dashboard,
  ),
  AdminPanelMenuDefinition(
    icon: Icons.data_usage,
    title: 'Veriler',
    groupLabel: 'Kontrol Merkezi',
    groupIcon: Icons.dashboard_customize_outlined,
    moduleKey: AdminModules.analytics,
  ),
  AdminPanelMenuDefinition(
    icon: Icons.storefront_outlined,
    title: 'Mağaza Yönetimi',
    groupLabel: 'Ticaret Operasyonları',
    groupIcon: Icons.store_mall_directory_outlined,
    moduleKey: AdminModules.storeManagement,
  ),
  AdminPanelMenuDefinition(
    icon: Icons.inventory_2_outlined,
    title: 'Ürün Onay',
    groupLabel: 'Ticaret Operasyonları',
    groupIcon: Icons.store_mall_directory_outlined,
    moduleKey: AdminModules.productApproval,
  ),
  AdminPanelMenuDefinition(
    icon: Icons.shopping_cart_outlined,
    title: 'Sipariş & İade',
    groupLabel: 'Ticaret Operasyonları',
    groupIcon: Icons.store_mall_directory_outlined,
    moduleKey: AdminModules.ordersReturns,
  ),
  AdminPanelMenuDefinition(
    icon: Icons.map_outlined,
    title: 'Harita & Arama',
    groupLabel: 'Operasyon Araçları',
    groupIcon: Icons.tune_outlined,
    moduleKey: AdminModules.mapSearch,
  ),
  AdminPanelMenuDefinition(
    icon: Icons.account_balance_wallet_outlined,
    title: 'Finans',
    groupLabel: 'Operasyon Araçları',
    groupIcon: Icons.tune_outlined,
    moduleKey: AdminModules.finance,
  ),
  AdminPanelMenuDefinition(
    icon: Icons.ads_click_outlined,
    title: 'Reklam',
    groupLabel: 'Büyüme & İçerik',
    groupIcon: Icons.auto_awesome_outlined,
    moduleKey: AdminModules.ads,
  ),
  AdminPanelMenuDefinition(
    icon: Icons.campaign_outlined,
    title: 'Kampanya & İçerik',
    groupLabel: 'Büyüme & İçerik',
    groupIcon: Icons.auto_awesome_outlined,
    moduleKey: AdminModules.campaignContent,
  ),
  AdminPanelMenuDefinition(
    icon: Icons.grid_view,
    title: 'Sistem Düzeni',
    groupLabel: 'Büyüme & İçerik',
    groupIcon: Icons.auto_awesome_outlined,
    moduleKey: AdminModules.systemLayout,
  ),
  AdminPanelMenuDefinition(
    icon: Icons.support_agent,
    title: 'Destek & Şikayet',
    groupLabel: 'Yönetim',
    groupIcon: Icons.admin_panel_settings_outlined,
    moduleKey: AdminModules.support,
  ),
  AdminPanelMenuDefinition(
    icon: Icons.delivery_dining_outlined,
    title: 'İHIZ',
    groupLabel: 'Yönetim',
    groupIcon: Icons.admin_panel_settings_outlined,
    moduleKey: AdminModules.ihiz,
  ),
  AdminPanelMenuDefinition(
    icon: Icons.admin_panel_settings_outlined,
    title: 'Yetki Sistemi',
    groupLabel: 'Yönetim',
    groupIcon: Icons.admin_panel_settings_outlined,
    moduleKey: AdminModules.permissionSystem,
  ),
  AdminPanelMenuDefinition(
    icon: Icons.security,
    title: 'Log & Güvenlik',
    groupLabel: 'Yönetim',
    groupIcon: Icons.admin_panel_settings_outlined,
    moduleKey: AdminModules.securityLogs,
  ),
];

const List<AdminPanelMenuDefinition> ihizAdminMenuDefinitions = [
  AdminPanelMenuDefinition(
    icon: Icons.dashboard_outlined,
    title: 'Genel Bakış',
    groupLabel: 'Kurye Operasyonları',
    groupIcon: Icons.delivery_dining_outlined,
  ),
  AdminPanelMenuDefinition(
    icon: Icons.calculate_outlined,
    title: 'Ücretlendirme',
    groupLabel: 'Kurye Operasyonları',
    groupIcon: Icons.delivery_dining_outlined,
  ),
  AdminPanelMenuDefinition(
    icon: Icons.data_usage,
    title: 'Veriler',
    groupLabel: 'Kurye Operasyonları',
    groupIcon: Icons.delivery_dining_outlined,
  ),
  AdminPanelMenuDefinition(
    icon: Icons.approval_outlined,
    title: 'Başvuru Onay',
    groupLabel: 'Kurye Operasyonları',
    groupIcon: Icons.delivery_dining_outlined,
  ),
  AdminPanelMenuDefinition(
    icon: Icons.account_balance_wallet_outlined,
    title: 'Finans',
    groupLabel: 'Yönetim',
    groupIcon: Icons.admin_panel_settings_outlined,
  ),
  AdminPanelMenuDefinition(
    icon: Icons.support_agent,
    title: 'Destek & Şikayet',
    groupLabel: 'Yönetim',
    groupIcon: Icons.admin_panel_settings_outlined,
  ),
  AdminPanelMenuDefinition(
    icon: Icons.admin_panel_settings_outlined,
    title: 'Yetki Sistemi',
    groupLabel: 'Yönetim',
    groupIcon: Icons.admin_panel_settings_outlined,
  ),
  AdminPanelMenuDefinition(
    icon: Icons.security,
    title: 'Log & Güvenlik',
    groupLabel: 'Yönetim',
    groupIcon: Icons.admin_panel_settings_outlined,
  ),
];

const AdminPanelLayoutDefinition ibulAdminPanelLayoutDefinition =
    AdminPanelLayoutDefinition(
      panelTitle: 'İBul Admin',
      menuDefinitions: ibulAdminMenuDefinitions,
    );

const AdminPanelLayoutDefinition ihizAdminPanelLayoutDefinition =
    AdminPanelLayoutDefinition(
      panelTitle: 'İhız Admin',
      menuDefinitions: ihizAdminMenuDefinitions,
      showSearch: false,
    );
