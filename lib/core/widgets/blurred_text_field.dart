import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooper/core/utils/utils.dart';

class BlurredTextField extends StatelessWidget {
  const new({
    super.key,
    this._controller,
    required this._message,
    this._onSubmitted,
    this._onChanged,
    this.keyboardType,
    this.autocorrect = false,
    this.autofillHints = const [],
    this.obscureText = false,
    this.enabled = true,
    this.maxLines = 1,
    this.maxLength,
    this.inputFormatters,
  });

  final TextEditingController? _controller;
  final String _message;
  final void Function(String)? _onChanged;
  final void Function(String)? _onSubmitted;
  final TextInputType? keyboardType;
  final bool autocorrect;
  final List<String> autofillHints;
  final bool obscureText;
  final bool enabled;
  final int maxLines;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    final colors = HooprTheme.instance;
    final glass = colors.glass;

    final field = TextField(
      maxLength: maxLength,
      obscureText: obscureText,
      keyboardType: keyboardType,
      autocorrect: autocorrect,
      autofillHints: autofillHints,
      inputFormatters: inputFormatters,
      onChanged: _onChanged,
      controller: _controller,
      enabled: enabled,
      maxLines: maxLines,
      decoration: InputDecoration(
        counter: const SizedBox(),
        filled: true,
        fillColor: glass ? colors.blurColor : colors.elevationColors[0],
        focusColor: colors.emphasisColor,
        hintText: _message,
        isDense: true,
        enabledBorder: ShapedInputBorder(
          shape: RoundedSuperellipseBorder(borderRadius: .circular(22)),
          borderSide: glass
              ? .new(color: colors.borderColor, strokeAlign: 0)
              : .none,
        ),
        focusedBorder: ShapedInputBorder(
          shape: RoundedSuperellipseBorder(borderRadius: .circular(22)),
          borderSide: glass ? .new(color: colors.borderColor) : .none,
        ),
      ),
      onSubmitted: _onSubmitted,
    );

    Widget content = ClipRSuperellipse(
      borderRadius: .circular(22),
      child: glass
          ? BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: 10,
                sigmaY: 10,
                tileMode: .mirror,
              ),
              child: field,
            )
          : field,
    );

    if (!glass) {
      content = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [colors.textFieldShadow],
        ),
        child: content,
      );
    }

    return RepaintBoundary(child: content);
  }
}

class BlurredFormField extends FormField<String> {
  BlurredFormField({
    super.key,
    TextEditingController? controller,
    super.validator,
    super.onSaved,
    String message = '',
    double borderRadius = 22.0,
    EdgeInsets contentPadding = const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 14,
    ),
    double blurSigma = 10.0,
    TextInputType? keyboardType,
    bool enabled = true,
    void Function(String)? onChanged,
    bool border = true,
    int? maxLength,
    int maxLines = 1,
    List<TextInputFormatter>? inputFormatters,
  }) : super(
         initialValue: controller?.text,
         builder: (FormFieldState<String> state) {
           final colors = HooprTheme.instance;
           final glass = colors.glass;
           final shouldBorder = border && glass;

           final field = TextField(
             maxLength: maxLength,
             maxLines: maxLines,
             buildCounter: (
               context, {
               required currentLength,
               required isFocused,
               required maxLength,
             }) => null,
             keyboardType: keyboardType,
             inputFormatters: inputFormatters,
             controller: controller,
             onChanged: (value) {
               state.didChange(value);
               if (onChanged != null) onChanged(value);
             },
             textAlignVertical: TextAlignVertical.center,
             decoration: InputDecoration(
               contentPadding: EdgeInsets.all(15),
               fillColor: glass ? colors.blurColor : colors.elevationColors[0],
               focusColor: colors.emphasisColor,
               filled: true,
               hintText: message,
               enabledBorder: ShapedInputBorder(
                 shape: RoundedSuperellipseBorder(borderRadius: .circular(22)),
                 borderSide: !shouldBorder
                     ? .none
                     : .new(color: colors.borderColor),
               ),
               focusedBorder: ShapedInputBorder(
                 shape: RoundedSuperellipseBorder(borderRadius: .circular(22)),
                 borderSide: !shouldBorder
                     ? .none
                     : .new(color: colors.borderColor),
               ),
               errorBorder: ShapedInputBorder(
                 shape: RoundedSuperellipseBorder(borderRadius: .circular(22)),
                 borderSide: !shouldBorder
                     ? .none
                     : .new(color: colors.borderColor),
               ),
             ),
           );

           Widget content = ClipRSuperellipse(
             borderRadius: BorderRadius.circular(borderRadius),
             child: glass
                 ? BackdropFilter(
                     filter: ImageFilter.blur(
                       sigmaX: blurSigma,
                       sigmaY: blurSigma,
                     ),
                     child: field,
                   )
                 : field,
           );

           if (!glass) {
             content = DecoratedBox(
               decoration: BoxDecoration(
                 borderRadius: BorderRadius.circular(borderRadius),
                 boxShadow: [colors.textFieldShadow],
               ),
               child: content,
             );
           }

           return Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             mainAxisSize: MainAxisSize.min,
             children: [
               content,
               if (state.hasError &&
                   state.errorText != null &&
                   state.errorText?.trim() != '')
                 Padding(
                   padding: const EdgeInsets.only(top: 6, left: 12),
                   child: Text(
                     state.errorText!,
                     style: TextStyle(
                       color: Theme.of(state.context).colorScheme.error,
                       fontSize: 12,
                     ),
                   ),
                 ),
             ],
           );
         },
       );
}
