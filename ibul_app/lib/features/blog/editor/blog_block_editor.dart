import 'package:flutter/material.dart';

import '../models/blog_content.dart';
import '../widgets/blog_theme.dart';
import 'blog_block_fields.dart';
import 'blog_block_ops.dart';
import 'blog_editor_controls.dart';

/// Ordered list of block editors with move / duplicate / delete actions.
class BlogBlockListEditor extends StatefulWidget {
  const BlogBlockListEditor({
    super.key,
    required this.blocks,
    required this.onChanged,
    this.allowColumns = true,
    this.onUndo,
    this.onShift,
  });

  final List<BlogBlock> blocks;
  final VoidCallback onChanged;
  final bool allowColumns;
  final void Function(VoidCallback undo)? onUndo;

  /// Moves a block into the previous (-1) or next (+1) column, when nested.
  final void Function(BlogBlock block, int direction)? onShift;

  @override
  State<BlogBlockListEditor> createState() => _BlogBlockListEditorState();
}

class _BlogBlockListEditorState extends State<BlogBlockListEditor> {
  String? _focusId;

  List<BlogBlock> get blocks => widget.blocks;

  void _changed() => widget.onChanged();

  void _remember(int index) {
    final copy = blocks[index].toJson();
    widget.onUndo?.call(() {
      if (index <= blocks.length) {
        blocks.insert(index, BlogBlock.fromJson(copy)!);
      }
      _changed();
    });
  }

  void _move(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= blocks.length) return;
    final block = blocks.removeAt(index);
    blocks.insert(target, block);
    _changed();
  }

  void _add(BlogBlock block, int index) {
    blocks.insert(index, block);
    setState(() => _focusId = block.id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _focusId == block.id) setState(() => _focusId = null);
    });
    _changed();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          _BlockFrame(
            key: ValueKey('${blocks[i].id}-${blocks[i].type.name}'),
            block: blocks[i],
            nested: !widget.allowColumns,
            autofocus: blocks[i].id == _focusId,
            canMoveUp: i > 0,
            canMoveDown: i < blocks.length - 1,
            onMoveUp: () => _move(i, -1),
            onMoveDown: () => _move(i, 1),
            onDuplicate: () {
              blocks.insert(i + 1, blocks[i].duplicate());
              _changed();
            },
            onDelete: () {
              _remember(i);
              blocks.removeAt(i);
              _changed();
            },
            onConvert: convertibleBlockTypes.contains(blocks[i].type)
                ? (next) {
                    _remember(i);
                    blocks[i] = convertBlock(blocks[i], next);
                    setState(() => _focusId = blocks[i].id);
                    _changed();
                  }
                : null,
            onShift: widget.onShift == null
                ? null
                : (direction) => widget.onShift!(blocks[i], direction),
            onUndo: widget.onUndo,
            onChanged: _changed,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: BlogAddBlockButton(
              allowColumns: widget.allowColumns,
              compact: true,
              onAdd: (block) => _add(block, i + 1),
            ),
          ),
        ],
        if (blocks.isEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: BlogAddBlockButton(
              allowColumns: widget.allowColumns,
              compact: !widget.allowColumns,
              onAdd: (block) => _add(block, 0),
            ),
          ),
      ],
    );
  }
}

class _BlockFrame extends StatelessWidget {
  const _BlockFrame({
    super.key,
    required this.block,
    required this.nested,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDuplicate,
    required this.onDelete,
    required this.onChanged,
    this.onConvert,
    this.onShift,
    this.onUndo,
    this.autofocus = false,
  });

  final BlogBlock block;
  final bool nested;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final VoidCallback onChanged;
  final ValueChanged<BlogBlockType>? onConvert;
  final ValueChanged<int>? onShift;
  final void Function(VoidCallback undo)? onUndo;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final meta = blogBlockMeta[block.type]!;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: BlogTheme.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(meta.$2, size: 16, color: BlogTheme.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  block.type == BlogBlockType.columns
                      ? '${block.columns.length} sütunlu bölüm'
                      : meta.$1,
                  overflow: TextOverflow.ellipsis,
                  style: BlogTheme.metaStyle.copyWith(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onConvert != null)
                        PopupMenuButton<BlogBlockType>(
                          tooltip: 'Tür değiştir',
                          icon: const Icon(Icons.swap_horiz, size: 18),
                          onSelected: onConvert,
                          itemBuilder: (context) => [
                            for (final type in convertibleBlockTypes)
                              if (type != block.type)
                                PopupMenuItem(
                                  value: type,
                                  child: Text(blogBlockMeta[type]!.$1),
                                ),
                          ],
                        ),
                      if (onShift != null) ...[
                        _tool(Icons.west, 'Önceki sütuna', () => onShift!(-1)),
                        _tool(Icons.east, 'Sonraki sütuna', () => onShift!(1)),
                      ],
                      _tool(Icons.arrow_upward, 'Yukarı taşı', canMoveUp ? onMoveUp : null),
                      _tool(Icons.arrow_downward, 'Aşağı taşı', canMoveDown ? onMoveDown : null),
                      _tool(Icons.copy_outlined, 'Çoğalt', onDuplicate),
                      _tool(Icons.delete_outline, 'Sil', onDelete),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: BlogBlockFields(
              block: block,
              autofocus: autofocus,
              onUndo: onUndo,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tool(IconData icon, String tooltip, VoidCallback? onPressed) =>
      IconButton(
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        iconSize: 18,
        onPressed: onPressed,
        icon: Icon(icon),
      );
}

/// Field editors per block type. Writes straight into [block].
