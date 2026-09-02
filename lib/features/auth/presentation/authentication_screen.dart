import 'dart:developer' show log;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hooper/core/services/google_auth_service.dart';
import 'package:hooper/core/widgets/dark_buttons.dart';
import 'package:skeletonizer/skeletonizer.dart';

class AuthenticationScreen extends StatefulWidget {
  const AuthenticationScreen({super.key, required this._isRegistering});
  final bool _isRegistering;

  @override
  State<AuthenticationScreen> createState() => _AuthenticationScreenState();
}

class _AuthenticationScreenState extends State<AuthenticationScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;
  bool _submittingGoogle = false;
  String? _error;
  bool _showPw = false;

  Future<void> _signInWithGoogle() async {
    setState(() {
      _submittingGoogle = true;
      _error = null;
    });
    try {
      await GoogleAuthService.instance.signIn();
    } on GoogleSignInException catch (e) {
      if (!mounted) return;
      if (e.code != GoogleSignInExceptionCode.canceled) {
        setState(() => _error = 'Could not sign in with Google. Please try again.');
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = _messageFor(e.code));
    } finally {
      if (mounted) {
        setState(() => _submittingGoogle = false);
        if (FirebaseAuth.instance.currentUser != null) {
          Navigator.of(context).pop();
        }
      }
    }
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      if (widget._isRegistering) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = _messageFor(e.code));
    } finally {
      TextInput.finishAutofillContext();
      if (mounted) {
        setState(() => _submitting = false);
        if (FirebaseAuth.instance.currentUser != null) {
          Navigator.of(context).pop();
        }
      }
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email above first, then try again.');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Password reset email sent to $email')));
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = _messageFor(e.code));
    }
  }

  String _messageFor(String code) {
    log(code);
    switch (code) {
      case 'invalid-email':
        return 'That email address doesn\'t look right.';
      case 'user-not-found':
        return 'No account found for that email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'weak-password':
        return 'Password should be at least 6 characters.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(icon: Icon(Icons.lock_reset_rounded), onPressed: _forgotPassword),
          const SizedBox(width: 14),
        ],
        title: Row(
          children: [IconButton(icon: Icon(Icons.arrow_back_rounded), onPressed: Navigator.of(context).pop)],
        ),
      ),
      body: Stack(
        children: [
          SizedBox.expand(
            child: Hero(
              transitionOnUserGestures: true,
              tag: "img",
              child: ColorFiltered(
                colorFilter: .mode(const Color.fromARGB(255, 44, 44, 47), .color),
                child: ImageFiltered(
                  imageFilter: .blur(sigmaX: 6, sigmaY: 6, tileMode: .mirror),
                  child: Image(
                    alignment: .centerLeft,
                    fit: .cover,
                    image: NetworkImage(
                      "https://plus.unsplash.com/premium_photo-1685366454253-cb705836c5a8?q=80&w=2070&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D",
                    ),
                  ),
                ),
              ),
            ),
          ),

          SizedBox.expand(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: AutofillGroup(
                onDisposeAction: AutofillContextAction.cancel,
                child: Column(
                  mainAxisAlignment: .center,
                  crossAxisAlignment: .stretch,
                  children: [
                    const Spacer(),
                    Hero(
                      transitionOnUserGestures: true,
                      flightShuttleBuilder:
                          (flightContext, animation, flightDirection, fromHeroContext, toHeroContext) {
                            return Material(type: .transparency, child: toHeroContext.widget);
                          },
                      tag: "objectcolumn",
                      child: ListView(
                        reverse: true,
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        children: [
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            autofillHints: const [AutofillHints.email],
                            decoration: InputDecoration(labelText: 'Email'),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _passwordController,
                                  obscureText: !_showPw,
                                  autofillHints: [
                                    widget._isRegistering ? AutofillHints.newPassword : AutofillHints.password,
                                  ],
                                  decoration: const InputDecoration(labelText: 'Password'),
                                  onSubmitted: (_) => _submit(),
                                ),
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                icon: Icon(Icons.remove_red_eye_rounded),
                                onPressed: () => setState(() => _showPw = !_showPw),
                              ),
                            ],
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              decoration: ShapeDecoration(
                                shape: RoundedSuperellipseBorder(borderRadius: .circular(18)),
                                color: const Color.fromARGB(105, 0, 0, 0),
                              ),
                              padding: .symmetric(horizontal: 14, vertical: 12),
                              child: Text(
                                _error!,
                                style: TextStyle(color: Theme.of(context).colorScheme.error),
                                textAlign: .center,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Skeletonizer(
                            enabled: _submitting,

                            child: FilledButton(
                              onPressed: _submitting ? null : _submit,
                              child: Text(widget._isRegistering ? 'Create account' : 'Sign in'),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              const Expanded(child: Divider()),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text('or', style: Theme.of(context).textTheme.bodySmall),
                              ),
                              const Expanded(child: Divider()),
                            ],
                          ),
                        ].reversed.toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Hero(
                      transitionOnUserGestures: true,
                      flightShuttleBuilder:
                          (flightContext, animation, flightDirection, fromHeroContext, toHeroContext) {
                            return OverflowBox(fit: .deferToChild, child: fromHeroContext.widget);
                          },
                      tag: "darkbtn",
                      child: DarkFilledButton(
                        onPressed: _submittingGoogle ? null : _signInWithGoogle,
                        child: Row(
                          mainAxisSize: .max,
                          mainAxisAlignment: .center,
                          children: [
                            Image(
                              height: 20,
                              image: NetworkImage(
                                "https://upload.wikimedia.org/wikipedia/commons/thumb/3/3c/Google_Favicon_2025.svg/250px-Google_Favicon_2025.svg.png?utm_source=en.wikipedia.org&utm_campaign=parser&utm_content=thumbnail",
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text('Continue with Google', overflow: .fade),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
