import 'package:screen_corner_radius/screen_corner_radius.dart';

class Utils {
  static ScreenRadius? radius;
  static double? cornerRadius;

  static Future setRadius() async {
    cornerRadius = 0;
    radius = await ScreenCornerRadius.get();
    if (radius != null) {
      cornerRadius = radius!.bottomLeft;
    } else {
      cornerRadius = 20;
    }
  }

  static final _months = [
    "January",
    "February",
    "March",
    "April",
    "May",
    "June",
    "July",
    "August",
    "September",
    "October",
    "November",
    "December",
  ];

  static String formatDate(DateTime date) {
    return '${date.day} ${_months[date.month - 1]} at ${date.hour}:${date.minute}';
  }
}
