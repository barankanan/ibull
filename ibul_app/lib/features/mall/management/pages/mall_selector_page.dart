import 'package:flutter/material.dart';

import '../../../../app/ibul_router.dart';
import '../../../../app/marketplace_paths.dart';
import '../../../../core/constants.dart';
import '../../application/mall_auth_page.dart';
import '../models/mall_profile.dart';
import '../services/mall_management_repository.dart';
import '../widgets/mall_panel_kit.dart';

const mallNoManagedMallMessage = 'Yönetebileceğiniz AVM bulunmuyor.';

/// 0 AVM: açıklama. 1 AVM: doğrudan panel. 2+ AVM: seçici.
class MallSelectorPage extends StatefulWidget {
  const MallSelectorPage({super.key, this.repository, this.autoOpenSingle = true});

  final MallManagementRepository? repository;
  final bool autoOpenSingle;

  @override
  State<MallSelectorPage> createState() => _MallSelectorPageState();
}

class _MallSelectorPageState extends State<MallSelectorPage> {
  late final MallManagementRepository _repository = widget.repository ?? MallManagementRepository();
  var _loading = true;
  String? _error;
  List<MallMembership> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _repository.myMemberships();
      if (!mounted) return;
      if (items.length == 1 && widget.autoOpenSingle) {
        IbulRouter.go(context, MarketplacePaths.mallManagementMall(items.single.mallId));
        return;
      }
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = friendlyMallError(error);
        _loading = false;
      });
    }
  }

  Future<void> _signOut() async {
    try {
      await _repository.signOut();
    } catch (error) {
      if (mounted) setState(() => _error = friendlyMallError(error));
      return;
    }
    if (mounted) IbulRouter.go(context, MarketplacePaths.mallHub);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MallTokens.pageBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink,
        leading: IconButton(
          tooltip: 'Geri',
          onPressed: () => mallGoBack(context),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('AVM Yönetimi'),
        actions: [
          TextButton.icon(
            key: const ValueKey('mall-selector-signout'),
            onPressed: _signOut,
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Çıkış Yap'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : MallPage(children: [
              if (_error != null) ...[
                MallInlineError(_error!),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(onPressed: _load, child: const Text('Tekrar dene')),
                ),
              ] else if (_items.isEmpty)
                MallEmptyState(
                  icon: Icons.apartment_outlined,
                  title: mallNoManagedMallMessage,
                  message: 'AVM yönetimine davet edildiyseniz daveti kabul edin veya yeni bir AVM başvurusu yapın.',
                  actionLabel: 'AVM Başvurusu',
                  onAction: () => IbulRouter.go(context, MarketplacePaths.mallApplication),
                )
              else ...[
                const MallPageTitle(
                  title: 'Yönettiğim AVM\'ler',
                  subtitle: 'Yönetmek istediğiniz AVM\'yi seçin.',
                ),
                MallGrid(minTileWidth: 320, children: [
                  for (final item in _items)
                    MallCard(
                      onTap: () => IbulRouter.go(context, MarketplacePaths.mallManagementMall(item.mallId)),
                      child: Row(
                        children: [
                          mallLogo(item.mall.logoUrl, size: 52),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.mall.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                const SizedBox(height: 4),
                                Text('${item.mall.locationLabel} • ${item.roleLabel}',
                                    style: const TextStyle(color: MallTokens.muted)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                ]),
              ],
            ]),
    );
  }
}
