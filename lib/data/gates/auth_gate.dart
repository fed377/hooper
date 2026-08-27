import 'dart:developer' show log;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hooper/data/fcmservice.dart';
import 'package:hooper/data/gates/lock_gate.dart';
import 'package:hooper/data/heartbeat.dart';
import 'package:hooper/screens/profile_fill_screen.dart';
import 'package:hooper/widgets/loading_screen_widget.dart';

import '../../../data/providers.dart';
import '../../screens/authentication_screen.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      loading: () => const FullScreenLoader(),
      error: (err, _) => Scaffold(body: Center(child: Text('Something went wrong signing in: $err'))),
      data: (user) {
        if (user == null) {
          return const AuthenticationScreen();
        }

        final profileExists = ref.watch(profileExistsProvider(user.uid));
        return profileExists.when(
          loading: () => const FullScreenLoader(message: 'Setting up your profile…'),
          error: (err, _) => Scaffold(body: Center(child: Text('Could not load your profile: $err'))),
          data: (exists) {
            if (!exists) {
              log("doesnt exist");
              return FullScreenLoader(
                message: 'Setting up your profile…',
                widg: FilledButton(
                  child: Text("Log out"),
                  onPressed: () {
                    FirebaseAuth.instance.signOut();
                    GoogleSignIn.instance.signOut();
                  },
                ),
              );
            }
            final dob = ref.watch(myDateOfBirthProvider(user.uid));
            return dob.when(
              loading: () => const FullScreenLoader(),
              error: (err, _) => Scaffold(body: Center(child: Text('Could not load your account: $err'))),
              data: (birthDate) {
                if (birthDate == null) {
                  return const ProfileFillScreen();
                }
                FCMService().registerFcmToken(user.uid);
                return ActivityHeartbeat(uid: user.uid, child: LockGate());
              },
            );
          },
        );
      },
    );
  }
}
