import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final schema = File(
    'supabase/migrations/20260916_coupon_engine_schema.sql',
  ).readAsStringSync();
  final rls = File(
    'supabase/migrations/20260916_coupon_engine_rls.sql',
  ).readAsStringSync();
  final rpc = File(
    'supabase/migrations/20260916_coupon_engine_rpc.sql',
  ).readAsStringSync();
  final wheel = File(
    'supabase/migrations/20260916_coupon_engine_wheel.sql',
  ).readAsStringSync();
  final wheelOps = File(
    'supabase/migrations/20260923_reward_wheel_ops.sql',
  ).readAsStringSync();
  final wheelElig = File(
    'supabase/migrations/20260924_reward_wheel_eligibility.sql',
  ).readAsStringSync();

  test('coupon engine keeps campaigns and user coupons separate', () {
    expect(schema, contains('create table if not exists public.coupon_campaigns'));
    expect(schema, contains('create table if not exists public.user_coupons'));
    expect(schema, contains('create table if not exists public.reward_wheel_spins'));
    expect(schema, isNot(contains('drop table public.campaigns')));
    expect(schema, isNot(contains('drop table public.store_campaigns')));
  });

  test('RLS blocks seller self-approval and customer used_count writes', () {
    expect(rls, contains('public.is_admin_user(auth.uid())'));
    expect(rls, contains('coupon_protect_campaign_row'));
    expect(rls, contains("raise exception 'not authorized'"));
    expect(rls, contains("new.approval_status = 'approved'"));
    expect(rls, contains('user_coupons_no_client_write'));
    expect(rls, contains('coupon_redemptions_no_client_insert'));
    expect(rls, contains('reward_wheel_spins_no_client_insert'));
  });

  test('apply and spin RPCs are security definer and atomic', () {
    expect(rpc, contains('coupon_apply_to_order'));
    expect(rpc, contains('security definer'));
    expect(rpc, contains('for update'));
    expect(rpc, contains('used_count = used_count + 1'));
    expect(rpc, contains('total_usage_limit is null or used_count < total_usage_limit'));
    expect(wheel, contains('spin_reward_wheel'));
    expect(wheel, contains('p_idempotency_key'));
    expect(wheel, contains('already_processed'));
    expect(wheel, contains("raise exception 'probability total must be 100 percent'"));
    expect(wheel, contains('list_daily_deal_products'));
    expect(wheel, contains('p.discount_price < p.price'));
    expect(wheelOps, contains('wheel_requested'));
    expect(wheelOps, contains('get_reward_wheel_for_user'));
    expect(wheelOps, contains('reward_wheel_compose_for_user'));
    expect(wheelOps, contains('p_idempotency_key'));
    expect(wheelOps, contains('reward_wheel_coupon_winnable'));
    expect(wheelOps, contains("new.wheel_enabled := false"));
    expect(wheelOps, contains('already_processed'));
    expect(wheelElig, contains('reward_wheel_user_eligibility'));
    expect(wheelElig, contains('can_spin'));
    expect(wheelElig, contains('daily_limit'));
    expect(wheelElig, contains('cooldown'));
    expect(wheelElig, contains('p_idempotency_key'));
    expect(wheelElig, contains('already_processed'));
    expect(wheelElig, contains('for update'));
  });

  test('Flutter wheel no longer picks the prize locally', () {
    final wheelUi = File(
      'lib/widgets/game/fortune_wheel_dialog.dart',
    ).readAsStringSync();
    final wheelChrome = File(
      'lib/widgets/game/fortune_wheel_customer_chrome.dart',
    ).readAsStringSync();
    expect(wheelUi, contains('spinWheel'));
    expect(wheelUi, contains('loadWheelForUser'));
    final overlay = File(
      'lib/features/coupon/widgets/reward_wheel_floating_button.dart',
    ).readAsStringSync();
    expect(overlay, contains('visibleOnHome'));
    expect(overlay, contains('_onSpinComplete'));
    expect(overlay, isNot(contains('SharedPreferences')));
    expect(overlay, isNot(contains('localStorage')));
    expect(wheelChrome, contains('RewardWheelSlicePainter'));
    expect(wheelChrome, contains('showLabels: false'));
    expect(wheelChrome, contains('mystery: true'));
    expect(wheelUi, isNot(contains('WheelPainter')));
    expect(wheelUi, isNot(contains("CouponService().addCoupon")));
    expect(wheelUi, isNot(contains('iPhone 15')));
    final adminPreview = File(
      'lib/features/coupon/widgets/reward_wheel_preview.dart',
    ).readAsStringSync();
    expect(adminPreview, contains('showLabels: true'));
    expect(adminPreview, contains('RewardWheelLegend'));
  });

  test('home deal column does not keep decorative-only copy as the only path', () {
    final home = File(
      'lib/screens/home/sections/home_section_coupon_deal_column.dart',
    ).readAsStringSync();
    expect(home, contains('listDailyDeals'));
    expect(home, contains('Bugün aktif fırsat bulunmuyor.'));
    expect(home, contains('CouponDiscoverPage'));
    expect(home, contains('DailyDealsPage'));
  });
}
