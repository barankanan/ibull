import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/app_state.dart';
import '../../../core/auth/customer_login_gate.dart';
import '../../../core/interaction_feedback.dart';
import '../domain/vehicle_compare_feedback.dart';
import '../models/vehicle_listing.dart';
import '../services/vehicle_service.dart';

class VehicleCardActionOverlay extends StatefulWidget {
  const VehicleCardActionOverlay({super.key, required this.listing});

  final VehicleListing listing;

  @override
  State<VehicleCardActionOverlay> createState() =>
      _VehicleCardActionOverlayState();
}

class _VehicleCardActionOverlayState extends State<VehicleCardActionOverlay> {
  bool _favorite = false;
  bool _busy = false;

  bool _isLoggedIn() {
    try {
      return context.read<AppState>().isLoggedIn;
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_hydrateFavorite());
    });
  }

  Future<void> _hydrateFavorite() async {
    try {
      if (!_isLoggedIn()) return;
      final ids = await VehicleService.instance.favorites.listingIds();
      if (!mounted) return;
      setState(() => _favorite = ids.contains(widget.listing.id));
    } catch (_) {}
  }

  Future<void> _toggleFavorite() async {
    if (_busy) return;
    if (!_isLoggedIn()) {
      final loggedIn = await _askLogin();
      if (!mounted || !loggedIn) return;
      await _favoriteAfterLogin();
      return;
    }
    InteractionFeedback.forInteraction(InteractionFeedbackType.favorite);
    final previous = _favorite;
    setState(() {
      _busy = true;
      _favorite = !previous;
    });
    try {
      final next = await VehicleService.instance.favorites.toggle(
        widget.listing,
      );
      if (mounted) setState(() => _favorite = next);
    } catch (_) {
      if (mounted) setState(() => _favorite = previous);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _favoriteAfterLogin() async {
    InteractionFeedback.forInteraction(InteractionFeedbackType.favorite);
    setState(() {
      _busy = true;
      _favorite = true;
    });
    try {
      final next = await VehicleService.instance.favorites.ensureFavorite(
        widget.listing,
      );
      if (mounted) setState(() => _favorite = next);
    } catch (_) {
      if (mounted) setState(() => _favorite = false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _askLogin() async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Giriş Yap'),
        content: const Text('Bu işlemi yapmak için giriş yapmanız gerekiyor.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Giriş Yap'),
          ),
        ],
      ),
    );
    if (proceed != true || !mounted) return false;
    try {
      return await CustomerLoginGate.open(context);
    } catch (_) {
      return false;
    }
  }

  void _openCompare() {
    VehicleCompareFeedback.open(context, widget.listing);
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 4,
      right: 4,
      child: Column(
        children: [
          _CircleAction(
            key: const ValueKey('vehicle-card-favorite'),
            icon: _favorite ? Icons.favorite : Icons.favorite_border,
            color: _favorite ? Colors.red : Colors.grey.shade400,
            onTap: _toggleFavorite,
          ),
          const SizedBox(height: 6),
          _CircleAction(
            key: const ValueKey('vehicle-card-compare'),
            icon: Icons.compare_arrows,
            color: Colors.grey.shade400,
            onTap: _openCompare,
          ),
        ],
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    super.key,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {},
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }
}
