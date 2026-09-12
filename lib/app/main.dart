//import 'package:cloud_firestore/cloud_firestore.dart';
//import 'package:cloud_functions/cloud_functions.dart';
//import 'package:firebase_auth/firebase_auth.dart';
//import 'package:flutter/foundation.dart' show kDebugMode;
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooper/app/firebase_options.dart';
import 'package:hooper/app/gates/auth_gate.dart';
import 'package:hooper/core/services/fcmservice.dart';
import 'package:hooper/core/services/google_auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FCMService().init();

  await GoogleAuthService.instance.initialize(
    webClientId: "146796569082-cqcg4hmslg3a81gjoupatff6646omquq.apps.googleusercontent.com",
    iosClientId: DefaultFirebaseOptions.currentPlatform.iosClientId,
  );

  if (!Platform.isAndroid) return;

  SystemChrome.setEnabledSystemUIMode(.edgeToEdge);

  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarContrastEnforced: true,
    ),
  );

  runApp(ProviderScope(child: const HooperApp()));
}

class HooperApp extends StatelessWidget {
  const HooperApp({super.key});

  @override
  Widget build(BuildContext context) {
    double rad = 24;
    final theme = ThemeData(
      fontFamily: 'Google Sans Flex',
      colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 3, 108, 255)),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(shape: RoundedSuperellipseBorder(borderRadius: .circular(rad))),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: EdgeInsets.only(top: 16, bottom: 16, right: 24, left: 24),
          shape: RoundedSuperellipseBorder(borderRadius: .circular(50)),
          backgroundColor: const Color.fromARGB(224, 255, 255, 255),
          foregroundColor: Colors.black,
          backgroundBuilder: (context, states, child) {
            return Container(
              decoration: ShapeDecoration(
                shape: RoundedSuperellipseBorder(borderRadius: .circular(50)),
                color: Colors.white,
              ),
              child: child,
            );
          },
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(shape: RoundedSuperellipseBorder(borderRadius: .circular(rad))),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: FilledButton.styleFrom(
          padding: .all(12),
          shape: CircleBorder(),
          backgroundColor: const Color.fromARGB(225, 255, 255, 255),
          foregroundColor: Colors.black,
        ),
      ),
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const AuthGate(),
      theme: theme,
      navigatorKey: FCMService().navigatorKey,
    );
  }
}
