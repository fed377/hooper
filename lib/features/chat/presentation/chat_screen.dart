import 'dart:developer' show log;
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooper/core/utils/utils.dart';
import 'package:hooper/core/widgets/blurred_container.dart';
import 'package:hooper/core/widgets/dark_buttons.dart';
import 'package:hooper/core/widgets/loading_screen_widget.dart';
import 'package:hooper/core/widgets/skeleton_widget.dart';
import 'package:hooper/features/chat/data/chat.dart';
import 'package:hooper/features/chat/data/chat_message.dart';
import 'package:hooper/features/location/presentation/location_picker.dart';
import 'package:hooper/features/matches/data/match_repo.dart';
import 'package:hooper/features/requests/data/match_request_doc.dart';
import 'package:hooper/features/requests/presentation/propose_screen.dart';
import 'package:map_launcher/map_launcher.dart';

import '../../../core/services/providers.dart';
import '../../../core/widgets/blurred_text_field.dart';
import '../../matches/data/match_doc.dart';
import 'system_message_widget.dart';
import 'user_message_widget.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String chatId;
  final String? bannerUrl;
  final String? heroTag;
  const ChatScreen({super.key, required this.chatId, this.bannerUrl, this.heroTag});

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
      body: Stack(
        children: [
          _buildHeroBackground(),
          chatAsync.when(
            loading: () => const SplashScreen(),
            error: (err, st) {
              log(st.toString());
              return Center(child: Text('Could not load this chat: $err'));
            },
            data: (chat) {
              final otherId = chat.otherParticipant(uid);
              return Stack(
                children: [
                  if (widget.bannerUrl == null) _buildFallbackBackground(otherId),
                  SafeArea(child: _buildBody(chat, uid, otherId)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // Mounted outside chatAsync so it's present on the very first frame — required for the
  // Hero flight from the matchup card to land correctly. Sharp unless glass mode is on.
  Widget _buildHeroBackground() {
    if (widget.bannerUrl == null) return const SizedBox.shrink();
    final image = Image(image: ref.watch(imageProviderFamily(widget.bannerUrl!)), fit: .cover);
    return SizedBox.expand(
      child: Hero(
        transitionOnUserGestures: true,
        tag: widget.heroTag ?? "banner",
        child: HooprColors.instance.glass
            ? ClipRect(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 20, sigmaY: 20, tileMode: .mirror),
                  child: image,
                ),
              )
            : image,
      ),
    );
  }

  Widget _buildFallbackBackground(String otherId) {
    if (!HooprColors.instance.glass) return const SizedBox.shrink();
    final url = ref.watch(playerBannerUrlProvider(otherId)).value;
    if (url == null || url.isEmpty) return const SizedBox.shrink();
    return SizedBox.expand(
      child: ClipRect(
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 20, sigmaY: 20, tileMode: .mirror),
          child: Image(image: ref.watch(imageProviderFamily(url)), fit: .cover),
        ),
      ),
    );
  }

  Widget _buildBody(Chat chat, String uid, String otherId) {
    final requestId = chat.lastMatchRequestId;

    return Column(
      children: [
        _buildHeader(otherId, requestId),
        Expanded(child: _buildChat(uid, otherId)),
        if (requestId != null) _buildActionBarForRequest(requestId, uid, otherId) else const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildHeader(String otherId, String? requestId) {
    final nameAsync = ref.watch(playerDisplayNameProvider(otherId));
    final hasRequest = requestId != null && requestId.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: BlurredContainer(
        elevation: 2,
        radius: 24,
        child: Column(
          mainAxisSize: .min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
              child: Row(
                children: [
                  IconButton(
                    padding: .zero,
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      nameAsync.value ?? 'Loading…',
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: .bold),
                    ),
                  ),
                ],
              ),
            ),
            if (hasRequest) ...[
              Divider(height: 1, color: HooprColors.instance.borderColor),
              _buildRequestDetails(requestId),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRequestDetails(String requestId) {
    final requestAsync = ref.watch(matchRequestProvider(requestId));
    return SkeletonWidget<MatchRequestDoc>(
      val: requestAsync,
      dummyData: MatchRequestDoc.dummy(),
      builder: (request) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: _DetailsWidget(
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
          ),
          _StatusBanner(status: request.status),
        ],
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
                    return SystemMessage(msg: msg);
                  }
                  final isMine = msg.senderId == uid;
                  return UserMessage(isMine: isMine, msg: msg, wasLastRead: msg.id == lastMessageIdAsync.value);
                },
              );
            },
          ),
        ),
        _buildTextBar(),
      ],
    );
  }

  Padding _buildTextBar() {
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8, top: 12),
      child: Row(
        children: [
          Expanded(
            child: BlurredTextField(
              controller: _messageController,
              message: _sendingMessage ? 'Sending...' : 'Message',
              inputFormatters: [FilteringTextInputFormatter.deny('\$')],
              onSubmitted: (_) => _sendingMessage ? null : _send(),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(icon: const Icon(Icons.send), onPressed: _sendingMessage ? null : _send),
        ],
      ),
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
                  child: FilledButton(
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

    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Container(
        decoration: ShapeDecoration(
          color: colorScheme.errorContainer.withAlpha(150),
          shape: RoundedSuperellipseBorder(borderRadius: .circular(16)),
        ),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: colorScheme.onErrorContainer),
        ),
      ),
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

    if (editing) {
      return Column(
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
      );
    }

    return Row(
      crossAxisAlignment: .center,
      children: [
        ClipRSuperellipse(
          borderRadius: .circular(16),
          child: SizedBox(
            width: 56,
            height: 56,
            child: LocationPicker.locationDisplayer(request.location, height: 56, borderRadius: 16),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: .start,
            mainAxisSize: .min,
            children: [
              Text(request.court, style: Theme.of(context).textTheme.titleSmall),
              Text(request.scheduledTime.toLocal().toString(), style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        if (canEdit) DarkIconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined), shadow: false),
        const SizedBox(width: 8),
        DarkIconButton(onPressed: launchMaps, icon: const Icon(Icons.location_on_rounded), shadow: false),
      ],
    );
  }

  void launchMaps() async {
    final double latitude, longitude;
    (latitude, longitude) = (request.location.latitude, request.location.longitude);
    await MapLauncher.marker(Location.coords(latitude, longitude)).show();
  }
}
