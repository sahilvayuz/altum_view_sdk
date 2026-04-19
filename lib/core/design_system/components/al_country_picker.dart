// import 'package:awesom_living/core/data/countries.dart';
// import 'package:awesom_living/core/design_system/app_spacing.dart';
// import 'package:awesom_living/core/design_system/extensions/theme_context_extensions.dart';
// import 'package:awesom_living/core/extensions/build_context_extensions.dart';
// import 'package:flutter/material.dart';
//
// Future<Country?> showCountryPicker({required BuildContext context}) {
//   return showModalBottomSheet<Country>(
//     context: context,
//     isScrollControlled: true,
//     builder: (context) => const _CountryPickerSheet(),
//   );
// }
//
// class _CountryPickerSheet extends StatefulWidget {
//   const _CountryPickerSheet();
//
//   @override
//   State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
// }
//
// class _CountryPickerSheetState extends State<_CountryPickerSheet> {
//   final _searchController = TextEditingController();
//   List<Country> _filtered = kCountries;
//
//   @override
//   void dispose() {
//     _searchController.dispose();
//     super.dispose();
//   }
//
//   void _onSearch(String query) {
//     final q = query.trim().toLowerCase();
//     setState(() {
//       _filtered = q.isEmpty
//           ? kCountries
//           : kCountries
//                 .where(
//                   (c) =>
//                       c.name.toLowerCase().contains(q) ||
//                       c.dialCode.contains(q) ||
//                       c.code.toLowerCase().contains(q),
//                 )
//                 .toList();
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return DraggableScrollableSheet(
//       initialChildSize: 0.5,
//       minChildSize: 0.3,
//       maxChildSize: 0.8,
//       builder: (context, scrollController) {
//         return Column(
//           children: [
//             const _BottomSheetHandle(),
//             Padding(
//               padding: const EdgeInsets.symmetric(
//                 horizontal: AppSpacing.md,
//                 vertical: AppSpacing.sm,
//               ),
//               child: Text(
//                 context.l10n.country_picker_title,
//                 style: context.titleMedium,
//               ),
//             ),
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
//               child: TextField(
//                 controller: _searchController,
//                 onChanged: _onSearch,
//                 decoration: InputDecoration(
//                   hintText: context.l10n.country_picker_search,
//                   prefixIcon: const Icon(Icons.search),
//                 ),
//               ),
//             ),
//             AppSpacing.verticalGapSm,
//             Expanded(
//               child: ListView.builder(
//                 controller: scrollController,
//                 itemCount: _filtered.length,
//                 itemBuilder: (context, index) {
//                   final country = _filtered[index];
//                   return ListTile(
//                     leading: Text(
//                       country.flag,
//                       style: const TextStyle(fontSize: 20),
//                     ),
//                     title: Text(country.name),
//                     trailing: Text(
//                       country.dialCode,
//                       style: context.bodySmall?.copyWith(
//                         color: context.colorScheme.onSurfaceVariant,
//                       ),
//                     ),
//                     onTap: () => Navigator.pop(context, country),
//                   );
//                 },
//               ),
//             ),
//           ],
//         );
//       },
//     );
//   }
// }
//
// class _BottomSheetHandle extends StatelessWidget {
//   const _BottomSheetHandle();
//
//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.only(top: AppSpacing.sm),
//       child: Center(
//         child: Container(
//           width: 40,
//           height: 4,
//           decoration: BoxDecoration(
//             color: context.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
//             borderRadius: const BorderRadius.all(Radius.circular(2)),
//           ),
//         ),
//       ),
//     );
//   }
// }
