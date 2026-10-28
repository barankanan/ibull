import re

PATH = 'ibul_app/lib/screens/seller/product_management/bulk_product_import_service.dart'

with open(PATH, 'r') as f:
    content = f.read()

content = content.replace("additionalInfo: highlightItems.isEmpty ? null : highlightItems.join('\\n'),",
"""additionalInfo: highlightItems.isEmpty ? null : highlightItems.join('\\n'),
      faq: candidate.faqs.isEmpty ? null : candidate.faqs,""")

with open(PATH, 'w') as f:
    f.write(content)
