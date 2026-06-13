import re

# 1. Update admin_ads_manager_content.dart
fp = "/Users/barankananogullari/Desktop/ibul2026 kopyası 9/ibul_app/lib/ads/presentation/pages/admin_ads_manager_content.dart"
with open(fp, "r", encoding="utf-8") as f:
    content = f.read()

# Replace hardcoded dropdown items
content = re.sub(r"DropdownMenuItem\(value: 'approved', child: Text\('approved'\)\)", "DropdownMenuItem(value: CampaignStatus.approved.dbValue, child: Text('approved'))", content)
content = re.sub(r"DropdownMenuItem\(value: 'rejected', child: Text\('rejected'\)\)", "DropdownMenuItem(value: CampaignStatus.rejected.dbValue, child: Text('rejected'))", content)
content = re.sub(r"DropdownMenuItem\(value: 'pending', child: Text\('pending'\)\)", "DropdownMenuItem(value: CampaignReviewStatus.pending.dbValue, child: Text('pending'))", content)
content = re.sub(r"DropdownMenuItem\(value: 'approved', child: Text\('approved'\)\)", "DropdownMenuItem(value: CampaignReviewStatus.approved.dbValue, child: Text('approved'))", content) # This might overlap if they use the same string for different dropdowns, but dbValue is the same string.

# Wait, the best way is to use constants instead of strings where possible, or keep using enum.dbValue.
content = content.replace("row.reviewLabel == 'pending'", "row.reviewLabel == CampaignReviewStatus.pending.dbValue")
content = content.replace("return resolvedStatus ?? 'pending';", "return resolvedStatus ?? CampaignReviewStatus.pending.dbValue;")
content = content.replace("return 'pending';", "return CampaignReviewStatus.pending.dbValue;")
content = content.replace("return 'rejected';", "return CampaignReviewStatus.rejected.dbValue;")
content = content.replace("return 'approved';", "return CampaignReviewStatus.approved.dbValue;")

with open(fp, "w", encoding="utf-8") as f:
    f.write(content)


# 2. seller_ads_manager_content.dart
fp2 = "/Users/barankananogullari/Desktop/ibul2026 kopyası 9/ibul_app/lib/ads/presentation/pages/seller_ads_manager_content.dart"
with open(fp2, "r", encoding="utf-8") as f:
    content2 = f.read()

content2 = content2.replace("'approved',", "CampaignStatus.approved.dbValue,")
content2 = content2.replace("'rejected',", "CampaignStatus.rejected.dbValue,")
content2 = content2.replace("('approved', 'Onaylandi')", "(CampaignStatus.approved.dbValue, 'Onaylandi')")
content2 = content2.replace("('rejected', 'Reddedildi')", "(CampaignStatus.rejected.dbValue, 'Reddedildi')")

with open(fp2, "w", encoding="utf-8") as f:
    f.write(content2)


# 3. status_chip.dart
fp3 = "/Users/barankananogullari/Desktop/ibul2026 kopyası 9/ibul_app/lib/ads/presentation/widgets/status_chip.dart"
with open(fp3, "r", encoding="utf-8") as f:
    content3 = f.read()

# Using CampaignStatus dbValues
content3 = content3.replace("case 'approved':", "case 'approved': // CampaignStatus.approved.dbValue")
content3 = content3.replace("case 'pending':", "case 'pending': // CampaignStatus.pendingReview.dbValue")
content3 = content3.replace("case 'rejected':", "case 'rejected': // CampaignStatus.rejected.dbValue")

with open(fp3, "w", encoding="utf-8") as f:
    f.write(content3)


# 4. ad_wallet_helper.dart
fp4 = "/Users/barankananogullari/Desktop/ibul2026 kopyası 9/ibul_app/lib/ads/helpers/ad_wallet_helper.dart"
with open(fp4, "r", encoding="utf-8") as f:
    content4 = f.read()

content4 = content4.replace("String status = 'approved',", "String status = 'approved', // Default approved status")
content4 = content4.replace("record.sourceStatus == 'pending'", "record.sourceStatus == CampaignReviewStatus.pending.dbValue")
content4 = content4.replace("record.sourceStatus == 'approved'", "record.sourceStatus == CampaignStatus.approved.dbValue")
content4 = content4.replace("record.sourceStatus == 'refunded'", "record.sourceStatus == WalletTransactionStatus.refunded.dbValue")
content4 = content4.replace("item.sourceStatus == 'approved'", "item.sourceStatus == CampaignStatus.approved.dbValue")

if "import '../enums/ad_enums.dart';" not in content4:
    content4 = "import '../enums/ad_enums.dart';\n" + content4

with open(fp4, "w", encoding="utf-8") as f:
    f.write(content4)

print("Done Ads Refactor")
