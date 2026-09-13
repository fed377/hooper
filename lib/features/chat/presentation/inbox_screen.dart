import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooper/core/utils/utils.dart' as utils;
import 'package:hooper/core/widgets/skeleton_widget.dart';
import 'package:hooper/features/chat/data/chat.dart';
import 'package:hooper/features/requests/data/match_request_doc.dart';

import '../../../core/services/providers.dart';
import 'chat_screen.dart';

class ChatInboxScreen extends ConsumerWidget {
  const ChatInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUserIdProvider);
    final chatsAsync = ref.watch(myChatsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Chats')),
      body: SkeletonWidget(
        val: chatsAsync,
        dummyData: List<Chat>.generate(10, (_) => Chat.dummy()),
        builder: (List<Chat> chats) {
          if (chats.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: .min,
                  children: [
                    const Icon(Icons.chat_bubble_outline, size: 48),
                    const SizedBox(height: 12),
                    const Text('No conversations yet'),
                    const SizedBox(height: 4),
                    Text(
                      'Challenge someone from the feed to start one.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            itemCount: chats.length,
            separatorBuilder: (_, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
              child: Divider(
                height: 1,
                thickness: 2,
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                radius: .circular(10),
              ),
            ),
            itemBuilder: (context, index) {
              final Chat chat = chats[index];
              return _ConversationTile(uid: uid, chat: chat);
            },
          );
        },
      ),
    );
  }
}

class _ConversationTile extends ConsumerWidget {
  final String uid;
  final Chat chat;
  const _ConversationTile({required this.uid, required this.chat});

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${time.month}/${time.day}';
  }

  String? _statusString(MatchRequestStatus status) => switch (status) {
    .accepted => 'Confirmed',
    .declined => 'Declined',
    .withdrawn => 'Cancelled',
    .expired => 'Expired',
    .finished => 'Finished',
    .pending => null,
  };

  Widget? _statusChip(MatchRequestStatus status) {
    String? str = _statusString(status);
    if (str == null) return null;
    return Chip(
      shape: RoundedSuperellipseBorder(borderRadius: .circular(12)),
      label: Text(str),
      visualDensity: VisualDensity.compact,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (uid == '') {
      return ListTile(
        leading: CircleAvatar(child: Text('')),
        title: Text(
          'Sample username',
          style: TextTheme.of(context).bodyLarge?.copyWith(fontWeight: .bold),
        ),
        subtitle: Text(
          "sample last message preview",
          maxLines: 1,
          overflow: .ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: .center,
          crossAxisAlignment: .end,
          children: [
            Text(
              _relativeTime(.now()),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }
    final otherId = chat.otherParticipant(uid);
    final nameAsync = ref.watch(playerDisplayNameProvider(otherId));
    final lastActivity = chat.lastMessageAt ?? chat.createdAt;

    final requestId = chat.lastMatchRequestId;
    final lastRequest = requestId == null
        ? null
        : ref.watch(matchRequestProvider(requestId));
    final statusChip = requestId == null
        ? null
        : lastRequest?.maybeWhen(
            data: (request) => _statusChip(request.status),
            orElse: () => null,
          );

    final imageUrl = ref.watch(playerPhotoUrlProvider(otherId));

    return ListTile(
      leading: imageUrl.when(
        data: (val) {
          if (val != '') {
            // ResizeImage caps the decoded size to roughly the on-screen avatar
            // size (radius 20 => ~120px at 3x), instead of decoding the source
            // image at full resolution just to shrink it for a small avatar.
            return CircleAvatar(
              backgroundImage: ResizeImage(
                CachedNetworkImageProvider(val),
                width: 120,
              ),
            );
          } else {
            return Text(nameAsync.value?.substring(0, 1) ?? '?');
          }
        },
        error: (_, _) => null,
        loading: () => null,
      ),
      title: Text(
        nameAsync.value ?? 'Loading…',
        style: TextTheme.of(context).bodyLarge?.copyWith(fontWeight: .bold),
      ),
      subtitle: Text(
        utils.parseDateMessage(chat.lastMessagePreview ?? "No messages"),
        maxLines: 1,
        overflow: .ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: .center,
        crossAxisAlignment: .end,
        children: [
          Text(
            _relativeTime(lastActivity),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          ?statusChip,
        ],
      ),
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => ChatScreen(chatId: chat.id))),
    );
  }
}
