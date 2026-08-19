import '../../data/repositories/local_store.dart';

/// Where the app finds its backend.
///
/// The backend is a small Cloudflare Worker that holds your API keys — see
/// `backend/README.md` for the deploy.
///
/// **No API key goes in this file, or anywhere else in this app.** An APK is a
/// zip archive; anything compiled into it can be read out by anyone who
/// downloads it. The only value here is [appToken], which is a low-value
/// doorkeeper: it stops strangers who find your Worker's URL from casually
/// using it, and that is all it is meant to do. The real protection against a
/// surprise bill is the daily cap the Worker enforces and the spending limit
/// you set in your provider account.
///
/// While [baseUrl] is empty the app uses the on-device tutor and the phone's
/// own voice — everything works, the tutor is just scripted rather than
/// genuinely conversational, and the live call is unavailable.
///
/// The address can be supplied two ways:
///
///  * **Compiled in**, via `--dart-define-from-file=env.json`. This is how a
///    real release is built.
///  * **Typed in at runtime**, on the testing screen. This exists because a
///    build made by CI cannot contain your secrets, so without it there is no
///    way to try the live call on a phone without a build machine.
abstract final class BackendConfig {
  static const _compiledBaseUrl = String.fromEnvironment(
    'VOIX_BACKEND_URL',
    defaultValue: '',
  );

  static const _compiledAppToken = String.fromEnvironment(
    'VOIX_APP_TOKEN',
    defaultValue: '',
  );

  /// Whether this build exposes the in-app testing screen.
  ///
  /// Off unless the build passed `--dart-define=VOIX_TESTING=true`, which the
  /// CI test builds do and a Play release must not. The screen can unlock
  /// Premium locally, so shipping it to the store would be handing every
  /// installer the paid tier's interface — harmless server-side, since the
  /// entitlement check happens there and fails closed, but not something to
  /// put in front of paying customers.
  static const isTestingBuild = bool.fromEnvironment(
    'VOIX_TESTING',
    defaultValue: false,
  );

  static String? _overrideBaseUrl;
  static String? _overrideAppToken;

  /// e.g. 'https://voix-backend.your-name.workers.dev'. No trailing slash.
  static String get baseUrl => _overrideBaseUrl ?? _compiledBaseUrl;

  /// The APP_TOKEN secret you set with `wrangler secret put APP_TOKEN`.
  static String get appToken => _overrideAppToken ?? _compiledAppToken;

  /// True once a backend is configured.
  static bool get isConfigured => baseUrl.isNotEmpty;

  /// Whether the address in use was typed in rather than compiled in.
  static bool get isOverridden => _overrideBaseUrl != null;

  /// Applies a runtime address. Pass null to fall back to the compiled one.
  ///
  /// Trailing slashes are stripped: pasting a URL from a browser address bar
  /// is the normal way to get one, and it would otherwise produce `//v1/chat`
  /// and a 404 that looks like the backend is down.
  static void applyOverride({String? baseUrl, String? appToken}) {
    final trimmed = baseUrl?.trim();
    _overrideBaseUrl = (trimmed == null || trimmed.isEmpty)
        ? null
        : trimmed.replaceAll(RegExp(r'/+$'), '');
    final token = appToken?.trim();
    _overrideAppToken = (token == null || token.isEmpty) ? null : token;
  }

  /// Restores a previously saved address at launch.
  static void restoreFrom(LocalStore store) {
    if (!isTestingBuild) return;
    applyOverride(
      baseUrl: store.getString(LocalStore.kTestBackendUrl),
      appToken: store.getString(LocalStore.kTestAppToken),
    );
  }

  static Uri get sessionUrl => Uri.parse('$baseUrl/v1/session');
  static Uri get chatUrl => Uri.parse('$baseUrl/v1/chat');

  /// Where a Play purchase token is sent to be checked against Google.
  static Uri get verifyUrl => Uri.parse('$baseUrl/v1/verify');

  /// Explaining a single word: meaning, history, examples, translation.
  static Uri get wordUrl => Uri.parse('$baseUrl/v1/word');
}
