import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/restaurant_ops_models.dart';

/// Manages the "Undo last action" capability for the garson flow.
///
/// After a destructive/important action (e.g., submitting a new order,
/// editing an order, closing a table) the caller pushes a [GarsonUndoAction].
/// The controller holds it for up to [GarsonUndoAction.ttl] (default 30 s).
///
/// Use [UndoActionBanner] to render the live countdown banner.
class GarsonUndoController extends ChangeNotifier {
  GarsonUndoAction? _pendingAction;
  Timer? _ticker;

  GarsonUndoAction? get pendingAction => _pendingAction;

  bool get hasPendingAction =>
      _pendingAction != null && !_pendingAction!.isExpired;

  /// Registers a new undoable action.
  /// Any previously registered action is silently discarded.
  void push(GarsonUndoAction action) {
    _cancel();
    _pendingAction = action;
    // Tick every second so the countdown stays live.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_pendingAction == null || _pendingAction!.isExpired) {
        _cancel();
      }
      notifyListeners();
    });
    notifyListeners();
  }

  /// Executes the undo function and clears the pending action.
  Future<void> undo() async {
    final action = _pendingAction;
    _cancel();
    if (action != null && !action.isExpired) {
      await action.undo();
    }
  }

  /// Discards the pending action without undoing.
  void dismiss() => _cancel();

  void _cancel() {
    _ticker?.cancel();
    _ticker = null;
    _pendingAction = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

/// A Material banner widget that shows a live countdown undo option.
///
/// ```dart
/// UndoActionBanner(controller: _undoController)
/// ```
///
/// Renders nothing when there is no pending action.
class UndoActionBanner extends StatefulWidget {
  const UndoActionBanner({
    super.key,
    required this.controller,
    this.onUndo,
  });

  final GarsonUndoController controller;

  /// Optional extra callback after the undo action completes.
  final VoidCallback? onUndo;

  @override
  State<UndoActionBanner> createState() => _UndoActionBannerState();
}

class _UndoActionBannerState extends State<UndoActionBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    ));
    widget.controller.addListener(_onControllerChanged);
    if (widget.controller.hasPendingAction) {
      _animController.forward();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _animController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    if (widget.controller.hasPendingAction) {
      _animController.forward();
    } else {
      _animController.reverse();
    }
    setState(() {});
  }

  Future<void> _handleUndo() async {
    await widget.controller.undo();
    widget.onUndo?.call();
  }

  @override
  Widget build(BuildContext context) {
    final action = widget.controller.pendingAction;
    if (action == null) return const SizedBox.shrink();

    final remaining = action.remaining.inSeconds;
    final progress = remaining / action.ttl.inSeconds;

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Circular countdown ring
            SizedBox(
              width: 32,
              height: 32,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    strokeWidth: 2.5,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFFFBBF24),
                    ),
                  ),
                  Text(
                    '$remaining',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    action.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Geri almak için dokun',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _handleUndo,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBBF24),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Geri Al',
                  style: TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: widget.controller.dismiss,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: Colors.white54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows a duplicate-product warning snackbar.
///
/// Call when the same product is added within [_kDuplicateWindow] seconds.
void showDuplicateProductWarning(
  BuildContext context, {
  required String productName,
  required VoidCallback onKeepBoth,
  required VoidCallback onIncreaseQty,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 6),
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Color(0xFFFBBF24), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '"$productName" zaten eklendi.',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
              maxLines: 2,
            ),
          ),
        ],
      ),
      action: SnackBarAction(
        label: 'Adedi Artır',
        textColor: const Color(0xFFFBBF24),
        onPressed: onIncreaseQty,
      ),
    ),
  );
}
