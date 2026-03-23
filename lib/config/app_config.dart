class AppConfig {
  // API Configuration
  static const String defaultApiUrl = 'http://10.91.220.92:5000/api';
  static const String productionApiUrl = 'https://your-production-api.com/api';

  // Environment
  static const String environment =
      'development'; // 'development', 'staging', 'production'

  // App Info
  static const String appName = 'Trip Claim App';
  static const String appVersion = '1.0.0';

  // Get current API URL based on environment
  static String getApiUrl() {
    switch (environment) {
      case 'production':
        return productionApiUrl;
      case 'staging':
        return 'https://staging-api.com/api';
      default:
        return defaultApiUrl;
    }
  }

  // API Endpoints
  static String getLoginEndpoint() => '${getApiUrl()}/auth/login';
  static String getRegisterEndpoint() => '${getApiUrl()}/auth/register';
  static String getTripClaimsEndpoint() => '${getApiUrl()}/trip-claims';
  static String getUploadEndpoint() => '${getApiUrl()}/upload';
}
