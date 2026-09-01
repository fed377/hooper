import 'dart:developer' show log;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooper/core/services/fcmservice.dart';
import 'package:hooper/core/widgets/loading_screen_widget.dart';
import 'package:hooper/app/gates/lock_gate.dart';
import 'package:hooper/core/utils/heartbeat_wrapper.dart';
import 'package:hooper/features/auth/data/app_auth_state.dart';
import 'package:hooper/features/auth/presentation/account_restricted_screen.dart';
import 'package:hooper/features/auth/providers/auth_state_provider.dart';
import 'package:hooper/features/profile/presentation/profile_fill_screen.dart';

import '../../features/auth/presentation/authentication_screen.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authStatus = ref.watch(appAuthStateProvider);

    return authStatus.when(
      loading: () => const SplashScreen(),
      error: (err, _) => Scaffold(body: Center(child: Text('Something went wrong: $err'))),
      data: (state) {
        switch (state.status) {
          case AuthStatus.unauthenticated:
            return const AuthenticationScreen();

          case AuthStatus.unverified:
            _sendVerificationEmail(state.user);
            return const SplashScreen(
              showLoading: false,
              message: 'Follow the link in your email to verify your account',
            );

          case AuthStatus.restricted:
            return AccountRestrictedScreen(status: state.accountStatus ?? '', reason: state.restrictionReason ?? '');

          case AuthStatus.needsProfileFill:
            return const ProfileFillScreen();

          case AuthStatus.authenticated:
            if (state.user != null) {
              FCMService().registerFcmToken(state.user!.uid);
            }
            return HeartbeatWrapper(uid: state.user!.uid, child: const LockGate());
        }
      },
    );
  }

  void _sendVerificationEmail(User? user) {
    user?.sendEmailVerification().catchError((e) => log("Error sending email: $e"));
  }
}
