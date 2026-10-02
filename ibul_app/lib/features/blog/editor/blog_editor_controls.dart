import 'package:flutter/material.dart';

import '../models/blog_content.dart';
import '../widgets/blog_theme.dart';

const Map<BlogBlockType, (String, IconData)> blogBlockMeta = {
  BlogBlockType.paragraph: ('Paragraf', Icons.notes),
  BlogBlockType.heading: ('Alt başlık', Icons.title),
  BlogBlockType.list: ('Liste', Icons.format_list_bulleted),
  BlogBlockType.quote: ('Alıntı', Icons.format_quote),
  BlogBlockType.image: ('Görsel', Icons.image_outlined),
  BlogBlockType.video: ('Video', Icons.smart_display_outlined),
  BlogBlockType.button: ('Buton', Icons.smart_button_outlined),
  BlogBlockType.divider: ('Ayırıcı', Icons.horizontal_rule),
  BlogBlockType.columns: ('Sütun bölümü', Icons.view_column_outlined),
};

/// "+ Blok ekle" menu. Column sections are offered only at the top level.
class BlogAddBlockButton extends StatelessWidget {
  const BlogAddBlockButton({
    super.key,
    required this.onAdd,
    this.allowColumns = true,
    this.compact = false,
  });

  final void Function(BlogBlock block) onAdd;
  final bool allowColumns;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<(BlogBlockType, int)>(
      tooltip: 'Blok ekle',
      onSelected: (choice) =>
          onAdd(BlogBlock.create(choice.$1, columnCount: choice.$2)),
      itemBuilder: (_) => [
        for (final entry in blogBlockMeta.entries)
          if (entry.key != BlogBlockType.columns)
            PopupMenuItem(
              value: (entry.key, 0),
              child: ListTile(
                dense: true,
                leading: Icon(entry.value.$2),
                title: Text(entry.value.$1),
              ),
            ),
        if (allowColumns)
          for (final count in const [2, 3, 4])
            PopupMenuItem(
              value: (BlogBlockType.columns, count),
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.view_column_outlined),
                title: Text('$count sütunlu bölüm'),
              ),
            ),
      ],
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 16,
          vertical: compact ? 6 : 12,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: BlogTheme.line),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, color: BlogTheme.accent, size: 20),
            const SizedBox(width: 6),
            Text(
              'Blok ekle',
              style: TextStyle(
                color: BlogTheme.accent,
                fontWeight: FontWeight.w700,
                fontSize: compact ? 13 : 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bold / italic / link buttons that wrap the current selection in markup.
class BlogInlineToolbar extends StatelessWidget {
  const BlogInlineToolbar({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  void _wrap(String before, String after) {
    final value = controller.value;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : value.text.length;
    final end = selection.isValid ? selection.end : value.text.length;
    final selected = value.text.substring(start, end);
    final replacement = '$before$selected$after';
    final text = value.text.replaceRange(start, end, replacement);
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(
        offset: start + before.length + selected.length,
      ),
    );
    onChanged(text);
  }

  Future<void> _link(BuildContext context) async {
    final urlController = TextEditingController(text: 'https://');
    final url = await showDialog<String>(
      context: context,
      builder: (context) {
        String? error;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Bağlantı ekle'),
            content: TextField(
              controller: urlController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Adres (https://, mailto: veya /)',
                errorText: error,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                onPressed: () {
                  final value = urlController.text.trim();
                  if (value.isEmpty || !BlogUrlPolicy.isSafe(value)) {
                    setState(() => error = 'Güvenli bir adres girin.');
                    return;
                  }
                  Navigator.pop(context, value);
                },
                child: const Text('Ekle'),
              ),
            ],
          ),
        );
      },
    );
    urlController.dispose();
    if (url == null) return;
    final selection = controller.selection;
    final hasText = selection.isValid && selection.start != selection.end;
    _wrap('[${hasText ? '' : 'bağlantı metni'}', ']($url)');
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 2,
      children: [
        IconButton(
          tooltip: 'Kalın (**metin**)',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.format_bold, size: 18),
          onPressed: () => _wrap('**', '**'),
        ),
        IconButton(
          tooltip: 'İtalik (*metin*)',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.format_italic, size: 18),
          onPressed: () => _wrap('*', '*'),
        ),
        IconButton(
          tooltip: 'Bağlantı',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.link, size: 18),
          onPressed: () => _link(context),
        ),
      ],
    );
  }
}
