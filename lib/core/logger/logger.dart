// import 'dart:developer' as developer;
//
// import '../config/env.dart';
// import '../constants/app_strings.dart';
//
// abstract final class AppLogger {
//   static void debug(String message, {String? name, Object? error}) {
//     if (!Env.enableLogging) return;
//     developer.log(
//       message,
//       name: name ?? AppStrings.loggerName,
//       level: 500,
//       error: error,
//     );
//   }
//
//   static void info(String message, {String? name}) {
//     if (!Env.enableLogging) return;
//     developer.log(message, name: name ?? AppStrings.loggerName, level: 800);
//   }
//
//   static void warning(String message, {String? name, Object? error}) {
//     if (!Env.enableLogging) return;
//     developer.log(
//       message,
//       name: name ?? AppStrings.loggerName,
//       level: 900,
//       error: error,
//     );
//   }
//
//   static void error(
//     String message, {
//     String? name,
//     Object? error,
//     StackTrace? stackTrace,
//   }) {
//     if (!Env.enableLogging) return;
//     developer.log(
//       message,
//       name: name ?? AppStrings.loggerName,
//       level: 1000,
//       error: error,
//       stackTrace: stackTrace,
//     );
//   }
// }
