import 'package:flutter/material.dart';
import 'package:hooper/core/widgets/background_image.dart';
import 'package:hooper/core/widgets/dark_buttons.dart';
import 'package:hooper/features/auth/presentation/authentication_screen.dart';

class AppEnterScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red,
      body: Stack(
        children: [
          BackgroundImage(),
          SizedBox.expand(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: .max,
                mainAxisAlignment: .end,
                crossAxisAlignment: .start,
                children: [
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
                        Text(
                          "Hooper",
                          textAlign: .left,
                          style: TextTheme.of(context).displayLarge?.copyWith(
                            color: const Color.fromARGB(233, 255, 255, 255),
                            fontWeight: .w900,
                            fontVariations: [FontVariation('wdth', 50), FontVariation('grad', 100)],
                          ),
                        ),
                        const SizedBox(height: 0),
                        Text(
                          "Find people to hoop with, anywhere. ",
                          style: TextTheme.of(context).titleMedium?.copyWith(
                            color: const Color.fromARGB(188, 255, 255, 255),
                            fontVariations: [FontVariation('wdth', 100), FontVariation('grad', 0)],
                          ),
                        ),
                      ].reversed.toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonal(
                          child: Text("Sign In"),
                          onPressed: () {
                            Navigator.of(context)
                                .push(MaterialPageRoute(builder: (_) => AuthenticationScreen(isRegistering: false)));
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Hero(
                          transitionOnUserGestures: true,
                          flightShuttleBuilder:
                              (flightContext, animation, flightDirection, fromHeroContext, toHeroContext) {
                                return OverflowBox(fit: .deferToChild, child: toHeroContext.widget);
                              },
                          tag: "darkbtn",
                          child: DarkFilledButton(
                            child: Text("Sign Up", overflow: .fade),
                            onPressed: () {
                              Navigator.of(context)
                                  .push(MaterialPageRoute(builder: (_) => AuthenticationScreen(isRegistering: true)));
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
