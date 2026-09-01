import 'package:flutter/material.dart';
import 'package:hooper/core/utils/utils.dart' as utils;
import 'package:hooper/features/chat/data/chat_message.dart';

class SystemMessage extends StatelessWidget {
  const SystemMessage({super.key, required this.msg});

  final ChatMessage msg;

  @override
  Widget build(BuildContext context) {
    String text = utils.parseDateMessage(msg.text);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisSize: .max,
        children: [
          const SizedBox(width: 25),
          Flexible(
            fit: FlexFit.tight,
            child: Container(
              decoration: ShapeDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                shape: RoundedSuperellipseBorder(borderRadius: .circular(12)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(fontStyle: FontStyle.italic, color: Theme.of(context).colorScheme.outline),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          const SizedBox(width: 25),
        ],
      ),
    );
  }
}
