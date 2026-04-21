// ─────────────────────────────────────────────────────────────────────────────
// features/people/data/repositories/person_repository_impl.dart
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:typed_data';

import 'package:altum_view_sdk/core/networking/app_exception.dart';
import 'package:altum_view_sdk/features/people/data/data_source/person_remote_data_source.dart';
import 'package:altum_view_sdk/features/people/domain/models/person_model.dart';
import 'package:altum_view_sdk/features/people/domain/repositories/person_repository.dart';
import 'package:dio/dio.dart';


class PersonRepositoryImpl implements PersonRepository {
  final PersonRemoteDataSource _source;
  PersonRepositoryImpl(this._source);

  @override
  Future<List<PersonModel>> getPeople() => _safe(_source.getPeople);

  @override
  Future<int> createPerson(String friendlyName) =>
      _safe(() => _source.createPerson(friendlyName));

  @override
  Future<void> assignGroup({required int personId, required int groupId}) =>
      _safe(() => _source.assignGroup(personId: personId, groupId: groupId));

  @override
  Future<void> uploadFacePhoto({
    required int       personId,
    required Uint8List imageBytes,
    String             filename = 'face.jpg',
  }) =>
      _safe(() => _source.uploadFacePhoto(
        personId:   personId,
        imageBytes: imageBytes,
        filename:   filename,
      ));

  @override
  Future<void> deletePerson(int personId) =>
      _safe(() => _source.deletePerson(personId));

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