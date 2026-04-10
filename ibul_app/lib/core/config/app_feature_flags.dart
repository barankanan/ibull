import 'package:flutter/foundation.dart';

class AppFeatureFlags {
  static const bool allowGuestMode = false;
  static const bool enableDemoAiAssistant = true;
  static const bool enableDemoVisualIntelligence = true;
  static const bool enableVerboseDebugLogs = kDebugMode;

  const AppFeatureFlags._();
}
