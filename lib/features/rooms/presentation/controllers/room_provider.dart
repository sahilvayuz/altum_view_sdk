// ─────────────────────────────────────────────────────────────────────────────
// features/rooms/presentation/providers/room_provider.dart
//
// Exposes room list and CRUD state to the UI.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:altum_view_sdk/core/state/view_state.dart';
import 'package:altum_view_sdk/features/rooms/domain/models/room_model.dart';
import 'package:flutter/foundation.dart';
import '../../domain/repositories/room_repository.dart';

class RoomProvider extends ChangeNotifier {
  final RoomRepository _repo;
  RoomProvider(this._repo);

  ViewState<List<RoomModel>> roomState  = const IdleState();
  ViewState<void>            crudState  = const IdleState();

  List<RoomModel> get rooms =>
      roomState is SuccessState<List<RoomModel>>
          ? (roomState as SuccessState<List<RoomModel>>).data
          : [];

  // ── Load rooms ─────────────────────────────────────────────────────────────
  Future<void> loadRooms() async {
    roomState = const LoadingState();
    notifyListeners();
    try {
      final data = await _repo.getRooms();
      roomState = SuccessState(data);
    } catch (e) {
      roomState = ErrorState(e.toString());
    }
    notifyListeners();
  }

  // ── Create ─────────────────────────────────────────────────────────────────
  Future<void> createRoom(String name) async {
    crudState = const LoadingState();
    notifyListeners();
    try {
      await _repo.createRoom(name);
      crudState = const SuccessState(null);
      await loadRooms(); // refresh list
    } catch (e) {
      crudState = ErrorState(e.toString());
      notifyListeners();
    }
  }

  // ── Update ─────────────────────────────────────────────────────────────────
  Future<void> updateRoom(int id, String name) async {
    crudState = const LoadingState();
    notifyListeners();
    try {
      await _repo.updateRoom(id, name);
      crudState = const SuccessState(null);
      await loadRooms();
    } catch (e) {
      crudState = ErrorState(e.toString());
      notifyListeners();
    }
  }

  // ── Delete ─────────────────────────────────────────────────────────────────
  Future<void> deleteRoom(int id) async {
    crudState = const LoadingState();
    notifyListeners();
    try {
      await _repo.deleteRoom(id);
      crudState = const SuccessState(null);
      await loadRooms();
    } catch (e) {
      crudState = ErrorState(e.toString());
      notifyListeners();
    }
  }
}