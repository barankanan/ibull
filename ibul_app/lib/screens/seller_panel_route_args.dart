/// Lightweight route args for `/seller` — kept out of [SellerPanelPage] so web
/// boot can defer-load the heavy seller panel module.
enum SellerPanelEntryRole { seller, waiter }

SellerPanelEntryRole parseSellerPanelEntryRole(Object? arguments) {
  if (arguments is SellerPanelEntryRole) {
    return arguments;
  }
  final rawValue = arguments is Map<String, dynamic>
      ? arguments['entryRole']?.toString()
      : arguments?.toString();
  switch (rawValue?.trim().toLowerCase()) {
    case 'waiter':
    case 'garson':
      return SellerPanelEntryRole.waiter;
    default:
      return SellerPanelEntryRole.seller;
  }
}
