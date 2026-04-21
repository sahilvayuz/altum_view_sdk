// ─────────────────────────────────────────────────────────────────────────────
// features/people/data/sources/person_remote_data_source.dart
//
// Extracted 1-for-1 from AltumPersonService in altum_person_service.dart.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:developer';
import 'dart:typed_data';

import 'package:altum_view_sdk/core/networking/api_constant.dart';
import 'package:altum_view_sdk/core/networking/dio_client.dart';
import 'package:altum_view_sdk/features/people/domain/models/person_model.dart';
import 'package:dio/dio.dart';


abstract interface class PersonRemoteDataSource {
  Future<List<PersonModel>> getPeople();
  Future<int>               createPerson(String friendlyName);
  Future<void>              assignGroup({required int personId, required int groupId});
  Future<void>              uploadFacePhoto({
    required int      personId,
    required Uint8List imageBytes,
    String            filename,
  });
  Future<void> deletePerson(int personId);
}

class PersonRemoteDataSourceImpl implements PersonRemoteDataSource {
  final DioClient _client;
  PersonRemoteDataSourceImpl(this._client);

  @override
  Future<List<PersonModel>> getPeople() async {
    final resp = await _client.get(ApiConstants.people);
    log('👥 GET /people → ${resp.statusCode}');
    final raw = resp.data['data']?['people']?['array'];
    final list = raw is List ? raw : <dynamic>[];
    return list.cast<Map<String, dynamic>>().map(PersonModel.fromJson).toList();
  }

  @override
  Future<int> createPerson(String friendlyName) async {
    final resp = await _client.post(
      ApiConstants.people,
      data: {'friendly_name': friendlyName},
    );
    log('➕ POST /people → ${resp.statusCode}');
    final person = resp.data['data']?['person'] as Map<String, dynamic>?;
    final id     = (person?['id'] as num?)?.toInt();
    if (id == null) throw Exception('No person ID in response');
    log('✅ Created person id=$id name=$friendlyName');
    return id;
  }

  @override
  Future<void> assignGroup({required int personId, required int groupId}) async {
    await _client.patch(
      ApiConstants.personById(personId),
      data: {'person_group_id': groupId},
    );
    log('🏷️  Assigned person $personId → group $groupId');
  }

  @override
  Future<void> uploadFacePhoto({
    required int       personId,
    required Uint8List imageBytes,
    String             filename = 'face.jpg',
  }) async {
    final formData = FormData.fromMap({
      'image': MultipartFile.fromBytes(imageBytes, filename: filename),
    });
    await _client.postFormData(ApiConstants.personFaces(personId), formData: formData);
    log('📷 Face photo uploaded for person $personId');
  }

  @override
  Future<void> deletePerson(int personId) async {
    await _client.delete(ApiConstants.personById(personId));
    log('🗑️  Person $personId deleted');
  }
}