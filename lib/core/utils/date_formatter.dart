import 'package:flutter/services.dart';

class DateInputFormatter extends TextInputFormatter {
  static final RegExp _nonDigits = RegExp(r'\D');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (oldValue.text.length >= newValue.text.length) {
      return newValue;
    }

    final text = newValue.text.replaceAll(_nonDigits, '');

    if (text.length > 8) {
      return oldValue;
    }

    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if (i == 1 || i == 3) {
        buffer.write('/');
      }
    }

    final formatted = buffer.toString();
    return TextEditingValue(text: formatted);
  }
}
