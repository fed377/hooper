import 'dart:developer' show log;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';

class SkeletonWidget<StateT> extends StatelessWidget {
  const SkeletonWidget({super.key, required this.val, required this.dummyData, required this.builder, this.onError});

  final AsyncValue<StateT> val;
  final StateT dummyData;
  final Widget Function(StateT) builder;
  final Widget Function(Object? error, StackTrace? trace)? onError;

  @override
  Widget build(BuildContext context) {
    if (val.hasError) {
      log(val.error.toString());
      log(val.stackTrace.toString());
      if (onError == null) {
        return Text("Something went wrong");
      } else {
        return onError!(val.error, val.stackTrace);
      }
    }

    final data = switch (val) {
      AsyncData<StateT>(value: final v) => v,
      _ => dummyData,
    };

    return Skeletonizer(enabled: val.isLoading, ignoreContainers: true, child: builder(data));
  }
}
