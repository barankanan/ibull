fp = "/Users/barankananogullari/Desktop/ibul2026 kopyası 9/ibul_app/lib/screens/admin/support_complaints_page.dart"
with open(fp, "r", encoding="utf-8") as f:
    c = f.read()

c = c.replace("?? 'pending'", "?? AdminApprovalStatusConstants.pending")
with open(fp, "w", encoding="utf-8") as f:
    f.write(c)

print("Support Fixed")
