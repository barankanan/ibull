import 'package:flutter/material.dart';
import '../../models/admin_permissions.dart';
import '../../services/admin_service.dart';
import '../../services/auth_service.dart';
import '../seller_login_page.dart';
import '../../features/admin/panel/helpers/admin_panel_access_helpers.dart';
import '../../features/admin/panel/models/admin_menu_registry.dart';
import '../../features/admin/panel/models/admin_panel_definitions.dart';
import '../../features/admin/panel/pages/system_layout_page.dart';
import '../../features/admin/panel/widgets/admin_login_required_state.dart';
import '../../features/admin/panel/widgets/admin_panel_loading_state.dart';
import '../../features/admin/panel/widgets/admin_operation_selector.dart';
import '../../features/admin/panel/routing/admin_panel_content_router.dart';
import '../../features/admin/panel/widgets/admin_panel_shell.dart';
import '../../features/admin/panel/widgets/admin_sidebar.dart';

class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({
    super.key,
    this.authService,
    this.adminService,
  });

  final AuthService? authService;
  final AdminService? adminService;

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> {
  String _selectedMenu = 'Genel Bakış';
  String _selectedIhizMenu = 'Genel Bakış';
  late final AdminService _adminService = widget.adminService ?? AdminService();
  late final AuthService _authService = widget.authService ?? AuthService();
  bool _isCheckingAccess = true;
  bool _hasAdminAccess = false;
  String _adminName = 'Admin';
  String _adminEmail = '';
  String _adminRoleLabel = 'Admin';
  Set<String> _allowedModules = <String>{};
  AdminPanelOperationMode _selectedOperationMode = AdminPanelOperationMode.ibul;
  bool _isOperationSelectorExpanded = false;

  List<AdminPanelMenuDefinition> get _visibleMenuEntries =>
      visibleAdminPanelMenus(_allowedModules);

  AdminPanelLayoutDefinition get _activeLayoutDefinition {
    switch (_selectedOperationMode) {
      case AdminPanelOperationMode.ihiz:
        return ihizAdminPanelLayoutDefinition;
      case AdminPanelOperationMode.defaultPanel:
      case AdminPanelOperationMode.ibul:
        return ibulAdminPanelLayoutDefinition;
    }
  }

  String get _activeSelectedMenu {
    switch (_selectedOperationMode) {
      case AdminPanelOperationMode.ihiz:
        return _selectedIhizMenu;
      case AdminPanelOperationMode.defaultPanel:
      case AdminPanelOperationMode.ibul:
        return _selectedMenu;
    }
  }

  @override
  void initState() {
    super.initState();
    _resolveAdminAccess();
  }

  Future<void> _resolveAdminAccess() async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        if (!mounted) return;
        setState(() {
          _hasAdminAccess = false;
          _allowedModules = <String>{};
          _adminEmail = '';
          _adminName = 'Admin';
          _adminRoleLabel = 'Admin';
        });
        return;
      }

      final roleFuture = _authService.getUserDataField('role');
      final profileFuture = _authService.getUserProfile();
      final role = await roleFuture;
      final profile = await profileFuture;
      final accessBundle = AuthService.isAdminRole(role?.toString())
          ? await _adminService.getCurrentAdminAccessBundle()
          : const AdminAccessBundle(
              roleKey: 'user',
              roleTitle: 'Kullanici',
              allowedModules: [],
              deniedModules: [],
            );
      if (!mounted) return;

      final visibleMenus = ibulAdminMenuDefinitions
          .where((entry) => accessBundle.canAccess(entry.moduleKey ?? ''))
          .toList(growable: false);
      final nextSelectedMenu = resolveAdminSelectedMenu(
        currentSelectedMenu: _selectedMenu,
        visibleMenus: visibleMenus,
      );

      setState(() {
        _hasAdminAccess = AuthService.isAdminRole(role?.toString());
        _allowedModules = accessBundle.allowedModules.toSet();
        _adminRoleLabel = accessBundle.roleTitle;
        _selectedMenu = nextSelectedMenu;
        _adminName =
            (profile?['display_name']?.toString().trim().isNotEmpty ?? false)
            ? profile!['display_name'].toString()
            : (user.email?.split('@').first ?? 'Admin');
        _adminEmail = user.email ?? '';
      });
    } catch (error, stackTrace) {
      debugPrint('AdminPanelPage _resolveAdminAccess failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _hasAdminAccess = false;
        _allowedModules = <String>{};
        _selectedMenu = 'Genel Bakış';
        _selectedIhizMenu = 'Genel Bakış';
        _adminRoleLabel = 'Admin';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingAccess = false;
        });
      }
    }
  }

  Future<void> _exitAdminPanel() async {
    try {
      final restored = await _authService.restoreUserSessionAfterSellerExit();
      if (!mounted) return;
      if (restored) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        return;
      }
    } catch (_) {}

    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAccess) {
      return const AdminPanelLoadingState();
    }

    if (!_hasAdminAccess) {
      return AdminLoginRequiredState(
        onLoginTap: () {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const SellerLoginPage(adminMode: true),
            ),
          );
        },
      );
    }

    if (_selectedOperationMode == AdminPanelOperationMode.ihiz) {
      return _buildAdminLayout();
    }

    if (_selectedOperationMode == AdminPanelOperationMode.ibul) {
      return _buildAdminLayout();
    }

    return _buildAdminLayout();
  }

  Widget _buildAdminLayout() {
    final layoutDefinition = _activeLayoutDefinition;
    final menuDefinitions =
        _selectedOperationMode == AdminPanelOperationMode.ihiz
        ? layoutDefinition.menuDefinitions
        : _visibleMenuEntries;

    return AdminPanelShell(
      panelTitle: layoutDefinition.panelTitle,
      menuSections: _buildMenuSections(menuDefinitions),
      adminName: _adminName,
      adminEmail: _adminEmail,
      onLogoutTap: _exitAdminPanel,
      headerTitle: _activeSelectedMenu,
      content: _selectedOperationMode == AdminPanelOperationMode.ihiz
          ? _buildIhizContent()
          : _buildContent(),
      operationSelector: _buildOperationSelector(),
      showSearch: layoutDefinition.showSearch,
      showOverviewBadge:
          _selectedOperationMode != AdminPanelOperationMode.ihiz &&
          _selectedMenu == 'Genel Bakış',
    );
  }

  String get _selectedOperationLabel {
    return adminOperationModeLabel(_selectedOperationMode, _adminRoleLabel);
  }

  Widget _buildOperationSelector() {
    return AdminOperationSelectorCard(
      selectedLabel: _selectedOperationLabel,
      isExpanded: _isOperationSelectorExpanded,
      onToggle: () {
        setState(() {
          _isOperationSelectorExpanded = !_isOperationSelectorExpanded;
        });
      },
      options: [
        _buildOperationOptionEntry('İbul', AdminPanelOperationMode.ibul),
        _buildOperationOptionEntry('İhız', AdminPanelOperationMode.ihiz),
      ],
    );
  }

  AdminOperationOptionEntry _buildOperationOptionEntry(
    String label,
    AdminPanelOperationMode mode,
  ) {
    return AdminOperationOptionEntry(
      label: label,
      isActive: _selectedOperationMode == mode,
      onTap: () {
        setState(() {
          _selectedOperationMode = mode;
          _isOperationSelectorExpanded = false;
          if (mode == AdminPanelOperationMode.ihiz) {
            _selectedIhizMenu = ihizAdminMenuDefinitions.first.title;
          }
        });
      },
    );
  }

  List<AdminPanelMenuSectionEntry> _buildMenuSections(
    List<AdminPanelMenuDefinition> definitions,
  ) {
    return buildAdminPanelMenuSectionEntries(
      definitions: definitions,
      selectedTitle: _activeSelectedMenu,
      onSelect: (title) {
        setState(() {
          if (_selectedOperationMode == AdminPanelOperationMode.ihiz) {
            _selectedIhizMenu = title;
            return;
          }
          _selectedMenu = title;
        });
      },
    );
  }

  Widget _buildContent() {
    final hasSelectedMenuAccess = _visibleMenuEntries.any(
      (entry) => entry.title == _selectedMenu,
    );
    return buildAdminPanelContent(
      selectedMenu: _selectedMenu,
      hasSelectedMenuAccess: hasSelectedMenuAccess,
      systemLayoutPage: const SystemLayoutPage(),
    );
  }

  Widget _buildIhizContent() {
    return buildIhizAdminPanelContent(selectedMenu: _selectedIhizMenu);
  }
}
