import 'package:flutter/foundation.dart';

class AppFeatureFlags {
  static const bool allowGuestMode = false;
  static final bool enableDemoAiAssistant = !kReleaseMode;
  static final bool enableDemoVisualIntelligence = !kReleaseMode;
  static const bool enableVerboseDebugLogs = kDebugMode;

  const AppFeatureFlags._();
}
