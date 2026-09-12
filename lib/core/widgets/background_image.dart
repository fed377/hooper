import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooper/core/services/providers.dart';

class BackgroundImage extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox.expand(
      child: Hero(
        transitionOnUserGestures: true,
        tag: "img",
        child: RepaintBoundary(
          child: Image(alignment: .centerLeft, fit: .cover, image: ref.watch(backgroundImageProvider)),
        ),
      ),
    );
  }
}
