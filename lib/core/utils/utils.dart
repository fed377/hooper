import 'package:intl/intl.dart';

final String appname = "Hooper";

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
