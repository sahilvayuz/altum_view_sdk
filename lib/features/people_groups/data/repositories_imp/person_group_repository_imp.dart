// ─────────────────────────────────────────────────────────────────────────────
// features/people_groups/data/repositories/person_group_repository_impl.dart
// ─────────────────────────────────────────────────────────────────────────────

import 'package:altum_view_sdk/core/networking/app_exception.dart';
import 'package:altum_view_sdk/features/people_groups/data/data_source/person_group_remote_data_source.dart';
import 'package:altum_view_sdk/features/people_groups/domain/models/person_group_model.dart';
import 'package:altum_view_sdk/features/people_groups/domain/repositories/person_group_repository.dart';
import 'package:dio/dio.dart';

class PersonGroupRepositoryImpl implements PersonGroupRepository {
  final PersonGroupRemoteDataSource _source;
  PersonGroupRepositoryImpl(this._source);

  @override
  Future<List<PersonGroupModel>> getGroups() => _safe(_source.getGroups);

  @override
  Future<int> createGroup({
    required String         name,
    PersonGroupType         type = PersonGroupType.senior,
  }) =>
      _safe(() => _source.createGroup(name: name, type: type));

  @override
  Future<void> updateGroup({
    required int             id,
    String?                  name,
    PersonGroupType?          type,
  }) =>
      _safe(() => _source.updateGroup(id: id, name: name, type: type));

  @override
  Future<void> deleteGroup(int id) => _safe(() => _source.deleteGroup(id));

  Future<T> _safe<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw e.error is AppException
          ? e.error as AppException
          : ApiException(e.message ?? 'Unknown error');
    }
  }
}