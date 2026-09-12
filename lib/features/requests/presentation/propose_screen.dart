import 'dart:developer' show log;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hooper/core/widgets/blurred_container.dart';
import 'package:hooper/core/widgets/dark_buttons.dart';
import 'package:hooper/features/chat/presentation/chat_screen.dart';
import 'package:hooper/features/discovery/data/matchups_repo.dart';
import 'package:hooper/features/location/presentation/location_picker.dart';
import 'package:hooper/features/matches/data/match_doc.dart';

import '../../../core/services/providers.dart';
import '../../../core/widgets/blurred_text_field.dart';
import '../../../core/widgets/skeleton_widget.dart';
import '../../discovery/data/matchup.dart';

class ProposeMatchScreen extends ConsumerStatefulWidget {
  final String? targetId;
  final Matchup? matchup;
  const ProposeMatchScreen({super.key, this.targetId, this.matchup});

  static void pushProposal(String targetId, BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProposeMatchScreen(targetId: targetId)));
  }

  static void pushProposalWithMatchup(Matchup targetMatchup, BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProposeMatchScreen(matchup: targetMatchup)));
  }

  @override
  ConsumerState<ProposeMatchScreen> createState() => _ProposeMatchScreenState();
}

class _ProposeMatchScreenState extends ConsumerState<ProposeMatchScreen> {
  final _courtController = TextEditingController();
  DateTime? _selectedTime;
  bool _sending = false;
  LocationPickerController locationController = LocationPickerController(point: GeoPoint(0, 0));
  bool _private = false;
  bool _friendly = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prefsAsync = ref.read(myPreferencesProvider);
      prefsAsync.whenData((prefs) {
        if (mounted) {
          setState(() {
            _private = prefs.defaultPrivate;
            _friendly = prefs.defaultFriendly;
          });
        }
      });
    });
  }

  Future<void> _pickTime() async {
    final date = await showDatePicker(
      context: context,
      firstDate: .now(),
      lastDate: .now().add(const Duration(days: 14)),
      initialDate: .now().add(Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time == null) return;
    setState(() {
      _selectedTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _send(String? bannerUrl, String heroTag) async {
    final court = _courtController.text.trim();
    if (court.isEmpty || _selectedTime == null) return;
    if (!locationController.hasMoved) return;
    setState(() => _sending = true);
    try {
      final repo = ref.read(matchupRepositoryProvider);
      final response = await repo.proposeMatch(
        targetId: (widget.targetId ?? widget.matchup?.id)!,
        court: court,
        scheduledTime: _selectedTime!,
        location: GeoPoint(locationController.point.latitude, locationController.point.longitude),
        friendly: _friendly,
        private: _private,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ChatScreen(chatId: response.chatId, bannerUrl: bannerUrl, heroTag: heroTag),
        ),
      );
    } on ProposalException catch (e) {
      if (!mounted) return;
      log(e.toString());
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.matchup != null) {
      return _buildBody(context, widget.matchup!);
    }
    final matchupAsync = ref.watch(matchupFromIdProvider(widget.targetId!));
    return SkeletonWidget<Matchup>(
      val: matchupAsync,
      dummyData: Matchup.dummy(),
      builder: (data) => _buildBody(context, data),
    );
  }

  Widget _buildBody(BuildContext context, Matchup target) {
    final lockedMatchesAsync = ref.watch(lockedMatchesProvider);
    final locationAsync = ref.read(myLocationProvider);
    return Scaffold(
      body: Stack(
        children: [
          SizedBox.expand(
            child: Hero(
              transitionOnUserGestures: true,
              tag: "banner_${target.id}",
              child: target.bannerUrl == null || target.bannerUrl == ''
                  ? const SizedBox()
                  : GestureDetector(
                      onTap: Navigator.of(context).pop,
                      child: Image(image: ref.read(imageProviderFamily(target.bannerUrl!)), fit: BoxFit.cover),
                    ),
            ),
          ),
          SizedBox.expand(
            child: Padding(
              padding: .only(top: 12, bottom: 12, left: 12, right: 12),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: BlurredContainer(
                  elevation: 1,
                  child: Padding(
                    padding: const .all(16),
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: Column(
                        mainAxisSize: .min,
                        mainAxisAlignment: .end,
                        crossAxisAlignment: .start,
                        children: [
                          Text(
                            'Challenge ${target.displayName}',
                            style: TextTheme.of(context).headlineMedium
                                ?.copyWith(fontWeight: .w900, color: Colors.black.withAlpha(170)),
                          ),
                          Text('Where do you want to play?', style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 8),
                          BlurredTextField(
                            controller: _courtController,
                            onChanged: (_) => setState(() {}),
                            message: 'Court',
                            onSubmitted: (_) {},
                          ),
                          const SizedBox(height: 16),
                          locationAsync.when(
                            data: (Position pos) {
                              locationController.point = GeoPoint(pos.latitude, pos.longitude);
                              return LocationPicker(controller: locationController);
                            },
                            error: (Object error, StackTrace stackTrace) {
                              return Container();
                            },
                            loading: () {
                              return Container();
                            },
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Checkbox(value: _private, onChanged: (v) => setState(() => _private = v ?? false)),
                              const Text('Private'),
                            ],
                          ),
                          Row(
                            children: [
                              Checkbox(value: _friendly, onChanged: (v) => setState(() => _friendly = v ?? false)),
                              const Text('Friendly'),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: .spaceBetween,
                            children: [
                              Text('When?', style: Theme.of(context).textTheme.titleMedium),
                              FilledButton(
                                onPressed: _pickTime,
                                child: Text(_selectedTime == null ? 'Pick date & time' : _selectedTime.toString()),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: SkeletonWidget<List<MatchDoc>?>(
                                  val: lockedMatchesAsync,
                                  dummyData: [],
                                  builder: (data) {
                                    bool pass = checkPass(data);
                                    return DarkFilledButton(
                                      shadow: false,
                                      onPressed: (_courtController.text.trim().isNotEmpty && !_sending && pass)
                                          ? () => _send(target.bannerUrl, "banner_${target.id}")
                                          : null,
                                      child: const Text('Send challenge'),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ).asHero("mainchip"),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool? _checkConflict(List<MatchDoc>? data, DateTime requestStart, DateTime requestEnd) {
    return data?.every((doc) {
      final startTime = doc.scheduledTime;
      final endTime = startTime.add(Duration(hours: 1));
      final canPass =
          (startTime.isBefore(requestStart) && endTime.isBefore(requestStart)) ||
          (endTime.isAfter(requestEnd) && startTime.isAfter(requestEnd));
      return canPass;
    });
  }

  bool checkPass(List<MatchDoc>? data) {
    final rs = _selectedTime;
    if (rs == null) return false;
    final re = rs.add(Duration(hours: 1));
    bool pass = _checkConflict(data, rs, re) ?? true;
    return pass;
  }
}
