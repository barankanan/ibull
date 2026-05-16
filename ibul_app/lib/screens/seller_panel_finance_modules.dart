part of 'seller_panel_page.dart';

extension _SellerPanelFinanceModules on _SellerPanelPageState {
  Widget _buildMobileFinanceModuleImpl() {
    final sellerId = _authService.currentUser?.id ?? '';
    return FinanceShell(sellerId: sellerId);
  }

  Widget _buildFinanceModuleImpl() {
    final sellerId = _authService.currentUser?.id ?? '';
    return FinanceShell(sellerId: sellerId);
  }
}
