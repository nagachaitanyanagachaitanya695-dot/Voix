import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voix/data/models/user_profile.dart';
import 'package:voix/data/repositories/auth_repository.dart';
import 'package:voix/data/repositories/local_store.dart';
import 'package:voix/data/repositories/profile_sync.dart';
import 'package:voix/firebase_options.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<LocalAuthRepository> repo() async {
    SharedPreferences.setMockInitialValues({});
    return LocalAuthRepository(await LocalStore.open());
  }

  group('DefaultFirebaseOptions', () {
    test('reports itself unconfigured while placeholders remain', () {
      // The guard that keeps main() from calling Firebase.initializeApp with
      // nonsense. If someone fills the file in, this test is expected to fail
      // and should be deleted along with the placeholders.
      expect(DefaultFirebaseOptions.isConfigured, isFalse);
      expect(DefaultFirebaseOptions.hasGoogleClientId, isFalse);
    });
  });

  group('LocalAuthRepository email', () {
    test('rejects a malformed address', () async {
      final r = await repo();
      expect(
        () => r.signIn(
          method: AuthMethod.email,
          email: 'not-an-email',
          password: 'secret123',
        ),
        throwsA(isA<AuthException>()),
      );
    });

    test('rejects a short password', () async {
      final r = await repo();
      expect(
        () => r.signIn(
          method: AuthMethod.email,
          email: 'hrithik@example.com',
          password: '123',
        ),
        throwsA(isA<AuthException>()),
      );
    });

    test('derives a display name from the address', () async {
      final r = await repo();
      final profile = await r.signIn(
        method: AuthMethod.email,
        email: 'hrithik.kumar@example.com',
        password: 'secret123',
      );
      expect(profile.name, 'Hrithik Kumar');
      expect(profile.email, 'hrithik.kumar@example.com');
    });

    test('an explicit name wins over the derived one', () async {
      final r = await repo();
      final profile = await r.signIn(
        method: AuthMethod.email,
        email: 'hrithik.kumar@example.com',
        password: 'secret123',
        name: 'Naga',
      );
      expect(profile.name, 'Naga');
    });

    test('signing in again keeps existing progress', () async {
      final r = await repo();
      final first = await r.signIn(
        method: AuthMethod.email,
        email: 'hrithik@example.com',
        password: 'secret123',
      );

      // Simulate a week of practice, then a sign-out / sign-in cycle.
      final store = await LocalStore.open();
      await store.setJson(
        LocalStore.kProfile,
        first.copyWith(xp: 1250, currentStreak: 12).toJson(),
      );
      await r.signOut();

      final second = await r.signIn(
        method: AuthMethod.email,
        email: 'hrithik@example.com',
        password: 'secret123',
      );
      expect(second.xp, 1250);
      expect(second.currentStreak, 12);
    });
  });

  group('LocalAuthRepository session', () {
    test('currentUser is null before signing in', () async {
      final r = await repo();
      expect(await r.currentUser(), isNull);
    });

    test('currentUser returns the profile after signing in', () async {
      final r = await repo();
      await r.signIn(method: AuthMethod.guest, name: 'Naga');
      final user = await r.currentUser();
      expect(user, isNotNull);
      expect(user!.name, 'Naga');
      expect(user.isGuest, isTrue);
    });

    test('signOut clears the session but not the progress', () async {
      final r = await repo();
      await r.signIn(method: AuthMethod.guest);
      await r.signOut();
      expect(await r.currentUser(), isNull);

      // The profile is still on disk, which is what lets a returning learner
      // pick up where they left off.
      final store = await LocalStore.open();
      expect(store.getJson(LocalStore.kProfile), isNotNull);
    });

    test('deleteAccount erases everything', () async {
      final r = await repo();
      await r.signIn(method: AuthMethod.guest);
      await r.deleteAccount();

      final store = await LocalStore.open();
      expect(store.getJson(LocalStore.kProfile), isNull);
      expect(await r.currentUser(), isNull);
    });
  });

  group('LocalAuthRepository social sign-in', () {
    test('explains that Google and Apple need Firebase', () async {
      final r = await repo();
      for (final method in [AuthMethod.google, AuthMethod.apple]) {
        await expectLater(
          () => r.signIn(method: method),
          throwsA(
            isA<AuthException>().having(
              (e) => e.message,
              'message',
              contains('FIREBASE_SETUP'),
            ),
          ),
        );
      }
    });
  });

  group('LocalAuthRepository password reset', () {
    test('explains why there is nothing to reset, without naming a doc',
        () async {
      final r = await repo();
      await expectLater(
        () => r.sendPasswordReset('hrithik@example.com'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('locally'),
              // Learner-facing copy must never leak repository paths.
              isNot(contains('docs/')),
              isNot(contains('.md')),
            ),
          ),
        ),
      );
    });
  });

  group('NoOpProfileSync', () {
    test('accepts every call and stores nothing', () async {
      const sync = NoOpProfileSync();
      const profile = UserProfile(id: 'u1', name: 'Naga');
      sync.push(profile);
      await expectLater(sync.flush(), completes);
      expect(await sync.pull('u1'), isNull);
      await expectLater(sync.delete('u1'), completes);
    });
  });
}
