import 'dart:async';
import 'dart:developer' show log;
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  GoogleAuthService._();
  static final instance = GoogleAuthService._();

  bool _initialized = false;

  Future<void> initialize({required String webClientId, String? iosClientId}) async {
    if (_initialized) return;

    if (Platform.isIOS) {
      await GoogleSignIn.instance.initialize(clientId: iosClientId, serverClientId: webClientId);
    } else {
      await GoogleSignIn.instance.initialize(serverClientId: webClientId);
    }

    GoogleSignIn.instance.authenticationEvents.listen((event) async {
      if (event is GoogleSignInAuthenticationEventSignIn) {
        final idToken = event.user.authentication.idToken;

        if (idToken != null && FirebaseAuth.instance.currentUser == null) {
          final credential = GoogleAuthProvider.credential(idToken: idToken);
          await FirebaseAuth.instance.signInWithCredential(credential);
        }
      }
    });

    _initialized = true;
    if (FirebaseAuth.instance.currentUser == null) {
      try {
        unawaited(GoogleSignIn.instance.attemptLightweightAuthentication());
      } on GoogleSignInException catch (e) {
        log(e.toString());
      }
    }
  }

  Future<UserCredential> signIn() async {
    late GoogleSignInAccount googleUser;
    try {
      googleUser = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      log(e.code.toString());
      throw StateError(e.description.toString());
    }

    final idToken = googleUser.authentication.idToken;
    if (idToken == null) {
      throw StateError('Google did not return an ID token.');
    }
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    return FirebaseAuth.instance.signInWithCredential(credential);
  }
}
