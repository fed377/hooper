import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';

/// Wraps the main app once a user is signed in with a profile. Bumps
/// lastActiveAt on:
///  - first build (app just became usable this session)
///  - every foreground resume (backgrounded -> resumed)
/// but not on every screen navigation, action, or Firestore read —
/// that would be a lot of writes for a field that only needs
/// "roughly how recently was this person around" accuracy.
class ActivityHeartbeat extends ConsumerStatefulWidget {
  final String uid;
  final Widget child;

  const ActivityHeartbeat({super.key, required this.uid, required this.child});

  @override
  ConsumerState<ActivityHeartbeat> createState() => _ActivityHeartbeatState();
}

class _ActivityHeartbeatState extends ConsumerState<ActivityHeartbeat> with WidgetsBindingObserver {
  DateTime? _lastSent;
  static const _minInterval = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _touch();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _touch();
    }
  }

  void _touch() {
    final now = DateTime.now();
    if (_lastSent != null && now.difference(_lastSent!) < _minInterval) return;
    _lastSent = now;
    ref.read(playerProfileRepositoryProvider).touchLastActive(widget.uid);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
