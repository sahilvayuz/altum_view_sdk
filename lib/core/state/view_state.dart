// ─────────────────────────────────────────────────────────────────────────────
// core/utils/view_state.dart
//
// A lightweight sealed class used by every Provider to represent UI state.
//
// Usage in a Provider:
//   ViewState<List<AltumAlert>> alertState = const IdleState();
//
//   Future<void> loadAlerts() async {
//     alertState = const LoadingState();
//     notifyListeners();
//     try {
//       final result = await _repo.getAlerts();
//       alertState = SuccessState(result);
//     } catch (e) {
//       alertState = ErrorState(e.toString());
//     }
//     notifyListeners();
//   }
//
// Usage in a widget:
//   switch (provider.alertState) {
//     IdleState()    => SizedBox.shrink(),
//     LoadingState() => CircularProgressIndicator(),
//     SuccessState(data: final alerts) => AlertList(alerts: alerts),
//     ErrorState(message: final msg)  => ErrorText(msg),
//   }
// ─────────────────────────────────────────────────────────────────────────────

sealed class ViewState<T> {
  const ViewState();
}

/// Not yet loaded — initial state before any action.
class IdleState<T> extends ViewState<T> {
  const IdleState();
}

/// Async operation in progress.
class LoadingState<T> extends ViewState<T> {
  const LoadingState();
}

/// Async operation completed successfully.
class SuccessState<T> extends ViewState<T> {
  final T data;
  const SuccessState(this.data);
}

/// Async operation failed.
class ErrorState<T> extends ViewState<T> {
  final String message;
  const ErrorState(this.message);
}