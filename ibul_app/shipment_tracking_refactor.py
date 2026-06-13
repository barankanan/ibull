import re

file_path = "/Users/barankananogullari/Desktop/ibul2026 kopyası 9/ibul_app/lib/screens/shipment_tracking_page.dart"

with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# Add import if missing
if "order_status_constants.dart" not in content:
    content = content.replace("import '../widgets/common/video_player_widget.dart';", "import '../widgets/common/video_player_widget.dart';\nimport '../utils/order_status_constants.dart';")

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
    # Replace cases like: == 'new'
    content = re.sub(r"==\s*" + old, "== " + new, content)
    content = re.sub(r"!=\s*" + old, "!= " + new, content)
    # Default assignments: ?? 'confirmed'
    content = re.sub(r"\?\?\s*" + old, "?? " + new, content)
    # Return statements: return 'new';
    content = re.sub(r"return\s+" + old + r"\s*;", "return " + new + ";", content)
    # Assignment: orderStatus = 'new';
    content = re.sub(r"=\s*" + old + r"\s*;", "= " + new + ";", content)
    # Switch cases: case 'new':
    content = re.sub(r"case\s+" + old + r"\s*:", "case " + new + ":", content)
    # Array literals: const ['confirmed', ...] -> OrderStatusConstants.ecommerceConfirmed
    content = re.sub(r"(?<![a-zA-Z0-9_])" + old + r"(?![a-zA-Z0-9_])", new, content)

# But wait, the array literals replace might replace any occurrence of the literal. We should just let python do standard string replacement but carefully.
# Actually, re.sub(r"(?<![a-zA-Z0-9_])" + old + r"(?![a-zA-Z0-9_])", new, content) is safe enough since old includes single quotes.

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)

print("Replacement complete.")
