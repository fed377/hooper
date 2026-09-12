import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final String appname = "Hooper";

class HooprColors extends ChangeNotifier {
  static final HooprColors instance = HooprColors._internal();

  factory HooprColors() => instance;

  HooprColors._internal();

  Color _blurColor = .fromARGB(79, 255, 255, 255);
  Color get blurColor => _blurColor;
  set blurColor(Color value) {
    if (_blurColor == value) return;
    _blurColor = value;
    notifyListeners();
  }

  Color _emphasisColor = const .fromARGB(137, 255, 255, 255);
  Color get emphasisColor => _emphasisColor;
  set emphasisColor(Color value) {
    if (_emphasisColor == value) return;
    _emphasisColor = value;
    notifyListeners();
  }

  Color _borderColor = const .fromARGB(75, 255, 255, 255);
  Color get borderColor => _borderColor;
  set borderColor(Color value) {
    if (_borderColor == value) return;
    _borderColor = value;
    notifyListeners();
  }

  Color _darkenColor = const .fromARGB(34, 0, 0, 0);
  Color _darkenSolidColor = const .fromARGB(225, 221, 221, 221);
  Color get darkenColor => glass ? _darkenColor : _darkenSolidColor;
  set darkenColor(Color value) {
    if (_darkenColor == value) return;
    _darkenColor = value;
    notifyListeners();
  }

  List<Color> _elevationColors = [
    const .fromARGB(255, 255, 255, 255),
    const .fromARGB(255, 241, 241, 241),
    const .fromARGB(255, 227, 227, 227),
    const .fromARGB(255, 213, 213, 213),
    const .fromARGB(255, 199, 199, 199),
  ];
  List<Color> get elevationColors => _elevationColors;
  set elevationColors(List<Color> value) {
    _elevationColors = value;
    notifyListeners();
  }

  bool _glass = false;
  bool get glass => _glass;
  set glass(bool value) {
    if (_glass == value) return;
    _glass = value;
    notifyListeners();
  }
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
