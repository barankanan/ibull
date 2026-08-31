import 'package:flutter/material.dart';

import '../app/ibul_router.dart';
import '../core/web_seo.dart';
import '../features/ihiz/apply/ihiz_courier_apply_page.dart';
import '../features/ihiz/business/ihiz_business_link_page.dart';
import '../features/ihiz/courier/ihiz_courier_login_page.dart';
import '../features/ihiz/delivery/ihiz_route_paths.dart';
import '../features/ihiz/ihiz_landing_body.dart';
import '../features/ihiz/send/ihiz_package_send_page.dart';
import '../features/ihiz/shell/ihiz_footer.dart';
import '../features/ihiz/shell/ihiz_header.dart';
import '../features/ihiz/shell/ihiz_shell.dart';

export '../features/ihiz/tracking/ihiz_tracking_page.dart';
export '../features/ihiz/send/ihiz_package_send_page.dart';
export '../features/ihiz/business/ihiz_business_link_page.dart';
class IhizCourierPage extends StatefulWidget {
  const IhizCourierPage({super.key});

  @override
  State<IhizCourierPage> createState() => _IhizCourierPageState();
}

class _IhizCourierPageState extends State<IhizCourierPage> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _howItWorksKey = GlobalKey();
  final GlobalKey _trackingKey = GlobalKey();
  final GlobalKey _courierKey = GlobalKey();
  final GlobalKey _businessKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    setSeoMeta(
      title: 'İHIZ | Hızlı Teslimat Platformu',
      description:
          'Mağazalardan müşterilere hızlı, güvenli ve takip edilebilir teslimat.',
      keywords: const ['ihiz', 'ihız', 'kurye', 'teslimat'],
      canonicalPath: '/ihiz',
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
  }

  void _openLogin() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const IhizCourierLoginPage(),
      ),
    );
  }

  void _openCourierApply() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const IhizCourierApplyPage(),
      ),
    );
  }

  void _openBusinessJoin([String? serial]) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => IhizBusinessLinkPage(initialSerial: serial),
      ),
    );
  }

  void _openPackageSend() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const IhizPackageSendPage()),
    );
  }

  void _openTracking(String code) {
    IbulRouter.push(context, IhizRoutePaths.track(code));
  }

  void _returnToIbul() {
    IbulRouter.go(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    return IhizShell(
      controller: _scrollController,
      header: IhizHeader(
        onHome: _scrollToTop,
        onHowItWorks: () => _scrollTo(_howItWorksKey),
        onTracking: () => _scrollTo(_trackingKey),
        onBusinessJoin: _openBusinessJoin,
        onLogin: _openLogin,
        onCourierApply: _openCourierApply,
      ),
      body: IhizLandingBody(
        onLogin: _openLogin,
        onCourierApply: _openCourierApply,
        onBusinessJoin: _openBusinessJoin,
        onBindBusiness: (serial) => _openBusinessJoin(serial),
        onPackageSend: _openPackageSend,
        onSubmitTracking: _openTracking,
        howItWorksKey: _howItWorksKey,
        trackingKey: _trackingKey,
        courierKey: _courierKey,
        businessKey: _businessKey,
      ),
      footer: IhizFooter(
        onHome: _scrollToTop,
        onHowItWorks: () => _scrollTo(_howItWorksKey),
        onCourierApply: _openCourierApply,
        onBusinessJoin: _openBusinessJoin,
        onTracking: () => _scrollTo(_trackingKey),
        onReturnToIbul: _returnToIbul,
      ),
    );
  }
}
