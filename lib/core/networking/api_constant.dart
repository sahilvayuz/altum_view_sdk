// ─────────────────────────────────────────────────────────────────────────────
// core/constants/api_constants.dart
//
// Single source of truth for every API URL, endpoint path, and timeout value.
// ─────────────────────────────────────────────────────────────────────────────

class ApiConstants {
  ApiConstants._();

  // ── Base ──────────────────────────────────────────────────────────────────
  static const String baseUrl = 'https://api.altumview.ca/v1.0';

  // ── Auth / Account ────────────────────────────────────────────────────────
  static const String info        = '/info';
  static const String mqttAccount = '/mqttAccount';

  // ── Rooms ─────────────────────────────────────────────────────────────────
  static const String rooms = '/rooms';
  static String roomById(int id) => '/rooms/$id';

  // ── Cameras ───────────────────────────────────────────────────────────────
  static const String cameras = '/cameras';
  static String cameraById(int id)         => '/cameras/$id';
  static String bluetoothToken(String sn)  =>
      '/cameras/bluetoothToken?serial_number=$sn';
  static String camerasBy(String sn)       =>
      '/cameras?serial_number=$sn';
  static String cameraCalibrate(int id)    => '/cameras/$id/calibrate';
  static String cameraBackground(int id)   => '/cameras/$id/background';
  static String cameraView(int id)         => '/cameras/$id/view';
  static String cameraFloormask(int id)    => '/cameras/$id/floormask/switch';
  static String cameraStreamToken(int id)  => '/cameras/$id/streamtoken';

  // ── Alerts ────────────────────────────────────────────────────────────────
  static const String alerts         = '/alerts';
  static String alertById(String id) => '/alerts/$id';
  static const String resolveAll     = '/alerts/all';

  // ── People ────────────────────────────────────────────────────────────────
  static const String people             = '/people';
  static String personById(int id)       => '/people/$id';
  static String personFaces(int id)      => '/people/$id/faces';

  // ── People Groups ─────────────────────────────────────────────────────────
  static const String personGroups        = '/people/groups';
  static String personGroupById(int id)   => '/people/groups/$id';

  // ── BLE / Camera Server ───────────────────────────────────────────────────
  static const String altumServer = 'prodca.altumview.ca';
  static const String ntpServer   = 'pool.ntp.org';
  static const String certUrl     =
      'https://cert.altumview.com/Altumview_Trust_x509.pem';
}