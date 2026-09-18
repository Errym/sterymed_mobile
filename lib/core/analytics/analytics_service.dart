import 'package:flutter/foundation.dart';

import 'analytics_events.dart';

class AnalyticsService {
  void track(String event, [Map<String, Object?>? props]) {
    if (kDebugMode) {
      debugPrint('analytics: $event $props');
    }
    // Wire to your analytics provider later.
  }

  void trackLogin() => track(AnalyticsEvents.login);
  void trackLogout() => track(AnalyticsEvents.logout);
  void trackScanSuccess() => track(AnalyticsEvents.scanSuccess);
  void trackScanBlocked(String reason) =>
      track(AnalyticsEvents.scanBlocked, {'reason': reason});
  void trackUsageRecorded() => track(AnalyticsEvents.usageRecorded);
  void trackCycleTransition(String status) =>
      track(AnalyticsEvents.cycleTransition, {'status': status});
}
