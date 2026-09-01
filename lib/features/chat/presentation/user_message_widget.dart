import 'package:flutter/material.dart';
import 'package:hooper/features/chat/data/chat_message.dart';

class UserMessage extends StatelessWidget {
  const UserMessage({super.key, required this.isMine, required this.msg, required this.wasLastRead});

  final bool isMine;
  final bool wasLastRead;
  final ChatMessage msg;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: isMine ? .end : .start,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 3),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
            decoration: ShapeDecoration(
              color: isMine
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              shape: RoundedSuperellipseBorder(borderRadius: .circular(14)),
            ),
            child: Text(msg.text),
          ),
          if (isMine && wasLastRead) Text('Read', style: TextTheme.of(context).labelMedium),
        ],
      ),
    );
  }
}
