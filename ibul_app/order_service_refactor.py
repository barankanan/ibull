import re

file_path = "/Users/barankananogullari/Desktop/ibul2026 kopyası 9/ibul_app/lib/services/order_service.dart"

with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# Add import if missing
if "order_status_constants.dart" not in content:
    content = content.replace("import 'supabase_service.dart';", "import '../utils/order_status_constants.dart';\nimport 'supabase_service.dart';")

# Replace constants
# We want to replace 'new', 'confirmed', 'preparing', 'ready_to_ship', 'shipped', 'transfer', 'branch', 'out_for_delivery', 'delivered', 'cancelled', 'returns'
# But only when they are used as status strings, which usually look like:
# 'status': 'new',
# == 'delivered'
# 'new'

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

# We need to be careful with 'new' because 'new' is also a keyword, but here we replace string literal "'new'".
# And only where it makes sense, e.g. status fields. But 'new' as a string is almost exclusively used for status.
# Let's use a regex that matches these exact string literals.
# Since it's Dart, string could be "new" or 'new'.

for old, new in replacements.items():
    # Replace cases like: == 'new'
    content = re.sub(r"==\s*" + old, "== " + new, content)
    content = re.sub(r"!=\s*" + old, "!= " + new, content)
    # Replace cases like: 'status': 'new'
    content = re.sub(r"\'status\'\s*:\s*" + old, "'status': " + new, content)
    content = re.sub(r"\'shipment_step\'\s*:\s*" + old, "'shipment_step': " + new, content)
    content = re.sub(r"\'order_status\'\s*:\s*item\[\'status\'\]\s*\?\?\s*" + old, "'order_status': item['status'] ?? " + new, content)
    content = re.sub(r"\'order_status\'\s*:\s*order\[\'status\'\]\s*\?\?\s*" + old, "'order_status': order['status'] ?? " + new, content)
    # Return statements: return 'new';
    content = re.sub(r"return\s+" + old + r"\s*;", "return " + new + ";", content)
    # Assignment: orderStatus = 'new';
    content = re.sub(r"=\s*" + old + r"\s*;", "= " + new + ";", content)
    # Switch cases: case 'new':
    content = re.sub(r"case\s+" + old + r"\s*:", "case " + new + ":", content)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)

print("Replacement complete.")
