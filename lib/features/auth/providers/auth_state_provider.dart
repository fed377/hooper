import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooper/core/services/providers.dart';
import 'package:hooper/features/auth/data/app_auth_state.dart';

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final appAuthStateProvider = FutureProvider<AppAuthState>((ref) async {
  // 1. Auth state stream
  final user = ref.watch(authStateProvider).value;
  if (user == null) {
    return AppAuthState(status: AuthStatus.unauthenticated);
  }

  // 2. Email verification
  if (!user.emailVerified) {
    return AppAuthState(status: AuthStatus.unverified, user: user);
  }

  // 3. Live Account Status check (Firestore Stream)
  final statusInfo = await ref.watch(_myAccountStatusProvider(user.uid).future);
  if (statusInfo.status != 'active') {
    return AppAuthState(
      status: AuthStatus.restricted,
      user: user,
      restrictionReason: statusInfo.reason,
      accountStatus: statusInfo.status,
    );
  }

  final profileExists = await ref.watch(profileExistsProvider(user.uid).future);
  if (!profileExists) {
    return AppAuthState(status: AuthStatus.needsProfileFill, user: user);
  }

  final birthDate = await ref.watch(_myDateOfBirthProvider(user.uid).future);
  if (birthDate == null) {
    return AppAuthState(status: AuthStatus.needsProfileFill, user: user);
  }

  return AppAuthState(status: AuthStatus.authenticated, user: user);
});

class AccountStatusInfo({required var String status, required var String? reason});

final _myAccountStatusProvider = StreamProvider.family<AccountStatusInfo, String>((ref, uid) {
  return FirebaseFirestore.instance.collection('users').doc(uid).snapshots().map((snap) {
    final data = snap.data();
    return AccountStatusInfo(status: data?['status'] as String? ?? 'active', reason: data?['statusReason'] as String?);
  });
});

final _myDateOfBirthProvider = StreamProvider.autoDispose.family<DateTime?, String>((ref, uid) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((snap) => (snap.data()?['dateOfBirth'] as Timestamp?)?.toDate());
});
