import 'dart:developer' show log;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooper/data/repos/match_repo.dart';
import 'package:hooper/models/chat.dart';
import 'package:hooper/models/chat_message.dart';
import 'package:hooper/models/match_request_doc.dart';
import 'package:hooper/screens/propose_screen.dart';
import 'package:hooper/core/utils/utils.dart' as utils;
import 'package:hooper/core/widgets/loading_screen_widget.dart';
import 'package:hooper/widgets/location_picker.dart';
import 'package:hooper/core/widgets/skeleton_widget.dart';
import 'package:map_launcher/map_launcher.dart';

import '../data/providers.dart';
import '../models/match_doc.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String chatId;
  const ChatScreen({super.key, required this.chatId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  bool _editingDetails = false;
  final _courtController = TextEditingController();
  DateTime? _editedTime;
  bool _busy = false;
  bool _sendingMessage = false;
  GeoPoint? _chosenLocation;

  Future<void> _send() async {
    setState(() => _sendingMessage = true);
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();
    final uid = ref.read(currentUserIdProvider);
    await ref.read(matchRepositoryProvider).sendMessage(chatId: widget.chatId, uid: uid, text: text);
    setState(() => _sendingMessage = false);
  }

  void _startEditingDetails(MatchRequestDoc request) {
    _courtController.text = request.court;
    _editedTime = request.scheduledTime;
    setState(() => _editingDetails = true);
  }

  Future<void> _pickEditedTime() async {
    final base = _editedTime ?? .now();
    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: .now(),
      lastDate: .now().add(const Duration(days: 14)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(base));
    if (time == null) return;
    setState(() {
      _editedTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _saveDetails(String requestId) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(matchRepositoryProvider)
          .updateMatchRequestDetails(
            matchRequestId: requestId,
            court: _courtController.text.trim(),
            scheduledTime: _editedTime,
            location: _chosenLocation,
          );
      if (!mounted) return;
      setState(() => _editingDetails = false);
    } on MatchActionException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runAction(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on MatchActionException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatAsync = ref.watch(chatProvider(widget.chatId));
    final uid = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: chatAsync.maybeWhen(
          data: (chat) {
            final otherId = chat.otherParticipant(uid);
            final nameAsync = ref.watch(playerDisplayNameProvider(otherId));
            return Text(nameAsync.value ?? 'Loading…');
          },
          orElse: () => const Text('Chat'),
        ),
      ),
      body: chatAsync.when(
        loading: () => const SplashScreen(),
        error: (err, st) {
          log(st.toString());
          return Center(child: Text('Could not load this chat: $err'));
        },
        data: (chat) => _buildBody(chat, uid, chat.otherParticipant(uid)),
      ),
    );
  }

  Widget _buildBody(Chat chat, String uid, String otherId) {
    final requestId = chat.lastMatchRequestId;

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              SizedBox.expand(child: _buildChat(uid, otherId)),
              SizedBox.expand(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.white, const Color.fromARGB(0, 255, 255, 255)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0, 0.3],
                      ),
                    ),
                  ),
                ),
              ),
              if (requestId != null) _buildDetailsSection(requestId),
            ],
          ),
        ),
        if (requestId != null) _buildActionBarForRequest(requestId, uid, otherId),
      ],
    );
  }

  Widget _buildDetailsSection(String requestId) {
    final requestAsync = ref.watch(matchRequestProvider(requestId));
    return SkeletonWidget<MatchRequestDoc>(
      val: requestAsync,
      dummyData: MatchRequestDoc.dummy(),
      builder: (request) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: ClipRSuperellipse(
          borderRadius: .circular(24),
          child: Column(
            children: [
              _DetailsWidget(
                request: request,
                editing: _editingDetails,
                busy: _busy,
                courtController: _courtController,
                editedTime: _editedTime,
                onEdit: () => _startEditingDetails(request),
                onPickTime: _pickEditedTime,
                onSave: () => _saveDetails(requestId),
                onCancelEdit: () => setState(() => _editingDetails = false),
                onPickLocation: () async {
                  final location = await LocationPicker.pickLocation(context, _chosenLocation ?? request.location);
                  if (location != null) _chosenLocation = location;
                },
              ),
              _StatusBanner(status: request.status),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChat(String uid, String opponentId) {
    final messagesAsync = ref.watch(chatMessagesProvider(widget.chatId));
    final lastMessageIdAsync = ref.watch(lastMessageIdRead((widget.chatId, opponentId)));
    return Column(
      children: [
        Expanded(
          child: SkeletonWidget(
            val: messagesAsync,
            dummyData: ChatMessage.dummyList(uid),
            builder: (List<ChatMessage> messages) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_scrollController.hasClients) {
                  _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                }
              });

              if (messages.isEmpty) {
                return const Center(child: Text('No messages yet'));
              }
              final repo = ref.read(matchRepositoryProvider);
              repo.readMessage(
                userId: ref.read(currentUserIdProvider),
                chatId: widget.chatId,
                messageId: messages.last.id,
              );
              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  if (msg.isSystem) {
                    return _SystemMessage(msg: msg);
                  }
                  final isMine = msg.senderId == uid;
                  return _UserMessage(isMine: isMine, msg: msg, wasLastRead: msg.id == lastMessageIdAsync.value);
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: _sendingMessage ? 'Sending...' : 'Message…',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _sendingMessage ? null : _send(),
                ),
              ),
              IconButton(icon: const Icon(Icons.send), onPressed: _sendingMessage ? null : _send),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionBarForRequest(String requestId, String uid, String otherId) {
    final requestAsync = ref.watch(matchRequestProvider(requestId));
    final repo = ref.read(matchRepositoryProvider);

    return requestAsync.maybeWhen(
      data: (request) {
        if (request.status == MatchRequestStatus.accepted) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text("You're locked in! Head to the court.", textAlign: TextAlign.center),
          );
        }
        if (request.status != MatchRequestStatus.pending) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : () => ProposeMatchScreen.pushProposal(otherId, context),
                    child: Text("Play"),
                  ),
                ),
              ],
            ),
          );
        }

        final isInitiator = request.isInitiator(uid);
        final lockedMatchesAsync = ref.watch(lockedMatchesProvider);

        return Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (isInitiator)
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => _runAction(() => repo.cancelRequest(requestId)),
                    child: const Text('Cancel request'),
                  ),
                )
              else ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => _runAction(() => repo.declineRequest(requestId)),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 12),
                SkeletonWidget(
                  canPress: false,
                  val: lockedMatchesAsync,
                  dummyData: List<MatchDoc>.empty(),
                  builder: (List<MatchDoc>? data) {
                    final rs = request.scheduledTime;
                    final re = rs.add(Duration(hours: 1));
                    bool pass = _checkConflict(data, rs, re) ?? true;
                    return pass
                        ? Expanded(
                            child: FilledButton(
                              onPressed: _busy ? null : () => _runAction(() => repo.acceptRequest(requestId)),
                              child: const Text('Accept'),
                            ),
                          )
                        : Expanded(child: FilledButton(onPressed: null, child: const Text('Schedule conflict')));
                  },
                ),
              ],
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  bool? _checkConflict(List<MatchDoc>? data, DateTime rs, DateTime re) {
    return data?.every((doc) {
      final st = doc.scheduledTime;
      final et = st.add(Duration(hours: 1));
      final ol = (st.isBefore(rs) && et.isAfter(rs)) || (st.isBefore(re) && et.isAfter(re));
      return !ol;
    });
  }
}

class _UserMessage extends StatelessWidget {
  const _UserMessage({required this.isMine, required this.msg, required this.wasLastRead});

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

class _SystemMessage extends StatelessWidget {
  const _SystemMessage({required this.msg});

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

class _StatusBanner extends StatelessWidget {
  final MatchRequestStatus status;
  const _StatusBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    String? message = switch (status) {
      .declined => 'This request was declined.',
      .withdrawn => 'This request was cancelled.',
      .expired => 'This request expired.',
      .pending => 'This request has not been accepted yet. ',
      .accepted => 'This match is scheduled',
      .finished => "This match is finished",
    };

    return Container(
      decoration: ShapeDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
        ),
      ),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      child: Text(message, textAlign: TextAlign.center),
    );
  }
}

class _DetailsWidget extends StatelessWidget {
  final MatchRequestDoc request;
  final bool editing;
  final bool busy;
  final TextEditingController courtController;
  final DateTime? editedTime;
  final VoidCallback onEdit;
  final VoidCallback onPickTime;
  final VoidCallback onSave;
  final VoidCallback onCancelEdit;
  final VoidCallback onPickLocation;

  const _DetailsWidget({
    required this.request,
    required this.editing,
    required this.busy,
    required this.courtController,
    required this.editedTime,
    required this.onEdit,
    required this.onPickTime,
    required this.onSave,
    required this.onCancelEdit,
    required this.onPickLocation,
  });

  @override
  Widget build(BuildContext context) {
    final canEdit = request.status == MatchRequestStatus.pending;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: ShapeDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        ),
      ),
      child: editing
          ? Column(
              crossAxisAlignment: .stretch,
              children: [
                TextField(
                  controller: courtController,
                  decoration: const InputDecoration(labelText: 'Court', isDense: true),
                ),
                const SizedBox(height: 8),
                OutlinedButton(onPressed: onPickTime, child: Text(editedTime?.toString() ?? 'Pick date & time')),
                const SizedBox(height: 8),
                OutlinedButton(onPressed: onPickLocation, child: Text('Choose new location')),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(onPressed: busy ? null : onCancelEdit, child: const Text('Cancel')),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(onPressed: busy ? null : onSave, child: const Text('Save')),
                    ),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      Text(request.court, style: Theme.of(context).textTheme.titleSmall),
                      Text(request.scheduledTime.toLocal().toString(), style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                if (canEdit) IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined)),
                IconButton(onPressed: launchMaps, icon: const Icon(Icons.location_on_rounded)),
              ],
            ),
    );
  }

  void launchMaps() async {
    final double latitude, longitude;
    (latitude, longitude) = (request.location.latitude, request.location.longitude);
    await MapLauncher.marker(Location.coords(latitude, longitude)).show();
  }
}
