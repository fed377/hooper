import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooper/data/heartbeat.dart';
import 'package:hooper/screens/home_screen.dart';
import 'package:hooper/screens/profile_fill_screen.dart';

import '../../../data/providers.dart';
import '../../screens/authentication_screen.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      loading: () => const _Splash(),
      error: (err, _) => Scaffold(body: Center(child: Text('Something went wrong signing in: $err'))),
      data: (user) {
        if (user == null) {
          return const AuthenticationScreen();
        }

        final profileExists = ref.watch(profileExistsProvider(user.uid));
        return profileExists.when(
          loading: () => const _Splash(message: 'Setting up your profile…'),
          error: (err, _) => Scaffold(body: Center(child: Text('Could not load your profile: $err'))),
          data: (exists) {
            if (!exists) {
              return const _Splash(message: 'Setting up your profile…');
            }
            final dob = ref.watch(myDateOfBirthProvider(user.uid));
            return dob.when(
              loading: () => const _Splash(),
              error: (err, _) => Scaffold(body: Center(child: Text('Could not load your account: $err'))),
              data: (birthDate) {
                if (birthDate == null) {
                  return const ProfileFillScreen();
                }
                return ActivityHeartbeat(uid: user.uid, child: LockGate());
              },
            );
          },
        );
      },
    );
  }
}

class LockGate extends ConsumerWidget {
  const LockGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myLockedMatchesProvider = ref.watch(myLockedMatchIdsProvider);
    return Center(child: const HomePage());
  }
}

class _Splash extends StatelessWidget {
  final String? message;
  const _Splash({this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (message != null) ...[const SizedBox(height: 16), Text(message!)],
          ],
        ),
      ),
    );
  }
}
