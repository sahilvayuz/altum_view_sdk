# 🖥️ feature/presentation/

The presentation layer contains everything the user sees and interacts with.

---

## Structure

```
presentation/
├── providers/              ← State management (ChangeNotifier)
├── screens/                ← Full-page screens (one per route)
└── widgets/                ← Small UI pieces used only in this feature
```

---

## providers/

The provider holds all state for the feature and calls the repository.  
It never calls services directly — only through the repository.

```dart
class DeviceConnectionProvider extends ChangeNotifier {
  final DeviceRepository _repository;
  DeviceConnectionProvider(this._repository);

  // State
  List<DeviceEntity> devices = [];
  bool isLoading = false;
  String? errorMessage;

  // Action
  Future<void> loadDevices() async {
    isLoading = true;
    notifyListeners();                          // Tell widgets to rebuild

    try {
      devices = await _repository.getDevices();
    } catch (e) {
      errorMessage = 'Failed to load devices';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
```

**In widgets:**
```dart
// Read state (rebuilds on change)
final provider = context.watch<DeviceConnectionProvider>();

// Call an action (no rebuild from this line)
context.read<DeviceConnectionProvider>().loadDevices();
```

---

## screens/

One file = one full-page route. Screens are thin — they just compose widgets.

```dart
class DeviceConnectionScreen extends StatefulWidget { ... }

// In initState — trigger initial data load
Future.microtask(() => context.read<DeviceConnectionProvider>().loadDevices());

// In build — react to provider state
Widget build(BuildContext context) {
  final provider = context.watch<DeviceConnectionProvider>();
  if (provider.isLoading) return const AppLoadingIndicator();
  return ListView.builder(...);
}
```

---

## widgets/

Break each screen into small focused widgets.  
A widget does **one thing** and gets all its data from constructor params — not from Provider directly (unless it's a leaf widget that reads state).

```dart
// Good — widget receives data it needs
class DeviceListTile extends StatelessWidget {
  final DeviceEntity device;
  final VoidCallback onTap;
  ...
}

// Bad — widget fetches its own data
class DeviceListTile extends StatelessWidget {
  Widget build(context) {
    final devices = context.watch<DeviceConnectionProvider>().devices; // ❌
    ...
  }
}
```

---

## Rules

- ✅ One provider per feature — keep state scoped
- ✅ Screens are thin — logic goes in the provider
- ✅ `context.watch` in screens/parent widgets, pass data down to children
- ✅ Feature-specific widgets stay inside `presentation/widgets/`
- ✅ Reused widgets go in `shared/widgets/`
- ❌ Never call a service directly from a widget
