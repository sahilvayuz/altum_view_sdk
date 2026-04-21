// ─────────────────────────────────────────────────────────────────────────────
// features/people/presentation/providers/person_provider.dart
// ─────────────────────────────────────────────────────────────────────────────

import 'package:altum_view_sdk/core/state/view_state.dart';
import 'package:altum_view_sdk/features/people/domain/models/person_model.dart';
import 'package:flutter/foundation.dart';
import '../../domain/repositories/person_repository.dart';

class PersonProvider extends ChangeNotifier {
  final PersonRepository _repo;
  PersonProvider(this._repo);

  ViewState<List<PersonModel>> peopleState = const IdleState();
  ViewState<void>              crudState   = const IdleState();

  List<PersonModel> get people =>
      peopleState is SuccessState<List<PersonModel>>
          ? (peopleState as SuccessState<List<PersonModel>>).data
          : [];

  // ── Load ───────────────────────────────────────────────────────────────────

  Future<void> loadPeople() async {
    peopleState = const LoadingState();
    notifyListeners();
    try {
      final data  = await _repo.getPeople();
      peopleState = SuccessState(data);
    } catch (e) {
      peopleState = ErrorState(e.toString());
    }
    notifyListeners();
  }

  // ── Create ─────────────────────────────────────────────────────────────────

  Future<int?> createPerson({
    required String  friendlyName,
    int?             groupId,
    Uint8List?       faceImageBytes,
    String           faceFilename = 'face.jpg',
  }) async {
    crudState = const LoadingState();
    notifyListeners();
    try {
      final id = await _repo.createPerson(friendlyName);

      if (groupId != null) {
        await _repo.assignGroup(personId: id, groupId: groupId);
      }
      if (faceImageBytes != null) {
        await _repo.uploadFacePhoto(
          personId:   id,
          imageBytes: faceImageBytes,
          filename:   faceFilename,
        );
      }

      crudState = const SuccessState(null);
      await loadPeople();
      return id;
    } catch (e) {
      crudState = ErrorState(e.toString());
      notifyListeners();
      return null;
    }
  }

  // ── Assign group ───────────────────────────────────────────────────────────

  Future<void> assignGroup({required int personId, required int groupId}) async {
    crudState = const LoadingState();
    notifyListeners();
    try {
      await _repo.assignGroup(personId: personId, groupId: groupId);
      crudState = const SuccessState(null);
      await loadPeople();
    } catch (e) {
      crudState = ErrorState(e.toString());
      notifyListeners();
    }
  }

  // ── Upload face photo ──────────────────────────────────────────────────────

  Future<void> uploadFacePhoto({
    required int       personId,
    required Uint8List imageBytes,
    String             filename = 'face.jpg',
  }) async {
    crudState = const LoadingState();
    notifyListeners();
    try {
      await _repo.uploadFacePhoto(
        personId:   personId,
        imageBytes: imageBytes,
        filename:   filename,
      );
      crudState = const SuccessState(null);
      await loadPeople();
    } catch (e) {
      crudState = ErrorState(e.toString());
      notifyListeners();
    }
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  Future<void> deletePerson(int personId) async {
    crudState = const LoadingState();
    notifyListeners();
    try {
      await _repo.deletePerson(personId);
      crudState = const SuccessState(null);
      await loadPeople();
    } catch (e) {
      crudState = ErrorState(e.toString());
      notifyListeners();
    }
  }
}