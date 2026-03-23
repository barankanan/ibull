import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/admin_permissions.dart';
import '../../services/admin_service.dart';
import '../../services/auth_service.dart';

const Map<String, IconData> _roleIconMap = {
  'workspace_premium': Icons.workspace_premium_rounded,
  'admin_panel_settings': Icons.admin_panel_settings_rounded,
  'campaign': Icons.campaign_rounded,
  'support_agent': Icons.support_agent_rounded,
  'storefront': Icons.storefront_rounded,
  'insights': Icons.insights_rounded,
  'account_balance_wallet': Icons.account_balance_wallet_rounded,
  'gpp_good': Icons.gpp_good_rounded,
  'shield': Icons.shield_rounded,
  'settings': Icons.settings_rounded,
};

class PermissionSystemPage extends StatefulWidget {
  const PermissionSystemPage({super.key});

  @override
  State<PermissionSystemPage> createState() => _PermissionSystemPageState();
}

class _PermissionSystemPageState extends State<PermissionSystemPage> {
  final AdminService _adminService = AdminService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _assignmentNoteController =
      TextEditingController();
  final TextEditingController _rosterSearchController = TextEditingController();
  final TextEditingController _historySearchController =
      TextEditingController();
  final TextEditingController _roleKeyController = TextEditingController();
  final TextEditingController _roleTitleController = TextEditingController();
  final TextEditingController _roleDescriptionController =
      TextEditingController();
  final TextEditingController _roleColorController = TextEditingController();
  final TextEditingController _roleScopesController = TextEditingController();

  Timer? _searchDebounce;
  bool _isLoading = true;
  bool _isSearchingUsers = false;
  bool _isSavingAssignment = false;
  bool _isSavingRole = false;
  List<Map<String, dynamic>> _searchResults = const [];
  List<AdminRoleCatalogEntry> _roleCatalog = const [];
  List<AdminUserPermissionAssignment> _adminUsers = const [];
  List<AdminRoleHistoryEntry> _roleHistory = const [];
  Map<String, dynamic>? _selectedUser;
  String _selectedRoleKey = 'admin_support';
  String _selectedRoleIconName = 'support_agent';
  Set<String> _selectedRoleModules = <String>{AdminModules.dashboard};
  bool _selectedRoleIsActive = true;
  bool _selectedRoleIsSystem = false;
  String? _rosterRoleFilter;
  String? _historyRoleFilter;
  String _historyEventFilter = 'all';
  String _schemaMessage =
      'Rol katalogu dinamik tablolardan okunur. SQL migration uygulanmadiysa ekran varsayilan kartlarla devam eder.';

  @override
  void initState() {
    super.initState();
    _loadPageData();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _emailController.dispose();
    _assignmentNoteController.dispose();
    _rosterSearchController.dispose();
    _historySearchController.dispose();
    _roleKeyController.dispose();
    _roleTitleController.dispose();
    _roleDescriptionController.dispose();
    _roleColorController.dispose();
    _roleScopesController.dispose();
    super.dispose();
  }

  Future<void> _loadPageData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait<dynamic>([
        _adminService.getRoleCatalog(),
        _adminService.getAdminUsers(),
        _adminService.getRoleHistory(limit: 80),
      ]);
      if (!mounted) return;

      final catalog = results[0] as List<AdminRoleCatalogEntry>;
      final adminUsers = results[1] as List<AdminUserPermissionAssignment>;
      final history = results[2] as List<AdminRoleHistoryEntry>;

      final resolvedRole =
          catalog.any((entry) => entry.roleKey == _selectedRoleKey)
          ? catalog.firstWhere((entry) => entry.roleKey == _selectedRoleKey)
          : (catalog.isNotEmpty
                ? catalog.first
                : defaultAdminRoleCatalog.first);

      _applyRoleToEditor(resolvedRole);

      setState(() {
        _roleCatalog = catalog;
        _adminUsers = adminUsers;
        _roleHistory = history;
        _schemaMessage =
            history.isEmpty && catalog.length == defaultAdminRoleCatalog.length
            ? 'Rol katalogu varsayilan kartlarla acildi. Dinamik kayitlar icin SQL migration dosyasini Supabase uzerinde calistirin.'
            : 'Rol katalogu ve rol gecmisi Supabase uzerinden yukleniyor.';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Yetki verileri yuklenemedi: $e')));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyRoleToEditor(AdminRoleCatalogEntry entry) {
    _selectedRoleKey = entry.roleKey;
    _selectedRoleIconName = entry.iconName;
    _selectedRoleModules = entry.modules.toSet();
    _selectedRoleIsActive = entry.isActive;
    _selectedRoleIsSystem = entry.isSystem;
    _roleKeyController.text = entry.roleKey;
    _roleTitleController.text = entry.title;
    _roleDescriptionController.text = entry.description;
    _roleColorController.text = entry.colorHex;
    _roleScopesController.text = entry.scopes.join(', ');
  }

  void _startNewRole() {
    final customKey =
        'admin_custom_${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    setState(() {
      _selectedRoleKey = customKey;
      _selectedRoleIconName = 'shield';
      _selectedRoleModules = <String>{AdminModules.dashboard};
      _selectedRoleIsActive = true;
      _selectedRoleIsSystem = false;
      _roleKeyController.text = customKey;
      _roleTitleController.text = 'Yeni Rol';
      _roleDescriptionController.text =
          'Bu rol icin aciklama ve erisim modullerini duzenleyin.';
      _roleColorController.text = '#2563EB';
      _roleScopesController.text = 'Dashboard';
    });
  }

  Future<void> _searchUsers(String query) async {
    final normalized = query.trim();
    if (normalized.length < 2) {
      if (!mounted) return;
      setState(() {
        _isSearchingUsers = false;
        _searchResults = const [];
      });
      return;
    }

    setState(() => _isSearchingUsers = true);
    try {
      final results = await _adminService.searchUsersByEmail(normalized);
      if (!mounted) return;
      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kullanici aramasi basarisiz: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSearchingUsers = false);
      }
    }
  }

  void _onEmailChanged(String value) {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _searchUsers(value);
    });
  }

  AdminRoleCatalogEntry _roleFromForm() {
    final rawKey = _roleKeyController.text.trim();
    final roleKey = rawKey == 'super_admin' || rawKey == 'admin'
        ? rawKey
        : (rawKey.startsWith('admin_') ? rawKey : 'admin_$rawKey');
    final modules =
        _selectedRoleModules.isEmpty
              ? <String>[AdminModules.dashboard]
              : _selectedRoleModules.toList()
          ..sort();
    final scopes = _roleScopesController.text
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();

    if (_roleTitleController.text.trim().isEmpty) {
      throw Exception('Rol basligi bos olamaz.');
    }
    if (_roleDescriptionController.text.trim().isEmpty) {
      throw Exception('Rol aciklamasi bos olamaz.');
    }
    if (roleKey.isEmpty) {
      throw Exception('Rol anahtari bos olamaz.');
    }

    return AdminRoleCatalogEntry(
      roleKey: roleKey,
      title: _roleTitleController.text.trim(),
      description: _roleDescriptionController.text.trim(),
      colorHex: _normalizeColor(_roleColorController.text),
      iconName: _selectedRoleIconName,
      modules: modules,
      scopes: scopes,
      isSystem: _selectedRoleIsSystem,
      isActive: _selectedRoleIsActive,
      sortOrder: _resolveRoleSortOrder(roleKey),
    );
  }

  int _resolveRoleSortOrder(String roleKey) {
    final existing = _roleCatalog.where((entry) => entry.roleKey == roleKey);
    if (existing.isNotEmpty) return existing.first.sortOrder;
    return (_roleCatalog.isEmpty ? 100 : _roleCatalog.length * 10 + 100);
  }

  Future<void> _saveRoleCatalogEntry() async {
    if (_isSavingRole) return;
    setState(() => _isSavingRole = true);
    try {
      final role = _roleFromForm();
      await _adminService.upsertRoleCatalogEntry(role);
      if (!mounted) return;
      await _loadPageData();
      if (!mounted) return;
      setState(() {
        _selectedRoleKey = role.roleKey;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${role.title} rol karti kaydedildi.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Rol karti kaydedilemedi: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSavingRole = false);
      }
    }
  }

  Future<void> _toggleRoleStatus(bool isActive) async {
    if (_isSavingRole) return;
    final roleKey = _roleKeyController.text.trim();
    if (roleKey.isEmpty) return;

    setState(() {
      _selectedRoleIsActive = isActive;
    });
    await _saveRoleCatalogEntry();
  }

  Future<void> _assignRoleToSelectedUser() async {
    final user = _selectedUser;
    if (user == null || _isSavingAssignment) return;
    setState(() => _isSavingAssignment = true);
    try {
      await _adminService.assignAdminRole(
        userId: user['id'].toString(),
        roleKey: _selectedRoleKey,
        note: _assignmentNoteController.text.trim().isEmpty
            ? null
            : _assignmentNoteController.text.trim(),
      );
      if (!mounted) return;
      await _loadPageData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_displayNameForUser(user)} icin ${_labelForRole(_selectedRoleKey)} atandi.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Rol atanamadi: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSavingAssignment = false);
      }
    }
  }

  Future<void> _revokeSelectedUserRole() async {
    final user = _selectedUser;
    if (user == null || _isSavingAssignment) return;
    setState(() => _isSavingAssignment = true);
    try {
      await _adminService.revokeAdminRole(
        userId: user['id'].toString(),
        note: _assignmentNoteController.text.trim().isEmpty
            ? 'Admin erisimi kaldirildi.'
            : _assignmentNoteController.text.trim(),
      );
      if (!mounted) return;
      await _loadPageData();
      if (!mounted) return;
      setState(() {
        _selectedUser = {...user, 'role': 'user'};
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_displayNameForUser(user)} icin admin yetkisi kaldirildi.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Admin yetkisi kaldirilamadi: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingAssignment = false);
      }
    }
  }

  List<AdminUserPermissionAssignment> get _filteredAdminUsers {
    final search = _rosterSearchController.text.trim().toLowerCase();
    return _adminUsers.where((item) {
      final matchesRole =
          _rosterRoleFilter == null || _rosterRoleFilter == item.roleKey;
      final email = (item.userEmail ?? '').toLowerCase();
      final name = (item.userDisplayName ?? '').toLowerCase();
      final matchesSearch =
          search.isEmpty || email.contains(search) || name.contains(search);
      return matchesRole && matchesSearch;
    }).toList();
  }

  List<AdminRoleHistoryEntry> get _filteredHistory {
    final search = _historySearchController.text.trim().toLowerCase();
    return _roleHistory.where((item) {
      final matchesRole =
          _historyRoleFilter == null ||
          item.newRoleKey == _historyRoleFilter ||
          item.previousRoleKey == _historyRoleFilter;
      final matchesEvent =
          _historyEventFilter == 'all' || item.eventType == _historyEventFilter;
      final haystack = [
        item.userDisplayName ?? '',
        item.userEmail ?? '',
        item.actorDisplayName ?? '',
        item.note ?? '',
        item.newRoleKey ?? '',
        item.previousRoleKey ?? '',
      ].join(' ').toLowerCase();
      final matchesSearch = search.isEmpty || haystack.contains(search);
      return matchesRole && matchesEvent && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadPageData,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 1240;
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              _buildHero(),
              const SizedBox(height: 20),
              _buildSchemaBanner(),
              const SizedBox(height: 20),
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 6, child: _buildUserAssignmentPanel()),
                    const SizedBox(width: 20),
                    Expanded(flex: 6, child: _buildRoleEditorPanel()),
                  ],
                )
              else ...[
                _buildUserAssignmentPanel(),
                const SizedBox(height: 20),
                _buildRoleEditorPanel(),
              ],
              const SizedBox(height: 20),
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 6, child: _buildRoleCatalogPanel()),
                    const SizedBox(width: 20),
                    Expanded(flex: 6, child: _buildAdminRosterPanel()),
                  ],
                )
              else ...[
                _buildRoleCatalogPanel(),
                const SizedBox(height: 20),
                _buildAdminRosterPanel(),
              ],
              const SizedBox(height: 20),
              _buildHistoryPanel(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHero() {
    final superAdminCount = _adminUsers
        .where((item) => item.roleKey == 'super_admin')
        .length;
    final supportCount = _adminUsers
        .where((item) => item.roleKey == 'admin_support')
        .length;
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF172554), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Dinamik admin yetki merkezi',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Rol kartlarini duzenle, modulleri ac kapa ve yetkiyi e-posta ile calisanlara ata.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Bu ekran artik sadece hazir roller gostermiyor. Rol katalogu, kullanici atamasi, moduller ve rol gecmisi tek yerden yonetilir.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _heroStat(
                'Rol karti',
                '${_roleCatalog.length}',
                'duzenlenebilir katalog',
              ),
              _heroStat(
                'Aktif admin',
                '${_adminUsers.length}',
                'yetkili hesap',
              ),
              _heroStat('Super admin', '$superAdminCount', 'kritik erisim'),
              _heroStat('Destek ekibi', '$supportCount', 'operasyon hesabi'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String title, String value, String subtitle) {
    return Container(
      width: 168,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.74),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSchemaBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        children: [
          const Icon(Icons.dataset_linked_rounded, color: Color(0xFF2563EB)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _schemaMessage,
              style: const TextStyle(
                color: Color(0xFF1D4ED8),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserAssignmentPanel() {
    final selectedUser = _selectedUser;
    return _card(
      title: 'Calisan sec ve yetki ata',
      subtitle:
          'Kayitli e-posta adresiyle hesap secin. Seçilen rol, kullanicinin admin panelindeki gorunur modullerini belirler.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 680;
              if (compact) {
                return Column(
                  children: [
                    _buildSearchField(),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: _buildSearchButton(),
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: _buildSearchField()),
                  const SizedBox(width: 12),
                  _buildSearchButton(),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Eslesen hesaplar',
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    if (_isSearchingUsers)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                if (_emailController.text.trim().length < 2)
                  _hintState(
                    icon: Icons.alternate_email_rounded,
                    title: 'Arama icin en az 2 karakter yazin',
                    subtitle:
                        'Tam e-posta veya alan adiyla kullanici bulabilirsiniz.',
                  )
                else if (!_isSearchingUsers && _searchResults.isEmpty)
                  _hintState(
                    icon: Icons.person_search_rounded,
                    title: 'Kayit bulunamadi',
                    subtitle:
                        'Bu arama icin users tablosunda eslesen hesap yok.',
                  )
                else
                  ..._searchResults.map(_buildSearchResultCard),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (selectedUser == null)
            _hintState(
              icon: Icons.person_add_alt_1_rounded,
              title: 'Henuz kullanici secilmedi',
              subtitle:
                  'Arama sonucundan bir kullanici secerek rol atama butonlarini aktif edin.',
            )
          else
            _buildSelectedUserSummary(selectedUser),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _emailController,
      onChanged: _onEmailChanged,
      onSubmitted: _searchUsers,
      decoration: InputDecoration(
        hintText: 'ornek: destek@ibul.com',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _emailController.text.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  setState(() {
                    _emailController.clear();
                    _searchResults = const [];
                  });
                },
                icon: const Icon(Icons.close_rounded),
              ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.2),
        ),
      ),
    );
  }

  Widget _buildSearchButton() {
    return FilledButton.icon(
      onPressed: () => _searchUsers(_emailController.text),
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF111827),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      icon: const Icon(Icons.manage_search_rounded),
      label: const Text('Ara'),
    );
  }

  Widget _buildSearchResultCard(Map<String, dynamic> user) {
    final roleKey = (user['role'] ?? '').toString();
    final roleColor = _colorForRole(roleKey);
    final isSelected = _selectedUser?['id'] == user['id'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          setState(() {
            _selectedUser = user;
            if (AuthService.isAdminRole(roleKey) &&
                _roleCatalog.any((entry) => entry.roleKey == roleKey)) {
              _applyRoleToEditor(
                _roleCatalog.firstWhere((entry) => entry.roleKey == roleKey),
              );
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected
                ? roleColor.withValues(alpha: 0.10)
                : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected ? roleColor : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: roleColor.withValues(alpha: 0.14),
                child: Text(
                  _displayNameForUser(user).substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    color: roleColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _displayNameForUser(user),
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (user['email'] ?? '-').toString(),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              _pill(
                label: _labelForRole(roleKey),
                color: AuthService.isAdminRole(roleKey)
                    ? roleColor
                    : const Color(0xFF64748B),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedUserSummary(Map<String, dynamic> user) {
    final currentRole = (user['role'] ?? 'user').toString();
    final nextRoleColor = _colorForRole(_selectedRoleKey);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            nextRoleColor.withValues(alpha: 0.14),
            const Color(0xFFF8FAFC),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: nextRoleColor.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: nextRoleColor.withValues(alpha: 0.16),
                child: Text(
                  _displayNameForUser(user).substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    color: nextRoleColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _displayNameForUser(user),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (user['email'] ?? '-').toString(),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _pill(
                          label: 'Mevcut: ${_labelForRole(currentRole)}',
                          color: _colorForRole(currentRole),
                        ),
                        _pill(
                          label: 'Yeni: ${_labelForRole(_selectedRoleKey)}',
                          color: nextRoleColor,
                        ),
                        _pill(
                          label: '${_selectedRoleModules.length} modul',
                          color: const Color(0xFF2563EB),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (currentRole == 'seller')
            _banner(
              background: const Color(0xFFFFFBEB),
              border: const Color(0xFFFDE68A),
              icon: Icons.warning_amber_rounded,
              iconColor: const Color(0xFFD97706),
              textColor: const Color(0xFF92400E),
              text:
                  'Bu hesap su an satici rolunde. Admin rolune gecince kullanicinin aktif panel yetkisi degisir.',
            ),
          TextField(
            controller: _assignmentNoteController,
            minLines: 2,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Atama notu',
              hintText: 'Ornek: Destek ekibi vardiya hesabi',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Color(0xFF2563EB)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 560;
              if (compact) {
                return Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: _buildApplyButton(),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: _buildRevokeButton(),
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: _buildApplyButton()),
                  const SizedBox(width: 12),
                  Expanded(child: _buildRevokeButton()),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildApplyButton() {
    return FilledButton.icon(
      onPressed: _isSavingAssignment ? null : _assignRoleToSelectedUser,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF111827),
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      icon: _isSavingAssignment
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.check_circle_outline_rounded),
      label: const Text('Yetkiyi uygula'),
    );
  }

  Widget _buildRevokeButton() {
    return OutlinedButton.icon(
      onPressed: _isSavingAssignment ? null : _revokeSelectedUserRole,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFDC2626),
        padding: const EdgeInsets.symmetric(vertical: 18),
        side: const BorderSide(color: Color(0xFFFCA5A5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      icon: const Icon(Icons.remove_moderator_outlined),
      label: const Text('Adminligi kaldir'),
    );
  }

  Widget _buildRoleEditorPanel() {
    final currentColor = _colorFromHex(_roleColorController.text);
    return _card(
      title: 'Rol katalogu duzenle',
      subtitle:
          'Kart icindeki baslik, aciklama, renk, ikon, aktiflik ve modul erisimlerini burada degistirin.',
      trailing: FilledButton.icon(
        onPressed: _startNewRole,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Yeni rol'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: currentColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: currentColor.withValues(alpha: 0.24)),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: currentColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    _iconForName(_selectedRoleIconName),
                    color: currentColor,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _roleTitleController.text.trim().isEmpty
                            ? 'Rol basligi'
                            : _roleTitleController.text.trim(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _roleDescriptionController.text.trim().isEmpty
                            ? 'Rol aciklamasi burada gorunur.'
                            : _roleDescriptionController.text.trim(),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _selectedRoleIsActive,
                  onChanged: (value) {
                    setState(() => _selectedRoleIsActive = value);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _roleKeyController,
                  readOnly: _selectedRoleIsSystem,
                  decoration: _fieldDecoration('Rol anahtari', 'admin_support'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _roleTitleController,
                  onChanged: (_) => setState(() {}),
                  decoration: _fieldDecoration('Kart basligi', 'Destek Ekibi'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _roleDescriptionController,
            onChanged: (_) => setState(() {}),
            minLines: 2,
            maxLines: 3,
            decoration: _fieldDecoration(
              'Kart aciklamasi',
              'Bu rol hangi operasyon icin kullaniliyor?',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _roleColorController,
                  onChanged: (_) => setState(() {}),
                  decoration: _fieldDecoration('Renk', '#2563EB'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey(_selectedRoleIconName),
                  initialValue: _selectedRoleIconName,
                  items: _roleIconMap.keys
                      .map(
                        (iconName) => DropdownMenuItem(
                          value: iconName,
                          child: Row(
                            children: [
                              Icon(_iconForName(iconName), size: 18),
                              const SizedBox(width: 8),
                              Text(iconName),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selectedRoleIconName = value);
                  },
                  decoration: _fieldDecoration('Ikon', ''),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _roleScopesController,
            decoration: _fieldDecoration(
              'Kart etiketleri',
              'Dashboard, Ticket, KPI',
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Modul erisimleri',
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: AdminModules.all.map((module) {
              final selected = _selectedRoleModules.contains(module);
              return FilterChip(
                selected: selected,
                label: Text(AdminModules.labels[module] ?? module),
                onSelected: (value) {
                  setState(() {
                    if (value) {
                      _selectedRoleModules.add(module);
                    } else {
                      _selectedRoleModules.remove(module);
                    }
                  });
                },
                selectedColor: currentColor.withValues(alpha: 0.18),
                checkmarkColor: currentColor,
                side: BorderSide(
                  color: selected
                      ? currentColor.withValues(alpha: 0.42)
                      : const Color(0xFFE2E8F0),
                ),
                labelStyle: TextStyle(
                  color: selected ? currentColor : const Color(0xFF334155),
                  fontWeight: FontWeight.w700,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isSavingRole ? null : _saveRoleCatalogEntry,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF111827),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: _isSavingRole
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Rol kartini kaydet'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSavingRole
                      ? null
                      : () => _toggleRoleStatus(!_selectedRoleIsActive),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    side: const BorderSide(color: Color(0xFFBFDBFE)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: Icon(
                    _selectedRoleIsActive
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  label: Text(_selectedRoleIsActive ? 'Pasife al' : 'Aktif et'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCatalogPanel() {
    return _card(
      title: 'Rol kartlari',
      subtitle:
          'Kartlara tiklayarak baslik, aciklama ve modul setini duzenleyin.',
      child: Column(
        children: _roleCatalog.map((entry) {
          final isSelected = entry.roleKey == _selectedRoleKey;
          final color = _colorFromHex(entry.colorHex);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () {
                setState(() {
                  _applyRoleToEditor(entry);
                });
              },
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.10)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isSelected ? color : const Color(0xFFE2E8F0),
                    width: isSelected ? 1.4 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            _iconForName(entry.iconName),
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.title,
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                entry.description,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _pill(
                          label: entry.isActive ? 'Aktif' : 'Pasif',
                          color: entry.isActive
                              ? const Color(0xFF16A34A)
                              : const Color(0xFF64748B),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: entry.modules
                          .map(
                            (module) => _pill(
                              label: AdminModules.labels[module] ?? module,
                              color: color,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAdminRosterPanel() {
    final filteredUsers = _filteredAdminUsers;
    return _card(
      title: 'Aktif admin listesi',
      subtitle:
          'Canli filtre ile ekip veya kisi bazinda admin kullanicilarini inceleyin.',
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 680;
              final roleDropdown = DropdownButtonFormField<String?>(
                key: ValueKey('roster-${_rosterRoleFilter ?? 'all'}'),
                initialValue: _rosterRoleFilter,
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Tum roller'),
                  ),
                  ..._roleCatalog.map(
                    (entry) => DropdownMenuItem<String?>(
                      value: entry.roleKey,
                      child: Text(entry.title),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() => _rosterRoleFilter = value);
                },
                decoration: _fieldDecoration('Rol filtre', ''),
              );
              final searchField = TextField(
                controller: _rosterSearchController,
                onChanged: (_) => setState(() {}),
                decoration: _fieldDecoration(
                  'Canli filtre',
                  'isim veya e-posta',
                ),
              );
              if (compact) {
                return Column(
                  children: [
                    searchField,
                    const SizedBox(height: 12),
                    roleDropdown,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: searchField),
                  const SizedBox(width: 12),
                  Expanded(child: roleDropdown),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          if (filteredUsers.isEmpty)
            _hintState(
              icon: Icons.admin_panel_settings_outlined,
              title: 'Filtreye uygun admin bulunamadi',
              subtitle:
                  'Rol filtresini sifirlayin veya yeni bir calisan atayin.',
            )
          else
            ...filteredUsers.map((item) {
              final color = _colorForRole(item.roleKey);
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        _iconForName(_roleEntryFor(item.roleKey)?.iconName),
                        color: color,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.userDisplayName ?? 'Admin',
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.userEmail ?? '-',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                            ),
                          ),
                          if ((item.note ?? '').trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              item.note!,
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _pill(label: _labelForRole(item.roleKey), color: color),
                        const SizedBox(height: 8),
                        Text(
                          '${item.allowedModules.length} modul',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildHistoryPanel() {
    final filteredHistory = _filteredHistory;
    return _card(
      title: 'Rol gecmisi',
      subtitle:
          'Atama, guncelleme, kaldirma ve rol karti degisikliklerini canli filtre ile izleyin.',
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 920;
              final searchField = TextField(
                controller: _historySearchController,
                onChanged: (_) => setState(() {}),
                decoration: _fieldDecoration(
                  'Gecmis ara',
                  'kisi, rol veya not',
                ),
              );
              final roleDropdown = DropdownButtonFormField<String?>(
                key: ValueKey('history-role-${_historyRoleFilter ?? 'all'}'),
                initialValue: _historyRoleFilter,
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Tum roller'),
                  ),
                  ..._roleCatalog.map(
                    (entry) => DropdownMenuItem<String?>(
                      value: entry.roleKey,
                      child: Text(entry.title),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() => _historyRoleFilter = value);
                },
                decoration: _fieldDecoration('Rol', ''),
              );
              final eventDropdown = DropdownButtonFormField<String>(
                key: ValueKey('history-event-$_historyEventFilter'),
                initialValue: _historyEventFilter,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('Tum olaylar')),
                  DropdownMenuItem(value: 'granted', child: Text('Atama')),
                  DropdownMenuItem(value: 'updated', child: Text('Guncelleme')),
                  DropdownMenuItem(value: 'revoked', child: Text('Kaldirma')),
                  DropdownMenuItem(
                    value: 'catalog_created',
                    child: Text('Rol karti olusturma'),
                  ),
                  DropdownMenuItem(
                    value: 'catalog_updated',
                    child: Text('Rol karti guncelleme'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _historyEventFilter = value);
                },
                decoration: _fieldDecoration('Olay tipi', ''),
              );

              if (compact) {
                return Column(
                  children: [
                    searchField,
                    const SizedBox(height: 12),
                    roleDropdown,
                    const SizedBox(height: 12),
                    eventDropdown,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(flex: 3, child: searchField),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: roleDropdown),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: eventDropdown),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          if (filteredHistory.isEmpty)
            _hintState(
              icon: Icons.history_toggle_off_rounded,
              title: 'Gosterilecek gecmis kaydi yok',
              subtitle: 'Filtreyi sifirlayin veya yeni bir rol atamasi yapin.',
            )
          else
            ...filteredHistory.map((entry) {
              final color = _colorForRole(
                entry.newRoleKey ?? entry.previousRoleKey,
              );
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(_historyIcon(entry.eventType), color: color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _historyTitle(entry),
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _historySubtitle(entry),
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                              height: 1.45,
                            ),
                          ),
                          if ((entry.note ?? '').trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              entry.note!,
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _pill(
                          label: _eventLabel(entry.eventType),
                          color: color,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _relativeTime(entry.createdAt),
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint.isEmpty ? null : hint,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.2),
      ),
    );
  }

  Widget _card({
    required String title,
    required String subtitle,
    required Widget child,
    Widget? trailing,
  }) {
    final headerChildren = <Widget>[
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    ];
    if (trailing != null) {
      headerChildren.add(const SizedBox(width: 12));
      headerChildren.add(trailing);
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: headerChildren,
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _hintState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: const Color(0xFF94A3B8)),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _banner({
    required Color background,
    required Color border,
    required IconData icon,
    required Color iconColor,
    required Color textColor,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: textColor, fontSize: 13, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  AdminRoleCatalogEntry? _roleEntryFor(String? roleKey) {
    if (roleKey == null || roleKey.isEmpty) return null;
    for (final entry in _roleCatalog) {
      if (entry.roleKey == roleKey) return entry;
    }
    for (final entry in defaultAdminRoleCatalog) {
      if (entry.roleKey == roleKey) return entry;
    }
    return null;
  }

  String _displayNameForUser(Map<String, dynamic> user) {
    final displayName = (user['display_name'] ?? '').toString().trim();
    if (displayName.isNotEmpty) return displayName;
    final email = (user['email'] ?? '').toString().trim();
    if (email.isNotEmpty) return email.split('@').first;
    return 'Kullanici';
  }

  String _labelForRole(String? roleKey) {
    final entry = _roleEntryFor(roleKey);
    return entry?.title ?? AuthService.adminRoleLabel(roleKey);
  }

  Color _colorForRole(String? roleKey) {
    final entry = _roleEntryFor(roleKey);
    return _colorFromHex(entry?.colorHex ?? '#64748B');
  }

  Color _colorFromHex(String? value) {
    final normalized = _normalizeColor(value);
    final hex = normalized.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  String _normalizeColor(String? value) {
    final sanitized = (value ?? '').trim().replaceAll('#', '').toUpperCase();
    if (sanitized.length == 6) {
      return '#$sanitized';
    }
    return '#2563EB';
  }

  IconData _iconForName(String? iconName) {
    if (iconName == null) return Icons.shield_rounded;
    return _roleIconMap[iconName] ?? Icons.shield_rounded;
  }

  IconData _historyIcon(String eventType) {
    switch (eventType) {
      case 'granted':
        return Icons.verified_user_rounded;
      case 'updated':
        return Icons.edit_rounded;
      case 'revoked':
        return Icons.remove_moderator_rounded;
      case 'catalog_created':
        return Icons.add_box_rounded;
      case 'catalog_updated':
        return Icons.view_carousel_rounded;
      default:
        return Icons.history_rounded;
    }
  }

  String _eventLabel(String eventType) {
    switch (eventType) {
      case 'granted':
        return 'Atama';
      case 'updated':
        return 'Guncelleme';
      case 'revoked':
        return 'Kaldirildi';
      case 'catalog_created':
        return 'Rol olustu';
      case 'catalog_updated':
        return 'Rol guncellendi';
      default:
        return eventType;
    }
  }

  String _historyTitle(AdminRoleHistoryEntry entry) {
    switch (entry.eventType) {
      case 'catalog_created':
      case 'catalog_updated':
        return _labelForRole(entry.newRoleKey);
      default:
        return entry.userDisplayName ?? entry.userEmail ?? 'Yetki kaydi';
    }
  }

  String _historySubtitle(AdminRoleHistoryEntry entry) {
    final actor = entry.actorDisplayName ?? entry.actorEmail ?? 'Sistem';
    switch (entry.eventType) {
      case 'granted':
        return '$actor tarafindan ${_labelForRole(entry.newRoleKey)} rolu atandi.';
      case 'updated':
        return '$actor tarafindan ${_labelForRole(entry.previousRoleKey)} rolu ${_labelForRole(entry.newRoleKey)} olarak guncellendi.';
      case 'revoked':
        return '$actor tarafindan admin erisimi kaldirildi.';
      case 'catalog_created':
        return '$actor yeni rol karti olusturdu ve modul setini tanimladi.';
      case 'catalog_updated':
        return '$actor rol kartini ve modul kapsamini guncelledi.';
      default:
        return 'Yetki hareketi kaydi.';
    }
  }

  String _relativeTime(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return 'az once';
    if (diff.inHours < 1) return '${diff.inMinutes} dk once';
    if (diff.inDays < 1) return '${diff.inHours} sa once';
    if (diff.inDays < 30) return '${diff.inDays} gun once';
    final months = (diff.inDays / 30).floor();
    return '$months ay once';
  }
}
