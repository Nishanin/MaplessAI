/// Networking and API constants
abstract final class ApiConstants {
  // Frozen backend base URL (Port 3000)
  static const String defaultBaseUrl = 'http://10.0.2.2:3000'; // For Android emulator, or localhost for web/desktop
  static const String localhostBaseUrl = 'http://localhost:3000';

  static const String healthEndpoint = '/health';
  static const String mappingPrefix = '/api/v1/mapping';
  static const String navigationPrefix = '/api/v1/navigation';
  static const String aiPrefix = '/api/v1/ai';
  static const String versioningPrefix = '/api/v1/versioning';

  static const Duration defaultTimeout = Duration(seconds: 15);
}
