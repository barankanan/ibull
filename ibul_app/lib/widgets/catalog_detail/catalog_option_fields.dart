import 'package:flutter/material.dart';

/// Read-only listing fields using the product "Ürün Seçenekleri" chip language.
class CatalogOptionFields extends StatelessWidget {
  const CatalogOptionFields({
    super.key,
    required this.fields,
    this.title = 'Ürün Seçenekleri',
    this.emptyLabel = 'Bu ürün için seçenek bulunmuyor.',
    this.webTitle = true,
  });

  final List<(String, String)> fields;
  final String title;
  final String emptyLabel;
  final bool webTitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: webTitle ? 18 : 16,
            fontWeight: webTitle ? FontWeight.w500 : FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        if (fields.isEmpty) ...[
          const SizedBox(height: 8),
          Text(
            emptyLabel,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ] else ...[
          const SizedBox(height: 12),
          for (var i = 0; i < fields.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            _OptionGroup(label: fields[i].$1, value: fields[i].$2),
          ],
        ],
      ],
    );
  }
}

class _OptionGroup extends StatelessWidget {
  const _OptionGroup({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '$label:',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF673AB7), width: 2),
              ),
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF673AB7),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
