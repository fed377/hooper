import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  final String? message;
  final bool showLoading;
  final Widget? widg;
  const SplashScreen({super.key, this.message, this.widg, this.showLoading = true});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: .min,
          children: [
            if (showLoading) const CircularProgressIndicator(),
            if (message != null) ...[const SizedBox(height: 16), Text(message!)],
            ?widg,
          ],
        ),
      ),
    );
  }
}
