import 'package:flutter/material.dart';

import '../../../app/ibul_router.dart';
import '../../../app/marketplace_paths.dart';
import 'mall_auth_session.dart';

/// Opens [child] only for a restored AVM session; otherwise sends the user to
/// `/avm/giris`. The marketplace customer session is never consulted.
class MallAuthGate extends StatefulWidget {
  const MallAuthGate({super.key, required this.child, this.session});

  final Widget child;
  final MallAuthSession? session;

  @override
  State<MallAuthGate> createState() => _MallAuthGateState();
}

class _MallAuthGateState extends State<MallAuthGate> {
  MallAuthSession get _session => widget.session ?? MallAuthSession.instance;
  var _ready = false;

  @override
  void initState() {
    super.initState();
    _session.restore().whenComplete(() {
      if (!mounted) return;
      setState(() => _ready = true);
      _redirectIfSignedOut();
    });
  }

  void _redirectIfSignedOut() {
    if (!mounted || _session.isSignedIn) return;
    debugPrint('[MALL][AUTH] gate: no AVM session -> ${MarketplacePaths.mallLogin}');
    IbulRouter.go(context, MarketplacePaths.mallLogin);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready || !_session.isSignedIn) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return widget.child;
  }
}
