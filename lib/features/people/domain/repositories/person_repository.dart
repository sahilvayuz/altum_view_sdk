// ─────────────────────────────────────────────────────────────────────────────
// features/people/domain/repositories/person_repository.dart
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:typed_data';
import 'package:altum_view_sdk/features/people/domain/models/person_model.dart';


abstract interface class PersonRepository {
  Future<List<PersonModel>> getPeople();
  Future<int>               createPerson(String friendlyName);
  Future<void>              assignGroup({required int personId, required int groupId});
  Future<void>              uploadFacePhoto({
    required int       personId,
    required Uint8List imageBytes,
    String             filename,
  });
  Future<void> deletePerson(int personId);
}