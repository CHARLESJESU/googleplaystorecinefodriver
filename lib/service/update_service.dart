import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  // Provided Play Store url; user gave this one.
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.vlabs.cinefo_agent';

  // Prevent repeated checks during same app session (avoid loops).
  static bool _checkedThisSession = false;

  /// Public method: call after first frame (so context is valid).
  /// Example: WidgetsBinding.instance.addPostFrameCallback((_) => UpdateService.checkAndPerformUpdate(context));
  static Future<void> checkAndPerformUpdate(BuildContext? context) async {
    // Guard: only once per session
    if (_checkedThisSession) {
      debugPrint('UpdateService: already checked this session.');
      return;
    }
    _checkedThisSession = true;

    try {
      final AppUpdateInfo info = await InAppUpdate.checkForUpdate();

      if (info.updateAvailability != UpdateAvailability.updateAvailable) {
        debugPrint('UpdateService: no update available.');
        return;
      }

      // Prefer immediate update if allowed (blocks user until update completes)
      if (info.immediateUpdateAllowed == true) {
        debugPrint('UpdateService: immediate update allowed — launching.');
        try {
          await InAppUpdate.performImmediateUpdate();
          // If immediate update returns, the update finished or the user cancelled.
          return;
        } catch (e, st) {
          debugPrint('UpdateService: immediate update failed: $e\n$st');
          // Fallthrough to flexible or fallback
        }
      }

      // Try flexible update if available (user can continue using app while update downloads)
      if (info.flexibleUpdateAllowed == true) {
        debugPrint('UpdateService: flexible update allowed — starting.');
        try {
          await InAppUpdate.startFlexibleUpdate();
          // OPTIONAL: you can show a UI to the user here that update is downloading.
          // After download, call completeFlexibleUpdate to install (this shows Play's restart UI).
          await InAppUpdate.completeFlexibleUpdate();
          debugPrint('UpdateService: flexible update completed.');
          return;
        } catch (e, st) {
          debugPrint('UpdateService: flexible update failed: $e\n$st');
          // Fallthrough to fallback
        }
      }

      // If we reach here, in-app flows didn't run or failed -> fallback to Play Store
      debugPrint('UpdateService: falling back to Play Store URL.');
      await _openPlayStore();
    } catch (e, st) {
      debugPrint('UpdateService: checkForUpdate failed: $e\n$st');
      // Fallback if entire in-app check failed
      await _openPlayStore();
    }
  }

  /// Opens the Play Store. Tries market:// first, then https:// web URL,
  /// and finally the provided fallback playStoreUrl.
  static Future<void> _openPlayStore() async {
    try {
      // 1) Try using market:// with package name from package_info_plus
      final info = await PackageInfo.fromPlatform();
      final packageName = info.packageName;
      final marketUri = Uri.parse('market://details?id=$packageName');

      if (await canLaunchUrl(marketUri)) {
        await launchUrl(marketUri);
        return;
      }

      // 2) If market: scheme not available, try https Play Store with packageName
      final playWebUri =
      Uri.parse('https://play.google.com/store/apps/details?id=$packageName');
      if (await canLaunchUrl(playWebUri)) {
        await launchUrl(playWebUri);
        return;
      }

      // 3) As final fallback, use the explicit URL you provided
      final fallbackUri = Uri.parse(playStoreUrl);
      if (await canLaunchUrl(fallbackUri)) {
        await launchUrl(fallbackUri);
        return;
      }

      debugPrint('UpdateService: unable to open any Play Store URL.');
    } catch (e) {
      debugPrint('UpdateService: failed to open Play Store: $e');
    }
  }
}
