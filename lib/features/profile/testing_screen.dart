import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/config/backend_config.dart';
import '../../core/config/build_info.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/context_ext.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/aurora_background.dart';
import '../../data/repositories/local_store.dart';
import '../../providers/app_providers.dart';
import '../../providers/user_controller.dart';
import 'widgets/settings_tile.dart';

/// Everything needed to try the paid features on a real phone.
///
/// A build made by CI cannot contain your Worker's address or its app token —
/// they are secrets, and CI has no access to them — so without this screen the
/// live call is unreachable in any APK downloaded from a build. Here you paste
/// the address once and it sticks.
///
/// Only reachable in a build made with `--dart-define=VOIX_TESTING=true`.
class TestingScreen extends ConsumerStatefulWidget {
  const TestingScreen({super.key});

  @override
  ConsumerState<TestingScreen> createState() => _TestingScreenState();
}

class _TestingScreenState extends ConsumerState<TestingScreen> {
  late final _url = TextEditingController(text: BackendConfig.baseUrl);
  late final _token = TextEditingController(text: BackendConfig.appToken);

  /// What the last "check connection" attempt found, in plain words.
  String? _probe;
  bool _probing = false;

  @override
  void dispose() {
    _url.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    Haptic.tap();
    final store = ref.read(localStoreProvider);
    await store.setString(LocalStore.kTestBackendUrl, _url.text.trim());
    await store.setString(LocalStore.kTestAppToken, _token.text.trim());
    BackendConfig.applyOverride(
      baseUrl: _url.text,
      appToken: _token.text,
    );
    if (!mounted) return;
    // Read back rather than echoing what was typed: the trailing slash gets
    // stripped, and seeing that happen is how you know it saved.
    setState(() => _url.text = BackendConfig.baseUrl);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved. Try "Check connection".')),
    );
  }

  /// Asks the backend for a live-call session and reports what came back.
  ///
  /// Deliberately reports the *useful* failures separately. "Not configured",
  /// "wrong app token" and "not a subscriber" are three completely different
  /// problems that all look like "the call did not start" from the practice
  /// screen.
  Future<void> _check() async {
    Haptic.tap();
    setState(() {
      _probing = true;
      _probe = null;
    });

    String result;
    if (!BackendConfig.isConfigured) {
      result = 'No address set. Paste your Worker URL above and save.';
    } else {
      final user = ref.read(userControllerProvider);
      try {
        final response = await http
            .post(
              BackendConfig.sessionUrl,
              headers: {
                'Content-Type': 'application/json',
                'x-voix-app-token': BackendConfig.appToken,
                'x-voix-device': ref.read(deviceIdProvider),
              },
              body: jsonEncode({'userId': user?.id ?? 'test'}),
            )
            .timeout(const Duration(seconds: 15));

        result = switch (response.statusCode) {
          200 => _describeSession(response.body),
          401 => 'Reached the Worker, but it rejected the app token. '
              'The value here must match `wrangler secret put APP_TOKEN`.',
          402 => 'Reached the Worker and it works — it just does not consider '
              'this account a subscriber. Turn on "Unlock Premium" below to '
              'see the paid screens; the call itself still needs a real '
              'subscription, because that check is server-side.',
          429 => 'Reached the Worker. Today\'s spending cap for this device is '
              'used up.',
          500 => 'Reached the Worker, but no voice provider is configured on '
              'it. Set ELEVENLABS_API_KEY and ELEVENLABS_AGENT_ID.',
          _ => 'Reached the Worker. It answered '
              '${response.statusCode}: ${_snippet(response.body)}',
        };
      } catch (e) {
        result = 'Could not reach it: $e';
      }
    }

    if (!mounted) return;
    setState(() {
      _probing = false;
      _probe = result;
    });
  }

  static String _describeSession(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final provider = switch (data['provider']) {
        'elevenlabs' => 'ElevenLabs',
        'openai' => 'OpenAI Realtime',
        _ => 'an unnamed provider',
      };
      return 'Working. The call would run on $provider at '
          '${data['sampleRate'] ?? '?'} Hz.';
    } catch (_) {
      return 'Working, but the answer could not be read: ${_snippet(body)}';
    }
  }

  static String _snippet(String body) =>
      body.length <= 160 ? body : '${body.substring(0, 160)}…';

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userControllerProvider);
    final c = context.colors;

    return Scaffold(
      body: AuroraBackground(
        animate: false,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.only(bottom: Gap.xxl),
            children: [
              const SettingsAppBar(title: 'Testing'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.page),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SettingsHero(
                      icon: Icons.science_rounded,
                      title: 'Testing',
                      caption: 'Point this build at your backend and try the '
                          'paid features. Not present in a store release.',
                      color: VoixPalette.cyan,
                    ),
                    Gap.h12,
                    Text(
                      'Build ${BuildInfo.commit}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: c.textSecondary,
                      ),
                    ),
                    Gap.h20,

                    _Label('Backend address'),
                    Gap.h8,
                    TextField(
                      controller: _url,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        hintText: 'https://voix-backend.you.workers.dev',
                      ),
                    ),
                    Gap.h16,

                    _Label('App token'),
                    Gap.h8,
                    TextField(
                      controller: _token,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        hintText: 'the APP_TOKEN secret',
                      ),
                    ),
                    Gap.h8,
                    Text(
                      'This is the doorkeeper token, not an API key. Never '
                      'type an OpenAI or ElevenLabs key here — those belong '
                      'only in wrangler secret put.',
                      style: TextStyle(fontSize: 12, color: c.textTertiary),
                    ),
                    Gap.h20,

                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: _save,
                            child: const Text('Save'),
                          ),
                        ),
                        Gap.w12,
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _probing ? null : _check,
                            child: Text(
                              _probing ? 'Checking…' : 'Check connection',
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (_probe != null) ...[
                      Gap.h16,
                      Container(
                        padding: const EdgeInsets.all(Gap.md),
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(Radii.md),
                          border: Border.all(color: c.border),
                        ),
                        child: Text(
                          _probe!,
                          style: TextStyle(color: c.textPrimary),
                        ),
                      ),
                    ],
                    Gap.h24,

                    SettingsGroup(
                      title: 'Paid features',
                      tiles: [
                        SettingsTile(
                          icon: Icons.workspace_premium_rounded,
                          title: 'Unlock Premium',
                          subtitle: 'Shows the paid screens without paying',
                          showChevron: false,
                          iconColor: VoixPalette.gold,
                          trailing: Switch(
                            value: user?.isPro ?? false,
                            onChanged: (v) {
                              Haptic.tap();
                              ref
                                  .read(userControllerProvider.notifier)
                                  .update((u) => u.copyWith(isPro: v));
                            },
                          ),
                        ),
                      ],
                    ),
                    Gap.h12,
                    Text(
                      'This only opens the interface. Whether a live call may '
                      'actually run is decided by the backend, which checks '
                      'the purchase with Google and refuses if it cannot — so '
                      'this switch cannot get you a free call, and an edited '
                      'APK cannot either.',
                      style: TextStyle(fontSize: 12, color: c.textTertiary),
                    ),
                    Gap.h24,

                    _DeviceReport(),
                    Gap.h24,

                    SettingsGroup(
                      title: 'This build',
                      tiles: [
                        SettingsTile(
                          icon: Icons.dns_rounded,
                          title: 'Address in use',
                          subtitle: BackendConfig.isOverridden
                              ? 'Typed in here'
                              : 'Compiled into the build',
                          value: BackendConfig.isConfigured ? 'Set' : 'None',
                          showChevron: false,
                        ),
                        SettingsTile(
                          icon: Icons.copy_rounded,
                          title: 'Copy device id',
                          subtitle: 'Identifies this install to the daily cap',
                          onTap: () {
                            final id = ref.read(deviceIdProvider);
                            Clipboard.setData(ClipboardData(text: id));
                            Haptic.tap();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Copied $id')),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: context.colors.textSecondary,
        ),
      );
}

/// What this phone reports about itself.
///
/// Layout bugs that only happen on one device are almost always a number the
/// system gave us that no emulator ever produces — a bottom inset half the
/// height of the screen, a text scale nobody tests at. Guessing at those from
/// a screenshot wastes a build cycle each time; reading them takes one.
class _DeviceReport extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final c = context.colors;

    String px(EdgeInsets e) =>
        'L${e.left.round()} T${e.top.round()} R${e.right.round()} B${e.bottom.round()}';

    final rows = <(String, String)>[
      ('Screen', '${mq.size.width.round()} × ${mq.size.height.round()} dp'),
      ('Pixel ratio', mq.devicePixelRatio.toStringAsFixed(2)),
      ('Padding', px(mq.padding)),
      ('View padding', px(mq.viewPadding)),
      ('View insets', px(mq.viewInsets)),
      ('Text scale', mq.textScaler.scale(1).toStringAsFixed(2)),
      ('Orientation', mq.orientation.name),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(title: 'This device', tiles: const []),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Gap.md,
            vertical: Gap.sm,
          ),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: c.border),
          ),
          child: Column(
            children: [
              for (final (label, value) in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 108,
                        child: Text(
                          label,
                          style: TextStyle(fontSize: 13, color: c.textTertiary),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          value,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: c.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Gap.h8,
        Text(
          'Send a photo of this if anything looks wrong on screen.',
          style: TextStyle(fontSize: 12, color: c.textTertiary),
        ),
      ],
    );
  }
}
