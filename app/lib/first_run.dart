import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import 'sync/sync_controller.dart';

/// What is left over from an earlier install, cleared on the first launch
/// after this one.
///
/// Deleting the app is meant to remove everything it kept. On an iPhone
/// the Keychain outlives the app, so a sync token saved before it was
/// deleted would still be there when it is installed again. The app's
/// own preferences do go with it, so a flag kept there tells a first
/// launch from any other.
class FirstRun {
  FirstRun._();

  /// Set once the first launch has been seen to.
  static const installedKey = 'installed';

  /// Throws away a sync token left by an earlier install, then sets the
  /// flag. Must run before anything reads the token.
  ///
  /// An install from before this flag existed that is only being updated
  /// keeps its token: if sync is already set up in [root], the flag is
  /// set and nothing is deleted.
  static Future<void> clearLeftovers({
    required SharedPreferences preferences,
    required Directory root,
    SecretStore secrets = const PhoneSecretStore(),
    bool? iOS,
  }) async {
    if (preferences.getBool(installedKey) ?? false) return;
    final setUp = File('${root.path}/sync.json').existsSync();
    if ((iOS ?? Platform.isIOS) && !setUp) {
      try {
        await secrets.delete();
      } catch (_) {
        // Nothing there to delete, or the Keychain is not to be had yet:
        // asked again on the next launch.
        return;
      }
    }
    await preferences.setBool(installedKey, true);
  }
}
