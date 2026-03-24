import 'package:connectivity_plus/connectivity_plus.dart';
import 'api_service.dart';

class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  late Connectivity _connectivity;
  late Stream<List<ConnectivityResult>> _connectivityStream;

  // Network configuration mapping
  static const Map<String, String> networkApiUrls = {
    'default': 'http://10.91.220.92:5000/api', // Default/Production
    'wifi': 'http://10.91.220.92:5000/api', // WiFi network
    'mobile': 'http://10.91.220.92:5000/api', // Mobile network
    'ethernet': 'http://10.91.220.92:5000/api', // Ethernet network
  };

  factory NetworkService() {
    return _instance;
  }

  NetworkService._internal() {
    _connectivity = Connectivity();
    _connectivityStream = _connectivity.onConnectivityChanged;
  }

  /// Initialize network monitoring
  Future<void> initializeNetworkMonitoring() async {
    // Set initial URL based on current network
    await _updateUrlBasedOnNetwork();

    // Listen for connectivity changes
    _connectivityStream.listen((List<ConnectivityResult> results) {
      _updateUrlBasedOnNetwork();
    });
  }

  /// Update API URL based on current network type
  Future<void> _updateUrlBasedOnNetwork() async {
    try {
      final result = await _connectivity.checkConnectivity();
      String newUrl = networkApiUrls['default']!;

      if (result.contains(ConnectivityResult.wifi)) {
        newUrl = networkApiUrls['wifi']!;
      } else if (result.contains(ConnectivityResult.mobile)) {
        newUrl = networkApiUrls['mobile']!;
      } else if (result.contains(ConnectivityResult.ethernet)) {
        newUrl = networkApiUrls['ethernet']!;
      } else if (result.contains(ConnectivityResult.none)) {
        return;
      }

      // Update API service base URL
      ApiService.setBaseUrl(newUrl);
    } catch (e) {}
  }

  /// Get current connectivity status
  Future<List<ConnectivityResult>> getCurrentNetworkStatus() async {
    return await _connectivity.checkConnectivity();
  }

  /// Check if device is connected to internet
  Future<bool> isConnected() async {
    final result = await _connectivity.checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  /// Get network type as string
  Future<String> getNetworkType() async {
    final result = await _connectivity.checkConnectivity();

    if (result.contains(ConnectivityResult.wifi)) {
      return 'WiFi';
    } else if (result.contains(ConnectivityResult.mobile)) {
      return 'Mobile';
    } else if (result.contains(ConnectivityResult.ethernet)) {
      return 'Ethernet';
    } else {
      return 'None';
    }
  }

  /// Update network URL mapping (useful for dynamic configuration)
  static void updateNetworkUrl(String networkType, String url) {
    networkApiUrls[networkType] = url;
  }
}
