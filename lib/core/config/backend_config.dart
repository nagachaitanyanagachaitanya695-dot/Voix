/// Where the app finds its backend.
///
/// The backend is a small Cloudflare Worker that holds your OpenAI API key —
/// see `backend/README.md` for the five-minute deploy.
///
/// **Your OpenAI key does not go in this file, or anywhere else in this app.**
/// An APK is a zip archive; anything compiled into it can be read out by
/// anyone who downloads it. The only value here is [appToken], which is a
/// low-value doorkeeper: it stops strangers who find your Worker's URL from
/// casually using it, and that is all it is meant to do. The real protection
/// against a surprise bill is the daily cap the Worker enforces and the
/// spending limit you set in your OpenAI account.
///
/// While [baseUrl] is empty the app uses the on-device tutor and the phone's
/// own voice — everything works, the tutor is just scripted rather than
/// genuinely conversational.
abstract final class BackendConfig {
  /// e.g. 'https://voix-backend.your-name.workers.dev'. No trailing slash.
  static const baseUrl = String.fromEnvironment(
    'VOIX_BACKEND_URL',
    defaultValue: '',
  );

  /// The APP_TOKEN secret you set with `wrangler secret put APP_TOKEN`.
  static const appToken = String.fromEnvironment(
    'VOIX_APP_TOKEN',
    defaultValue: '',
  );

  /// True once a backend is configured.
  static bool get isConfigured => baseUrl.isNotEmpty;

  static Uri get sessionUrl => Uri.parse('$baseUrl/v1/session');
  static Uri get chatUrl => Uri.parse('$baseUrl/v1/chat');
}
