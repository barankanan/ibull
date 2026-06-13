import re

file_path = "/Users/barankananogullari/Desktop/ibul2026 kopyası 9/ibul_app/lib/screens/seller_panel_dashboard_modules.dart"

with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# Add import if missing
if "order_status_constants.dart" not in content:
    # Not a direct import because this is a part file.
    # The import should be in `seller_panel_page.dart`! Let's check `seller_panel_page.dart` first.
    pass

replacements = {
    "'new'": "OrderStatusConstants.ecommerceNew",
    "'confirmed'": "OrderStatusConstants.ecommerceConfirmed",
    "'preparing'": "OrderStatusConstants.ecommercePreparing",
    "'ready_to_ship'": "OrderStatusConstants.ecommerceReadyToShip",
    "'shipped'": "OrderStatusConstants.ecommerceShipped",
    "'transfer'": "OrderStatusConstants.ecommerceTransfer",
    "'branch'": "OrderStatusConstants.ecommerceBranch",
    "'out_for_delivery'": "OrderStatusConstants.ecommerceOutForDelivery",
    "'delivered'": "OrderStatusConstants.ecommerceDelivered",
    "'cancelled'": "OrderStatusConstants.ecommerceCancelled",
    "'returns'": "OrderStatusConstants.ecommerceReturns",
}

for old, new in replacements.items():
    # Array literals: const ['confirmed', ...]
    content = re.sub(r"(?<![a-zA-Z0-9_])" + old + r"(?![a-zA-Z0-9_])", new, content)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)

print("Dashboard replaced.")
