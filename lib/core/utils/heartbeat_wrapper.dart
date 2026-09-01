import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/providers.dart';

class HeartbeatWrapper extends ConsumerStatefulWidget {
  final String uid;
  final Widget child;

  const HeartbeatWrapper({super.key, required this.uid, required this.child});

  @override
  ConsumerState<HeartbeatWrapper> createState() => _ActivityHeartbeatState();
}

class _ActivityHeartbeatState extends ConsumerState<HeartbeatWrapper> with WidgetsBindingObserver {
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
    final DateTime now = .now();
    if (_lastSent != null && now.difference(_lastSent!) < _minInterval) return;
    _lastSent = now;
    ref.read(playerProfileRepositoryProvider).touchLastActive(widget.uid);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
