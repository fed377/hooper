//import 'package:cloud_firestore/cloud_firestore.dart';
//import 'package:cloud_functions/cloud_functions.dart';
//import 'package:firebase_auth/firebase_auth.dart';
//import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooper/data/fcmservice.dart';
import 'package:hooper/data/gates/auth_gate.dart';
import 'package:hooper/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FCMService().init();
  runApp(ProviderScope(child: const HooperApp()));
}

class HooperApp extends StatelessWidget {
  const HooperApp({super.key});

  @override
  Widget build(BuildContext context) {
    double rad = 24;
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 3, 108, 255)),
      textTheme: GoogleFonts.rubikTextTheme(),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(rad))),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(rad))),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(rad))),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(rad))),
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
