import 'package:flutter/material.dart';

/// Wraps a product card with swipe-reveal actions for the waiter screen.
///
/// Swipe Contract
/// ══════════════
/// ← Left  (endToStart)  → "Düzenle" (purple)  — triggers [onEdit], card snaps back.
/// → Right (startToEnd)  → "Çıkar"   (red)      — triggers [onQuickRemove], card snaps back.
///
/// The underlying card is NEVER physically dismissed: both confirmDismiss callbacks
/// always return false so the widget stays in the list. The parent is responsible
/// for updating state in the callbacks so the visual indicators on the card refresh.
///
/// Use [enabled] to disable swipe gestures when the product is out of stock
/// or when no draft action is applicable.
class SwipeableProductCard extends StatelessWidget {
  const SwipeableProductCard({
    super.key,
    required this.productKey,
    required this.child,
    required this.onEdit,
    required this.onQuickRemove,
    this.isInDraft = false,
    this.enabled = true,
  });

  /// Unique key used by Dismissible — should be the product ID.
  final String productKey;

  /// The product card content.
  final Widget child;

  /// Called when the user swipes left (endToStart). Open a configure dialog.
  final VoidCallback onEdit;

  /// Called when the user swipes right (startToEnd). Remove from draft.
  final VoidCallback onQuickRemove;

  /// Whether this product is currently in the draft. Used for styling the
  /// right-swipe background.
  final bool isInDraft;

  /// Set to false to disable swipe gestures entirely.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    return Dismissible(
      key: ValueKey('swipeable_$productKey'),
      direction: DismissDirection.horizontal,
      // Right-swipe background: remove-from-draft (red)
      background: _SwipeBackground(
        alignment: Alignment.centerLeft,
        color: isInDraft ? const Color(0xFFDC2626) : const Color(0xFF9CA3AF),
        icon: Icons.remove_shopping_cart_rounded,
        label: isInDraft ? 'Çıkar' : 'Taslakta Yok',
        labelRight: false,
      ),
      // Left-swipe background: edit / configure (purple)
      secondaryBackground: const _SwipeBackground(
        alignment: Alignment.centerRight,
        color: Color(0xFF7A2FF4),
        icon: Icons.tune_rounded,
        label: 'Düzenle',
        labelRight: true,
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Right swipe → remove from draft.
          onQuickRemove();
        } else {
          // Left swipe → open configure dialog.
          onEdit();
        }
        // Always return false: we never actually dismiss the card from the list.
        return false;
      },
      child: child,
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.alignment,
    required this.color,
    required this.icon,
    required this.label,
    required this.labelRight,
  });

  final AlignmentGeometry alignment;
  final Color color;
  final IconData icon;
  final String label;
  final bool labelRight;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: labelRight
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: _labelStyle),
                const SizedBox(width: 8),
                Icon(icon, color: Colors.white, size: 20),
              ],
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(label, style: _labelStyle),
              ],
            ),
    );
  }

  static const TextStyle _labelStyle = TextStyle(
    color: Colors.white,
    fontSize: 13,
    fontWeight: FontWeight.w700,
  );
}
