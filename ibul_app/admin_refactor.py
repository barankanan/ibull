import re
import os

files_to_update = [
    "lib/screens/admin/store_application_detail_dialog.dart",
    "lib/screens/admin/support_complaints_page.dart",
    "lib/screens/admin/ihiz_application_approval_page.dart",
    "lib/screens/admin/data_analytics_page.dart",
    "lib/screens/admin/store_management_page.dart",
    "lib/screens/admin/finance_page.dart",
    "lib/services/admin_service.dart",
    "lib/services/store_service.dart"
]

for file_path in files_to_update:
    fp = os.path.join("/Users/barankananogullari/Desktop/ibul2026 kopyası 9/ibul_app", file_path)
    if not os.path.exists(fp):
        continue

    with open(fp, "r", encoding="utf-8") as f:
        content = f.read()

    # Import order status constants if not present
    if "order_status_constants.dart" not in content:
        # Assuming there is a lib import
        if "package:flutter/material.dart" in content:
            # Need to figure out relative path. Let's just use package import
            package_import = "import 'package:ibul_app/utils/order_status_constants.dart';\n"
            content = re.sub(r"(import 'package:flutter/material.dart';)", r"\1\n" + package_import, content)

    # General replacements
    content = content.replace("== 'pending'", "== AdminApprovalStatusConstants.pending")
    content = content.replace("!= 'pending'", "!= AdminApprovalStatusConstants.pending")
    content = content.replace("== 'approved'", "== AdminApprovalStatusConstants.approved")
    content = content.replace("!= 'approved'", "!= AdminApprovalStatusConstants.approved")
    content = content.replace("== 'rejected'", "== AdminApprovalStatusConstants.rejected")
    content = content.replace("!= 'rejected'", "!= AdminApprovalStatusConstants.rejected")

    # Some switch case updates
    content = content.replace("case 'approved':", "case AdminApprovalStatusConstants.approved:")
    content = content.replace("case 'rejected':", "case AdminApprovalStatusConstants.rejected:")
    content = content.replace("case 'pending':", "case AdminApprovalStatusConstants.pending:")

    # specific map creations like 'status': 'pending'
    content = content.replace("'status': 'pending'", "'status': AdminApprovalStatusConstants.pending")
    content = content.replace("'status': 'approved'", "'status': AdminApprovalStatusConstants.approved")
    content = content.replace("'status': 'rejected'", "'status': AdminApprovalStatusConstants.rejected")

    # String parameters or hardcoded updates
    content = content.replace("('Başvurular', 'pending')", "('Başvurular', AdminApprovalStatusConstants.pending)")
    content = content.replace("('Kullanıcılar', 'approved')", "('Kullanıcılar', AdminApprovalStatusConstants.approved)")
    content = content.replace("('Red Edilenler', 'rejected')", "('Red Edilenler', AdminApprovalStatusConstants.rejected)")
    content = content.replace("_updateStatus(targetRow, 'approved')", "_updateStatus(targetRow, AdminApprovalStatusConstants.approved)")
    content = content.replace("_updateStatus(targetRow, 'rejected'", "_updateStatus(targetRow, AdminApprovalStatusConstants.rejected'")

    # finance_page.dart has 'delivered' and 'cancelled'
    if "finance_page.dart" in fp:
        content = content.replace("status == 'delivered'", "OrderStatusConstants.isEcommerceTerminal(status)")
        # Wait, if it checks "status == 'delivered' || status == 'teslim edildi'", we might just want "OrderStatusConstants.isTerminalStatus(status)"
        # Actually I will just replace 'delivered' with OrderStatusConstants.ecommerceDelivered
        content = content.replace("status == 'delivered'", "status == OrderStatusConstants.ecommerceDelivered")
        content = content.replace("status == 'cancelled'", "status == OrderStatusConstants.ecommerceCancelled")

    with open(fp, "w", encoding="utf-8") as f:
        f.write(content)

print("Admin Refactor Complete")
