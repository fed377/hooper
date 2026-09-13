import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final String appname = "Hooper";

class HooprTheme {
  static final HooprTheme instance = HooprTheme._internal();

  factory HooprTheme() => instance;

  HooprTheme._internal();

  Color blurColor = .fromARGB(79, 255, 255, 255);
  Color emphasisColor = const .fromARGB(137, 255, 255, 255);
  Color borderColor = const .fromARGB(75, 255, 255, 255);

  Color _darkenColor = const .fromARGB(34, 0, 0, 0);
  final Color _darkenSolidColor = const .fromARGB(225, 221, 221, 221);
  Color get darkenColor => glass ? _darkenColor : _darkenSolidColor;
  set darkenColor(Color value) => _darkenColor = value;

  List<Color> elevationColors = [
    const .fromARGB(255, 255, 255, 255),
    const .fromARGB(255, 241, 241, 241),
    const .fromARGB(255, 227, 227, 227),
    const .fromARGB(255, 213, 213, 213),
    const .fromARGB(255, 199, 199, 199),
  ];

  final ValueNotifier<bool> glassNotifier = ValueNotifier(false);
  bool get glass => glassNotifier.value;
  set glass(bool value) => glassNotifier.value = value;

  BoxShadow blurredContainerShadow = const BoxShadow(
    color: .fromARGB(45, 0, 0, 0),
    spreadRadius: -1,
    blurRadius: 20,
  );
  BoxShadow textFieldShadow = const BoxShadow(
    color: .fromARGB(45, 0, 0, 0),
    spreadRadius: -1,
    blurRadius: 20,
  );
  BoxShadow pickerShadow = const BoxShadow(
    color: .fromARGB(45, 0, 0, 0),
    spreadRadius: -1,
    blurRadius: 10,
  );
  BoxShadow filledButtonShadow = const BoxShadow(
    color: .fromARGB(45, 0, 0, 0),
    spreadRadius: -1,
    blurRadius: 20,
  );
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

final DateFormat _monthYearFormat = DateFormat('MMMM yyyy');
final DateFormat _timeFormat = DateFormat('h:mm a');

String formatDate(DateTime date) {
  String suffix = _getDaySuffix(date.day);
  String monthYear = _monthYearFormat.format(date);
  String time = _timeFormat.format(date);
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
