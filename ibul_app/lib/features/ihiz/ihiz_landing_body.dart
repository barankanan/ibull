import 'package:flutter/material.dart';

import 'sections/ihiz_business_section.dart';
import 'sections/ihiz_courier_section.dart';
import 'sections/ihiz_feature_section.dart';
import 'sections/ihiz_hero_section.dart';
import 'sections/ihiz_how_it_works_section.dart';
import 'sections/ihiz_package_send_section.dart';
import 'sections/ihiz_tracking_section.dart';
import 'theme/ihiz_brand.dart';
import 'widgets/ihiz_landing_widgets.dart';

/// Profesyonel İHIZ landing — İHIZ shell (header/footer) içinde.
class IhizLandingBody extends StatelessWidget {
  const IhizLandingBody({
    super.key,
    required this.onCourierApply,
    required this.onBusinessJoin,
    required this.onBindBusiness,
    required this.onPackageSend,
    required this.onSubmitTracking,
    required this.howItWorksKey,
    this.trackingKey,
    this.courierKey,
    this.businessKey,
  });

  final VoidCallback onCourierApply;
  final VoidCallback onBusinessJoin;
  final ValueChanged<String> onBindBusiness;
  final VoidCallback onPackageSend;
  final ValueChanged<String> onSubmitTracking;
  final GlobalKey howItWorksKey;
  final GlobalKey? trackingKey;
  final GlobalKey? courierKey;
  final GlobalKey? businessKey;

  void _scrollToTracking() {
    final ctx = trackingKey?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: IhizBrand.surface,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: IhizBrand.contentMaxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IhizSectionPadding(
                top: 12,
                bottom: 0,
                child: IhizHeroSection(
                  onTrack: _scrollToTracking,
                ),
              ),
              const IhizSectionPadding(
                child: IhizFeatureSection(),
              ),
              IhizSectionPadding(
                child: KeyedSubtree(
                  key: howItWorksKey,
                  child: const IhizHowItWorksSection(),
                ),
              ),
              IhizSectionPadding(
                child: KeyedSubtree(
                  key: courierKey,
                  child: IhizCourierSection(onApply: onCourierApply),
                ),
              ),
              IhizSectionPadding(
                child: KeyedSubtree(
                  key: businessKey,
                  child: IhizBusinessSection(
                    onJoin: onBusinessJoin,
                    onBindSerial: onBindBusiness,
                  ),
                ),
              ),
              IhizSectionPadding(
                child: IhizPackageSendSection(onSend: onPackageSend),
              ),
              IhizSectionPadding(
                bottom: 40,
                child: KeyedSubtree(
                  key: trackingKey,
                  child: IhizTrackingSection(onSubmit: onSubmitTracking),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
