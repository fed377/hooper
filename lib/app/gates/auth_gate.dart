import 'dart:developer' show log;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooper/app/gates/lock_gate.dart';
import 'package:hooper/core/services/fcmservice.dart';
import 'package:hooper/core/utils/heartbeat_wrapper.dart';
import 'package:hooper/core/widgets/loading_screen_widget.dart';
import 'package:hooper/features/auth/data/app_auth_state.dart';
import 'package:hooper/features/auth/presentation/account_restricted_screen.dart';
import 'package:hooper/features/auth/providers/auth_state_provider.dart';
import 'package:hooper/features/profile/presentation/profile_fill_screen.dart';

import '../../features/auth/presentation/app_enter_screen.dart';

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  bool emailSent = false;
  AuthStatus? _lastStatus;

  // Whatever screen we return below sits at the bottom of the single app-wide
  // Navigator; a screen pushed on top of it (e.g. a chat) would otherwise
  // hide a status change — signed out, restricted, needs profile fill, etc.
  // — until the user manually popped back. Force them back to the root the
  // moment the status actually changes so the new gate screen is visible.
  void _routeToRootOnStatusChange(AuthStatus status) {
    if (_lastStatus != null && _lastStatus != status) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      });
    }
    _lastStatus = status;
  }

  @override
  Widget build(BuildContext context) {
    final authStatus = ref.watch(appAuthStateProvider);

    return authStatus.when(
      loading: () => const SplashScreen(),
      error: (err, _) =>
          Scaffold(body: Center(child: Text('Something went wrong: $err'))),
      data: (state) {
        _routeToRootOnStatusChange(state.status);
        switch (state.status) {
          case AuthStatus.unauthenticated:
            return const AppEnterScreen();

          case AuthStatus.unverified:
            _sendVerificationEmail(state.user);
            return SplashScreen(
              showLoading: false,
              message: 'Follow the link in your email to verify your account',
              widg: FilledButton(
                onPressed: () => FirebaseAuth.instance.signOut(),
                child: Text("Log Out"),
              ),
            );

          case AuthStatus.restricted:
            return AccountRestrictedScreen(
              status: state.accountStatus ?? '',
              reason: state.restrictionReason ?? '',
            );

          case AuthStatus.needsProfileFill:
            return const ProfileFillScreen();

          case AuthStatus.authenticated:
            if (state.user != null) {
              FCMService().registerFcmToken(state.user!.uid);
            }
            return HeartbeatWrapper(
              uid: state.user!.uid,
              child: const LockGate(),
            );
        }
      },
    );
  }

  void _sendVerificationEmail(User? user) {
    if (emailSent) return;
    user?.sendEmailVerification().catchError(
      (e) => log("Error sending email: $e"),
    );
    setState(() => emailSent = true);
  }
}
