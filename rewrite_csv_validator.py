import re

PATH = 'ibul_app/lib/screens/seller/product_management/bulk_product_import_validator.dart'

with open(PATH, 'r') as f:
    content = f.read()

# Add to imports if needed, but it already has dart:convert
# Add reading faq_json
faq_read = """
    final String faqJson = readBulkImportField(values, 'faq_json');
    if (faqJson.isNotEmpty) {
      try {
        final dynamic parsed = jsonDecode(faqJson);
        if (parsed is! List) {
          errors.add('faq_json geçerli JSON dizisi olmalı');
        }
      } catch (_) {
        errors.add('faq_json geçerli JSON olmalı');
      }
    }
"""

content = content.replace("final String highlightsJson = readBulkImportField(values, 'highlights_json');",
"""
    final String highlightsJson = readBulkImportField(values, 'highlights_json');
""" + faq_read)

faq_parse = """
    final List<Map<String, String>> faqs = _parseFaqs(readBulkImportField(values, 'faq_json'));
"""

content = content.replace("final List<String> highlightInfos = parseBulkImportHighlights(values);",
"""final List<String> highlightInfos = parseBulkImportHighlights(values);
""" + faq_parse)

content = content.replace("highlightInfos: highlightInfos,",
"""highlightInfos: highlightInfos,
        faqs: faqs,""")

faq_func = """
  List<Map<String, String>> _parseFaqs(String faqJson) {
    if (faqJson.isEmpty) return const <Map<String, String>>[];
    try {
      final dynamic parsed = jsonDecode(faqJson);
      if (parsed is List) {
        return parsed
            .whereType<Map>()
            .map((Map item) => item.map((k, v) => MapEntry(k.toString(), v.toString())))
            .toList(growable: false);
      }
    } catch (_) {}
    return const <Map<String, String>>[];
  }
"""

content = content.replace("List<Map<String, dynamic>> _parseVariants(String variantsJson) {",
faq_func + """
  List<Map<String, dynamic>> _parseVariants(String variantsJson) {""")

with open(PATH, 'w') as f:
    f.write(content)
