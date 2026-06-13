import re

# 1. admin_ads_manager_content.dart
fp1 = "lib/ads/presentation/pages/admin_ads_manager_content.dart"
with open(fp1, "r", encoding="utf-8") as f:
    c1 = f.read()
c1 = c1.replace("DropdownMenuItem(value: CampaignStatus.approved.dbValue,", "DropdownMenuItem<String>(value: CampaignStatus.approved.dbValue,")
c1 = c1.replace("DropdownMenuItem(value: CampaignStatus.rejected.dbValue,", "DropdownMenuItem<String>(value: CampaignStatus.rejected.dbValue,")
c1 = c1.replace("DropdownMenuItem(value: CampaignReviewStatus.pending.dbValue,", "DropdownMenuItem<String>(value: CampaignReviewStatus.pending.dbValue,")
c1 = c1.replace("DropdownMenuItem(value: CampaignReviewStatus.approved.dbValue,", "DropdownMenuItem<String>(value: CampaignReviewStatus.approved.dbValue,")
c1 = re.sub(r"const\s+DropdownMenuItem", "DropdownMenuItem", c1)
with open(fp1, "w", encoding="utf-8") as f:
    f.write(c1)

# 2. seller_ads_manager_content.dart
fp2 = "lib/ads/presentation/pages/seller_ads_manager_content.dart"
with open(fp2, "r", encoding="utf-8") as f:
    c2 = f.read()
# (CampaignStatus.approved.dbValue, 'Onaylandi') might be inside a const list.
c2 = c2.replace("const [", "[")
c2 = c2.replace("const <", "<")
# It's probably in `const statuses = [ ... ]`
c2 = re.sub(r"const\s+statuses\s*=", "final statuses =", c2)
with open(fp2, "w", encoding="utf-8") as f:
    f.write(c2)

# 3. Unused imports
for p in ["lib/screens/admin/data_analytics_page.dart", "lib/screens/admin/store_application_detail_dialog.dart"]:
    with open(p, "r", encoding="utf-8") as f:
        c = f.read()
    c = c.replace("import 'package:ibul_app/utils/order_status_constants.dart';\n", "")
    with open(p, "w", encoding="utf-8") as f:
        f.write(c)

# 4. ihiz_application_approval_page syntax error
fp4 = "lib/screens/admin/ihiz_application_approval_page.dart"
with open(fp4, "r", encoding="utf-8") as f:
    c4 = f.read()
c4 = c4.replace("AdminApprovalStatusConstants.rejected'", "AdminApprovalStatusConstants.rejected")
with open(fp4, "w", encoding="utf-8") as f:
    f.write(c4)

# 5. unreachable switch cases in order_detail_page.dart
fp5 = "lib/screens/order_detail_page.dart"
with open(fp5, "r", encoding="utf-8") as f:
    c5 = f.read()
# We have duplicate cases because refunded and returned both mapped to returns.
# Let's remove duplicate lines. We can just run a quick clean up.
lines = c5.split('\n')
new_lines = []
seen_cases = set()
in_switch = False
for line in lines:
    if "switch " in line:
        in_switch = True
        seen_cases = set()
    if "case OrderStatusConstants.ecommerceReturns:" in line:
        if "case OrderStatusConstants.ecommerceReturns:" in seen_cases:
            continue # skip duplicate
        else:
            seen_cases.add("case OrderStatusConstants.ecommerceReturns:")
    if "case OrderStatusConstants.ecommerceCancelled:" in line:
        if "case OrderStatusConstants.ecommerceCancelled:" in seen_cases:
            continue # skip duplicate
        else:
            seen_cases.add("case OrderStatusConstants.ecommerceCancelled:")
    if "break;" in line or "return " in line:
        seen_cases = set() # reset after block
    new_lines.append(line)

with open(fp5, "w", encoding="utf-8") as f:
    f.write('\n'.join(new_lines))

# 6. missing imports in services
for p in ["lib/services/admin_service.dart", "lib/services/store_service.dart"]:
    with open(p, "r", encoding="utf-8") as f:
        c = f.read()
    if "order_status_constants.dart" not in c:
        c = "import 'package:ibul_app/utils/order_status_constants.dart';\n" + c
    with open(p, "w", encoding="utf-8") as f:
        f.write(c)

print("Fixes applied")
