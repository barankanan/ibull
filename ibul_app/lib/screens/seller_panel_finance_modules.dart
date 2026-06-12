part of 'seller_panel_page.dart';

extension _SellerPanelFinanceModules on _SellerPanelPageState {
  Widget _buildMobileFinanceModuleImpl() {
    if (!_isSellerOwnerBootstrapReady) {
      return const Center(child: CircularProgressIndicator());
    }
    final sellerId = _resolveSellerDataOwnerId();
    if (sellerId.isEmpty) {
      return const Center(child: Text('Satıcı verisi hazırlanıyor...'));
    }
    return FinanceShell(
      key: ValueKey('finance-mobile-$sellerId-$_financeRefreshToken'),
      sellerId: sellerId,
      optimisticClosedHistory: _dashboardClosedHistory,
    );
  }

  Widget _buildFinanceModuleImpl() {
    if (!_isSellerOwnerBootstrapReady) {
      return const Center(child: CircularProgressIndicator());
    }
    final sellerId = _resolveSellerDataOwnerId();
    if (sellerId.isEmpty) {
      return const Center(child: Text('Satıcı verisi hazırlanıyor...'));
    }
    return FinanceShell(
      key: ValueKey('finance-$sellerId-$_financeRefreshToken'),
      sellerId: sellerId,
      optimisticClosedHistory: _dashboardClosedHistory,
    );
  }
}
