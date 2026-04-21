// ─────────────────────────────────────────────────────────────────────────────
// features/people_groups/presentation/providers/person_group_provider.dart
// ─────────────────────────────────────────────────────────────────────────────

import 'package:altum_view_sdk/core/state/view_state.dart';
import 'package:altum_view_sdk/features/people_groups/domain/models/person_group_model.dart';
import 'package:flutter/foundation.dart';
import '../../domain/repositories/person_group_repository.dart';

class PersonGroupProvider extends ChangeNotifier {
  final PersonGroupRepository _repo;
  PersonGroupProvider(this._repo);

  ViewState<List<PersonGroupModel>> groupsState = const IdleState();
  ViewState<void>                   crudState   = const IdleState();

  List<PersonGroupModel> get groups =>
      groupsState is SuccessState<List<PersonGroupModel>>
          ? (groupsState as SuccessState<List<PersonGroupModel>>).data
          : [];

  // ── Load ───────────────────────────────────────────────────────────────────

  Future<void> loadGroups() async {
    groupsState = const LoadingState();
    notifyListeners();
    try {
      final data  = await _repo.getGroups();
      groupsState = SuccessState(data);
    } catch (e) {
      groupsState = ErrorState(e.toString());
    }
    notifyListeners();
  }

  // ── Create ─────────────────────────────────────────────────────────────────

  Future<void> createGroup({
    required String         name,
    PersonGroupType         type = PersonGroupType.senior,
  }) async {
    crudState = const LoadingState();
    notifyListeners();
    try {
      await _repo.createGroup(name: name, type: type);
      crudState = const SuccessState(null);
      await loadGroups();
    } catch (e) {
      crudState = ErrorState(e.toString());
      notifyListeners();
    }
  }

  // ── Update ─────────────────────────────────────────────────────────────────

  Future<void> updateGroup({
    required int             id,
    String?                  name,
    PersonGroupType?          type,
  }) async {
    crudState = const LoadingState();
    notifyListeners();
    try {
      await _repo.updateGroup(id: id, name: name, type: type);
      crudState = const SuccessState(null);
      await loadGroups();
    } catch (e) {
      crudState = ErrorState(e.toString());
      notifyListeners();
    }
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  Future<void> deleteGroup(int id) async {
    crudState = const LoadingState();
    notifyListeners();
    try {
      await _repo.deleteGroup(id);
      crudState = const SuccessState(null);
      await loadGroups();
    } catch (e) {
      crudState = ErrorState(e.toString());
      notifyListeners();
    }
  }
}