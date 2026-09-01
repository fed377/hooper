import 'package:firebase_auth/firebase_auth.dart';

enum AuthStatus { unauthenticated, unverified, restricted, needsProfileFill, authenticated }

class AppAuthState {
  final AuthStatus status;
  final User? user;
  final String? restrictionReason;
  final String? accountStatus;

  AppAuthState({required this.status, this.user, this.restrictionReason, this.accountStatus});
}
