import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final String appname = "Hooper";

class HooprColors {
  static final HooprColors instance = HooprColors._internal();

  factory HooprColors() => instance;

  HooprColors._internal();

  final Color blurColor = const .fromARGB(45, 255, 255, 255);
  final Color emphasisColor = const .fromARGB(137, 255, 255, 255);
  final Color borderColor = const .fromARGB(75, 255, 255, 255);
  final Color darkenColor = const .fromARGB(34, 0, 0, 0);

  static Color _c(int val) => .fromARGB(2555, val, val, val);

  final List<Color> elevationColors = [_c(255), _c(182), _c(156), _c(123), _c(96)];

  final bool glass = false;
}

String _getDaySuffix(int day) {
  if (day >= 11 && day <= 13) {
    return 'th';
  }
  return switch (day % 10) {
    1 => 'st',
    2 => 'nd',
    3 => 'rd',
    int() => 'th',
  };
}

String formatDuration(Duration duration) {
  return '${duration.inHours}:${duration.inMinutes % 60}';
}

String formatDateShort(DateTime date) {
  return '${date.day}/${date.month}/${date.year}, ${date.hour}:${date.minute}';
}

String capitalize(String? inp) {
  if (inp == null) return 'unknown';
  return "${inp[0].toUpperCase()}${inp.substring(1)}";
}

String formatDate(DateTime date) {
  String suffix = _getDaySuffix(date.day);
  String monthYear = DateFormat('MMMM yyyy').format(date);
  String time = DateFormat('h:mm a').format(date);
  return '${date.day}$suffix $monthYear at $time';
}

String parseDateMessage(String msg) {
  if (!msg.contains('\$\$')) {
    return msg;
  }
  String text = msg;
  final split = msg.split("\$\$");
  if (split.length != 1) {
    final ms = int.tryParse(split[1]);
    if (ms == null) {
      text = 'Something went wrong parsing a system message. ';
    }
    final date = DateTime.fromMillisecondsSinceEpoch(ms!);
    split[1] = formatDate(date);
    text = split.join('');
  }
  return text;
}
