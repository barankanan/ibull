fp1 = "lib/ads/presentation/pages/admin_ads_manager_content.dart"
with open(fp1, "r", encoding="utf-8") as f:
    c1 = f.read()

# If the dropdown menu items are inside a list `items: const [...]`, we should remove the `const` before `[`
c1 = c1.replace("items: const [", "items: [")
c1 = c1.replace("items: const <DropdownMenuItem<String>>[", "items: <DropdownMenuItem<String>>[")

with open(fp1, "w", encoding="utf-8") as f:
    f.write(c1)

print("Fixed admin ads")
