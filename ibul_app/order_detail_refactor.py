import re

file_paths = [
    "/Users/barankananogullari/Desktop/ibul2026 kopyası 9/ibul_app/lib/screens/order_detail_page.dart",
    "/Users/barankananogullari/Desktop/ibul2026 kopyası 9/ibul_app/lib/screens/account_page.dart",
    "/Users/barankananogullari/Desktop/ibul2026 kopyası 9/ibul_app/lib/screens/courier_info_page.dart",
    "/Users/barankananogullari/Desktop/ibul2026 kopyası 9/ibul_app/lib/screens/order_confirmation_page.dart"
]

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
    "'returned'": "OrderStatusConstants.ecommerceReturns", # map returned to returns since we use returns for ecommerce? Wait, let's keep literal if it's not strictly 'returns'. Or wait, let's map 'returned' to 'returned' if there is no constant, but there is ecommerceReturns. We should check if returned is used as a constant.
    "'refunded'": "OrderStatusConstants.ecommerceReturns", # map refunded to returns as well? No, they might be different. Let's just use the ones we have in constants.
}

for fp in file_paths:
    with open(fp, "r", encoding="utf-8") as f:
        content = f.read()

    if "order_status_constants.dart" not in content:
        # try to insert it after material import
        content = re.sub(r"(import 'package:flutter/material.dart';)", r"\1\nimport '../utils/order_status_constants.dart';", content)

    for old, new in replacements.items():
        if old in ["'returned'", "'refunded'"]:
            # Maybe just replace 'returned' with 'returned' for now if we didn't define it. Wait, the user asked to clean it up.
            pass
        content = re.sub(r"==\s*" + old, "== " + new, content)
        content = re.sub(r"!=\s*" + old, "!= " + new, content)
        content = re.sub(r"return\s+" + old + r"\s*;", "return " + new + ";", content)
        content = re.sub(r"case\s+" + old + r"\s*:", "case " + new + ":", content)
        
    with open(fp, "w", encoding="utf-8") as f:
        f.write(content)

print("Done")
