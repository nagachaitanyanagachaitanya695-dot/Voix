/// Which build this is.
///
/// Exists because "still showing like this" is unanswerable without it: a fix
/// that is not in the APK on the phone looks exactly like a fix that did not
/// work, and the two need completely different next steps. The commit is shown
/// on the About and Testing screens so a single screenshot settles it.
abstract final class BuildInfo {
  /// Short commit the build came from, or 'local' when built by hand.
  static const commit = String.fromEnvironment(
    'VOIX_BUILD',
    defaultValue: 'local',
  );

  static bool get isCI => commit != 'local';
}
