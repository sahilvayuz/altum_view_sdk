// ─────────────────────────────────────────────────────────────────────────────
// features/people_groups/data/sources/person_group_remote_data_source.dart
//
// Extracted 1-for-1 from AltumPersonGroupService in altum_person_group_service.dart.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:developer';

import 'package:altum_view_sdk/core/networking/api_constant.dart';
import 'package:altum_view_sdk/core/networking/dio_client.dart';
import 'package:altum_view_sdk/features/people_groups/domain/models/person_group_model.dart';

abstract interface class PersonGroupRemoteDataSource {
  Future<List<PersonGroupModel>> getGroups();
  Future<int>                    createGroup({required String name, PersonGroupType type});
  Future<void>                   updateGroup({required int id, String? name, PersonGroupType? type});
  Future<void>                   deleteGroup(int id);
}

class PersonGroupRemoteDataSourceImpl implements PersonGroupRemoteDataSource {
  final DioClient _client;
  PersonGroupRemoteDataSourceImpl(this._client);

  @override
  Future<List<PersonGroupModel>> getGroups() async {
    final resp = await _client.get(ApiConstants.personGroups);
    log('👥 GET /people/groups → ${resp.statusCode}');
    final raw  = resp.data['data']?['person_groups']?['array'] as List? ?? [];
    return raw.cast<Map<String, dynamic>>().map(PersonGroupModel.fromJson).toList();
  }

  @override
  Future<int> createGroup({
    required String          name,
    PersonGroupType          type = PersonGroupType.senior,
  }) async {
    final resp = await _client.post(
      ApiConstants.personGroups,
      data: {'name': name, 'type': type.value},
    );
    log('➕ POST /people/groups → ${resp.statusCode}');
    final id = (resp.data['data']?['person_group']?['id'] as num?)?.toInt();
    if (id == null) throw Exception('No group ID in response');
    log('✅ Created group id=$id name=$name type=${type.label}');
    return id;
  }

  @override
  Future<void> updateGroup({
    required int              id,
    String?                   name,
    PersonGroupType?           type,
  }) async {
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    if (type != null) payload['type'] = type.value;
    await _client.patch(ApiConstants.personGroupById(id), data: payload);
    log('✏️  PATCH /people/groups/$id → done');
  }

  @override
  Future<void> deleteGroup(int id) async {
    await _client.delete(ApiConstants.personGroupById(id));
    log('🗑️  Group $id deleted');
  }
}