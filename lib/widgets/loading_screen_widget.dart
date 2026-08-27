import 'package:flutter/material.dart';

class FullScreenLoader extends StatelessWidget {
  final String? message;
  final Widget? widg;
  const FullScreenLoader({super.key, this.message, this.widg});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (message != null) ...[const SizedBox(height: 16), Text(message!)],
            ?widg,
          ],
        ),
      ),
    );
  }
}
