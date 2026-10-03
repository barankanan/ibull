import 'package:flutter/material.dart';

import '../models/blog_content.dart';
import '../widgets/blog_theme.dart';
import 'blog_block_editor.dart';

/// Column section editor. Inner lists do not offer nested column sections.
class BlogColumnsEditor extends StatelessWidget {
  const BlogColumnsEditor({
    super.key,
    required this.block,
    required this.onChanged,
    this.onUndo,
  });

  final BlogBlock block;
  final VoidCallback onChanged;
  final void Function(VoidCallback undo)? onUndo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Sütun sayısı', style: BlogTheme.metaStyle),
            const SizedBox(width: 10),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 2, label: Text('2')),
                ButtonSegment(value: 3, label: Text('3')),
                ButtonSegment(value: 4, label: Text('4')),
              ],
              selected: {block.columns.length},
              showSelectedIcon: false,
              onSelectionChanged: (value) {
                final count = value.first;
                while (block.columns.length < count) {
                  block.columns.add(BlogColumn());
                }
                if (block.columns.length > count) {
                  // Content of removed columns moves into the last kept one.
                  final removed = block.columns.sublist(count);
                  block.columns.removeRange(count, block.columns.length);
                  for (final column in removed) {
                    block.columns.last.blocks.addAll(column.blocks);
                  }
                }
                onChanged();
              },
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Mobilde sütunlar soldan sağa sırayla alt alta gösterilir.',
          style: TextStyle(fontSize: 12, color: BlogTheme.muted),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final sideBySide = constraints.maxWidth >= block.columns.length * 240;
            final editors = [
              for (var i = 0; i < block.columns.length; i++)
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBFAFE),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: BlogTheme.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Sütun ${i + 1}', style: BlogTheme.chipStyle),
                      const SizedBox(height: 6),
                      BlogBlockListEditor(
                        blocks: block.columns[i].blocks,
                        allowColumns: false,
                        onUndo: onUndo,
                        onShift: (moved, direction) {
                          final target = i + direction;
                          if (target < 0 || target >= block.columns.length) return;
                          block.columns[i].blocks.remove(moved);
                          block.columns[target].blocks.add(moved);
                          onChanged();
                        },
                        onChanged: onChanged,
                      ),
                    ],
                  ),
                ),
            ];
            if (!sideBySide) return Column(children: editors);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < editors.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(child: editors[i]),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}
