// ─────────────────────────────────────────────────────────────────────────────
// core/di/service_locator.dart
//
// Wires every feature's layers together in one place.
// Call ServiceLocator.init(accessToken) once at app start (e.g. after login).
//
// Pattern used: manual service locator via a plain Dart class.
// If you prefer get_it, replace the static fields with get_it registrations —
// the constructor arguments stay identical.
//
// ──────────────────────────────────────────────────────────────────────────────
// LAYER ORDER (bottom → top):
//   DioClient
//   └─ RemoteDataSource(s)
//      └─ RepositoryImpl
//         └─ Provider
// ─────────────────────────────────────────────────────────────────────────────

import 'package:altum_view_sdk/core/networking/dio_client.dart';
import 'package:altum_view_sdk/core/services/ble_services.dart';
import 'package:altum_view_sdk/features/alerts/data/data_source/alert_remote_data_source.dart';
import 'package:altum_view_sdk/features/alerts/data/repositories_implementation/alert_repository_imp.dart';
import 'package:altum_view_sdk/features/alerts/presentation/controller/alert_provider.dart';
import 'package:altum_view_sdk/features/calibration/data/data_source/calibration_remote_data_source.dart';
import 'package:altum_view_sdk/features/calibration/data/repository_implimentation/calibration_repository_imp.dart';
import 'package:altum_view_sdk/features/calibration/presentation/controllers/calibration_provider.dart';
import 'package:altum_view_sdk/features/camera/data/data_source/camera_remote_data_source.dart';
import 'package:altum_view_sdk/features/camera/data/repositories_implementation/camera_repo_imp.dart';
import 'package:altum_view_sdk/features/camera/presentation/controllers/camera_provider.dart';
import 'package:altum_view_sdk/features/device_connection/data/data_source_implimentation/camera_setup_remote_data_source.dart';
import 'package:altum_view_sdk/features/device_connection/data/repositories_implimentation/device_connection_repository_imp.dart';
import 'package:altum_view_sdk/features/device_connection/presentation/controller/device_connection_provider.dart';
import 'package:altum_view_sdk/features/device_settings/data/data_source/device_settings_remote_data_source.dart';
import 'package:altum_view_sdk/features/device_settings/data/repositories_implimentation/device_settings_repo_imp.dart';
import 'package:altum_view_sdk/features/device_settings/presentation/controllers/device_settings_provider.dart';
import 'package:altum_view_sdk/features/people/data/data_source/person_remote_data_source.dart';
import 'package:altum_view_sdk/features/people/data/repositories_implementation/person_repository_imp.dart';
import 'package:altum_view_sdk/features/people/presentation/controller/person_provider.dart';
import 'package:altum_view_sdk/features/people_groups/data/data_source/person_group_remote_data_source.dart';
import 'package:altum_view_sdk/features/people_groups/data/repositories_imp/person_group_repository_imp.dart';
import 'package:altum_view_sdk/features/people_groups/presentation/controller/person_group_provider.dart';
import 'package:altum_view_sdk/features/rooms/data/room_remote_data_source.dart';
import 'package:altum_view_sdk/features/rooms/data/room_repository_impl.dart';
import 'package:altum_view_sdk/features/rooms/presentation/controllers/room_provider.dart';
import 'package:altum_view_sdk/features/skeleton_stream/data/repositories_implementation/skeleton_stream_repository_impl.dart';
import 'package:altum_view_sdk/features/skeleton_stream/presentation/controllers/skeleton_stream_provider.dart';
import 'package:altum_view_sdk/features/skeleton_stream/presentation/managers/skeleton_stream_manager.dart';
import 'package:altum_view_sdk/features/wifi_connection/data/data_source_implimentation/wifi_data_source.dart';
import 'package:altum_view_sdk/features/wifi_connection/data/repositories_implimentation/wifi_repository_imp.dart';
import 'package:altum_view_sdk/features/wifi_connection/presentation/controller/wifi_provider.dart';


class ServiceLocator {
  ServiceLocator._();

  // ── Shared ─────────────────────────────────────────────────────────────────
  static late DioClient    _dioClient;
  static late BleService   _bleService;

  // ── Providers (one per feature) ────────────────────────────────────────────
  static late CameraProvider           cameraProvider;
  static late RoomProvider             roomProvider;
  static late DeviceConnectionProvider deviceConnectionProvider;
  static late WifiProvider             wifiProvider;
  static late CalibrationProvider      calibrationProvider;
  static late SkeletonStreamProvider   skeletonStreamProvider;
  static late AlertProvider            alertProvider;
  static late PersonProvider           personProvider;
  static late PersonGroupProvider      personGroupProvider;
  static late DeviceSettingsProvider   deviceSettingsProvider;

  // ── Skeleton stream requires camera context; call this after stream starts ─
  static SkeletonStreamProvider buildSkeletonProvider({
    required int    cameraId,
    required String serialNumber,
  }) {
    final manager = SkeletonStreamManager(
      client:       _dioClient,
      cameraId:     cameraId,
      serialNumber: serialNumber,
    );
    final repo = SkeletonStreamRepositoryImpl(manager);
    return SkeletonStreamProvider(repo);
  }

  // ── Main init ──────────────────────────────────────────────────────────────

  static void init(String accessToken) {
    // ── 1. Network layer ──────────────────────────────────────────────────────
    _dioClient  = DioClient(accessToken: accessToken);
    _bleService = BleService();

    // ── 2. altum_view ─────────────────────────────────────────────────────────
    final cameraSource = CameraRemoteDataSourceImpl(_dioClient);
    final cameraRepo   = CameraRepositoryImpl(cameraSource);
    cameraProvider     = CameraProvider(cameraRepo);

    // ── 3. rooms ──────────────────────────────────────────────────────────────
    final roomSource = RoomRemoteDataSourceImpl(_dioClient);
    final roomRepo   = RoomRepositoryImpl(roomSource);
    roomProvider     = RoomProvider(roomRepo);

    // ── 4. device_connection ──────────────────────────────────────────────────
    final setupSource  = CameraSetupRemoteDataSourceImpl(_dioClient);
    final connRepo     = DeviceConnectionRepositoryImpl(
      bleService:  _bleService,
      cloudSource: setupSource,
    );
    deviceConnectionProvider = DeviceConnectionProvider(connRepo);

    // ── 5. wifi_connection ────────────────────────────────────────────────────
    final wifiSource = WifiDataSource(_bleService);
    final wifiRepo   = WifiRepositoryImpl(wifiSource);
    wifiProvider     = WifiProvider(wifiRepo);

    // ── 6. calibration ────────────────────────────────────────────────────────
    final calSource  = CalibrationRemoteDataSourceImpl(
      client:     _dioClient,
      bleService: _bleService,
    );
    final calRepo    = CalibrationRepositoryImpl(calSource);
    calibrationProvider = CalibrationProvider(calRepo);

    // ── 7. skeleton_stream — built lazily (needs cameraId at runtime) ─────────
    // Use buildSkeletonProvider(cameraId, serialNumber) when opening the stream.

    // ── 8. alerts ─────────────────────────────────────────────────────────────
    final alertSource = AlertRemoteDataSourceImpl(_dioClient);
    final alertRepo   = AlertRepositoryImpl(alertSource);
    alertProvider     = AlertProvider(alertRepo);

    // ── 9. people ─────────────────────────────────────────────────────────────
    final personSource = PersonRemoteDataSourceImpl(_dioClient);
    final personRepo   = PersonRepositoryImpl(personSource);
    personProvider     = PersonProvider(personRepo);

    // ── 10. people_groups ─────────────────────────────────────────────────────
    final groupSource = PersonGroupRemoteDataSourceImpl(_dioClient);
    final groupRepo   = PersonGroupRepositoryImpl(groupSource);
    personGroupProvider = PersonGroupProvider(groupRepo);

    // ── 11. device_settings ───────────────────────────────────────────────────
    final settingsSource = DeviceSettingsRemoteDataSourceImpl(_dioClient);
    final settingsRepo   = DeviceSettingsRepositoryImpl(settingsSource);
    deviceSettingsProvider = DeviceSettingsProvider(settingsRepo);
  }

  /// Call when the user's access token is refreshed.
  static void updateToken(String newToken) {
    _dioClient.updateToken(newToken);
  }
}