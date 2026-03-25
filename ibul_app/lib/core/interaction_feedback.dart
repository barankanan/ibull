import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum FeedbackIntent { lightImpact, mediumImpact, heavyImpact, success, error }

enum InteractionFeedbackType {
  addToCart,
  favorite,
  mainCta,
  successState,
  errorState,
}

class InteractionFeedback {
  static const Duration _defaultThrottle = Duration(milliseconds: 220);
  static const int _maxTrackedChannels = 24;
  static final LinkedHashMap<String, DateTime> _lastTriggeredAt =
      LinkedHashMap<String, DateTime>();

  static const Map<InteractionFeedbackType, FeedbackIntent> _interactionMap = {
    InteractionFeedbackType.addToCart: FeedbackIntent.mediumImpact,
    InteractionFeedbackType.favorite: FeedbackIntent.lightImpact,
    InteractionFeedbackType.mainCta: FeedbackIntent.mediumImpact,
    InteractionFeedbackType.successState: FeedbackIntent.success,
    InteractionFeedbackType.errorState: FeedbackIntent.error,
  };

  static Future<void> trigger(
    FeedbackIntent intent, {
    String channel = 'default',
  }) async {
    if (kIsWeb) return;
    if (!_shouldTrigger(channel)) return;

    try {
      switch (intent) {
        case FeedbackIntent.lightImpact:
          await HapticFeedback.lightImpact();
          break;
        case FeedbackIntent.mediumImpact:
          await HapticFeedback.mediumImpact();
          break;
        case FeedbackIntent.heavyImpact:
          await HapticFeedback.heavyImpact();
          break;
        case FeedbackIntent.success:
          await _performSuccessFeedback();
          break;
        case FeedbackIntent.error:
          await _performErrorFeedback();
          break;
      }
    } catch (_) {}
  }

  static Future<void> forInteraction(
    InteractionFeedbackType interaction, {
    String? channel,
  }) {
    return trigger(
      _interactionMap[interaction]!,
      channel: channel ?? interaction.name,
    );
  }

  static Future<void> lightImpact({String channel = 'light_impact'}) {
    return trigger(FeedbackIntent.lightImpact, channel: channel);
  }

  static Future<void> mediumImpact({String channel = 'medium_impact'}) {
    return trigger(FeedbackIntent.mediumImpact, channel: channel);
  }

  static Future<void> heavyImpact({String channel = 'heavy_impact'}) {
    return trigger(FeedbackIntent.heavyImpact, channel: channel);
  }

  static Future<void> success({String channel = 'success'}) {
    return trigger(FeedbackIntent.success, channel: channel);
  }

  static Future<void> error({String channel = 'error'}) {
    return trigger(FeedbackIntent.error, channel: channel);
  }

  static bool _shouldTrigger(String channel) {
    final now = DateTime.now();
    final lastTriggeredAt = _lastTriggeredAt[channel];
    if (lastTriggeredAt != null &&
        now.difference(lastTriggeredAt) < _defaultThrottle) {
      return false;
    }

    _lastTriggeredAt[channel] = now;
    while (_lastTriggeredAt.length > _maxTrackedChannels) {
      _lastTriggeredAt.remove(_lastTriggeredAt.keys.first);
    }

    return true;
  }

  static Future<void> _performSuccessFeedback() async {
    await HapticFeedback.lightImpact();
    await Future<void>.delayed(const Duration(milliseconds: 40));
    await HapticFeedback.mediumImpact();
  }

  static Future<void> _performErrorFeedback() async {
    await HapticFeedback.heavyImpact();
  }
}
