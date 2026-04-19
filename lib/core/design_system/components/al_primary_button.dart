// import 'package:awesom_living/core/design_system/app_radius.dart';
// import 'package:awesom_living/core/design_system/app_spacing.dart';
// import 'package:awesom_living/core/design_system/extensions/app_semantic_colors.dart';
// import 'package:awesom_living/core/design_system/extensions/theme_context_extensions.dart';
// import 'package:flutter/material.dart';
//
// class ALPrimaryButton extends StatelessWidget {
//   const ALPrimaryButton({
//     super.key,
//     required this.label,
//     this.backgroundColor,
//     this.borderSide,
//     required this.onPressed,
//     this.width = 160,
//     this.height = 60,
//     this.textStyle,
//     this.isLoading = false,
//   });
//
//   final String label;
//   final VoidCallback? onPressed;
//   final double width;
//   final double height;
//   final Color? backgroundColor;
//   final BorderSide? borderSide;
//   final TextStyle? textStyle;
//   final bool isLoading;
//
//   @override
//   Widget build(BuildContext context) {
//     final semanticColors = context.semanticColors;
//
//     return SizedBox(
//       width: width,
//       height: height,
//       child: ElevatedButton(
//         style: ButtonStyle(
//           backgroundColor: WidgetStateProperty.resolveWith((states) {
//             if (states.contains(WidgetState.disabled)) {
//               return semanticColors.disabledBackground;
//             }
//             return backgroundColor ?? context.colorScheme.onSurface;
//           }),
//           shape: WidgetStateProperty.resolveWith((states) {
//             return RoundedRectangleBorder(
//               borderRadius: AppRadius.borderRadiusMd,
//               side: states.contains(WidgetState.disabled)
//                   ? BorderSide.none
//                   : (borderSide ?? BorderSide.none),
//             );
//           }),
//           padding: WidgetStateProperty.all(
//             const EdgeInsets.symmetric(
//               horizontal: AppSpacing.xl,
//               vertical: AppSpacing.md,
//             ),
//           ),
//         ),
//         onPressed: isLoading ? null : onPressed,
//         child: AnimatedSwitcher(
//           duration: const Duration(milliseconds: 250),
//           transitionBuilder: (child, animation) {
//             return ScaleTransition(
//               scale: animation,
//               child: FadeTransition(opacity: animation, child: child),
//             );
//           },
//           child: isLoading
//               ? const _Spinner(key: ValueKey('spinner'))
//               : _Label(label, textStyle, key: const ValueKey('label')),
//         ),
//       ),
//     );
//   }
// }
//
// class _Label extends StatelessWidget {
//   const _Label(this.label, this.textStyle, {super.key});
//
//   final String label;
//   final TextStyle? textStyle;
//
//   @override
//   Widget build(BuildContext context) {
//     return Text(
//       label,
//       style:
//           textStyle ??
//           context.textTheme.titleMedium?.copyWith(
//             color: context.colorScheme.surface,
//           ),
//     );
//   }
// }
//
// class _Spinner extends StatelessWidget {
//   const _Spinner({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return SizedBox(
//       width: 24,
//       height: 24,
//       child: CircularProgressIndicator(
//         strokeWidth: 2.5,
//         color: context.colorScheme.surface,
//       ),
//     );
//   }
// }
