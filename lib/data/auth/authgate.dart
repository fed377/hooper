import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooper/home_page.dart';

import '../../../data/providers.dart';
import '../../screens/signin_screen.dart';

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
          return const EmailSignInScreen();
        }

        // Signed in — but wait for onUserCreate to have finished
        // writing playerProfiles/{uid} before handing off to the rest
        // of the app, which assumes that doc exists.
        final profileExists = ref.watch(profileExistsProvider(user.uid));
        return profileExists.when(
          loading: () => const _Splash(message: 'Setting up your profile…'),
          error: (err, _) => Scaffold(body: Center(child: Text('Could not load your profile: $err'))),
          data: (exists) {
            if (!exists) {
              return const _Splash(message: 'Setting up your profile…');
            }
            // TODO: once dateOfBirth collection is built, check for it
            // here too and route to an onboarding screen if missing —
            // onUserCreate deliberately doesn't set it (see Step 1).
            return const HomePage();
          },
        );
      },
    );
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
