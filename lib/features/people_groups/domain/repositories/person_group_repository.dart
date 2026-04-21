// ─────────────────────────────────────────────────────────────────────────────
// features/people_groups/domain/repositories/person_group_repository.dart
// ─────────────────────────────────────────────────────────────────────────────


import 'package:altum_view_sdk/features/people_groups/domain/models/person_group_model.dart';

abstract interface class PersonGroupRepository {
  Future<List<PersonGroupModel>> getGroups();
  Future<int>                    createGroup({required String name, PersonGroupType type});
  Future<void>                   updateGroup({required int id, String? name, PersonGroupType? type});
  Future<void>                   deleteGroup(int id);
}