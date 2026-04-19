// import 'package:altum_view_sdk/core/design_system/app_spacing.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
//
// /// A labelled text field with the label rendered above the input.
// ///
// /// Validation fires on [AutovalidateMode.onUserInteraction] so errors appear
// /// as soon as the user leaves the field.
// class ALTextField extends StatelessWidget {
//   const ALTextField({
//     super.key,
//     required this.controller,
//     required this.label,
//     this.hint,
//     this.validator,
//     this.keyboardType,
//     this.textInputAction,
//     this.inputFormatters,
//     this.prefixIcon,
//     this.suffixIcon,
//     this.obscureText = false,
//     this.onChanged,
//     this.focusNode,
//     this.onFieldSubmitted,
//     this.autovalidateMode = AutovalidateMode.onUserInteraction,
//     this.autocorrect = true,
//     this.enableSuggestions = true,
//     this.maxLength,
//   });
//
//   final TextEditingController controller;
//   final String label;
//   final String? hint;
//   final String? Function(String?)? validator;
//   final TextInputType? keyboardType;
//   final TextInputAction? textInputAction;
//   final List<TextInputFormatter>? inputFormatters;
//   final Widget? prefixIcon;
//   final Widget? suffixIcon;
//   final bool obscureText;
//   final void Function(String)? onChanged;
//   final FocusNode? focusNode;
//   final void Function(String)? onFieldSubmitted;
//   final AutovalidateMode autovalidateMode;
//   final bool autocorrect;
//   final bool enableSuggestions;
//   final int? maxLength;
//
//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(label, style: context.bodySmall),
//         AppSpacing.verticalGapXs,
//         TextFormField(
//           controller: controller,
//           focusNode: focusNode,
//           decoration: InputDecoration(
//             hintText: hint,
//             prefixIcon: prefixIcon,
//             suffixIcon: suffixIcon,
//             counterText: '',
//           ),
//           validator: validator,
//           autovalidateMode: autovalidateMode,
//           keyboardType: keyboardType,
//           textInputAction: textInputAction,
//           inputFormatters: inputFormatters,
//           obscureText: obscureText,
//           onChanged: onChanged,
//           onFieldSubmitted: onFieldSubmitted,
//           autocorrect: autocorrect,
//           enableSuggestions: enableSuggestions,
//           maxLength: maxLength,
//         ),
//       ],
//     );
//   }
// }
