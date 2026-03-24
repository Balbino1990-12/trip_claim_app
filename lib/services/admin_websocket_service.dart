import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'dart:convert';

typedef StatusUpdatedCallback = void Function(Map<String, dynamic> data);

class AdminWebSocketService {
  static WebSocketChannel? _channel;
  static StatusUpdatedCallback? _onStatusUpdated;
  static Function? _onNewClaim;
  static Function? _onClaimsChanged;

  /// Connect to WebSocket server
  static Future<bool> connect(
    String apiUrl,
    StatusUpdatedCallback onStatusUpdated, {
    Function? onNewClaim,
    Function? onClaimsChanged,
  }) async {
    try {
      // Convert HTTP URL to WS URL
      String wsUrl = apiUrl.replaceFirst('http://', 'ws://').replaceFirst('https://', 'wss://');
      
      // Create WebSocket connection
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _onStatusUpdated = onStatusUpdated;
      _onNewClaim = onNewClaim;
      _onClaimsChanged = onClaimsChanged;

      // Send admin connection event
      _channel!.sink.add(jsonEncode({
        'event': 'admin:connect',
        'data': {
          'type': 'admin_dashboard',
          'timestamp': DateTime.now().toIso8601String()
        }
      }));

      // Listen for messages
      _channel!.stream.listen(
        (message) {
          _handleMessage(message);
        },
        onError: (error) {
          _reconnect(apiUrl, onStatusUpdated, onNewClaim, onClaimsChanged);
        },
        onDone: () {
          _reconnect(apiUrl, onStatusUpdated, onNewClaim, onClaimsChanged);
        },
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Handle incoming WebSocket messages
  static void _handleMessage(dynamic message) {
    try {
      // Socket.IO format: "event_name,data_json"
      // But web_socket_channel gets the actual JSON
      final data = jsonDecode(message);
      
      // Handle both direct JSON and Socket.IO format
      final eventName = data['event'] ?? data['type'] ?? '';
      final eventData = data['data'] ?? data;

      switch (eventName) {
        case 'claim:statusUpdated':
          _onStatusUpdated?.call(data);
          break;

        case 'claim:created':
          _onNewClaim?.call(data['claim']);
          break;

        case 'claims:changed':
          _onClaimsChanged?.call(data['claims']);
          break;

        case 'admin:connected':
          break;

        default:
          }
    } catch (e) {
      }
  }

  /// Reconnect with exponential backoff
  static Future<void> _reconnect(
    String apiUrl,
    StatusUpdatedCallback onStatusUpdated,
    Function? onNewClaim,
    Function? onClaimsChanged,
  ) async {
    await Future.delayed(Duration(seconds: 3));
    
    final success = await connect(apiUrl, onStatusUpdated, onNewClaim: onNewClaim, onClaimsChanged: onClaimsChanged);
    if (!success) {
      _reconnect(apiUrl, onStatusUpdated, onNewClaim, onClaimsChanged);
    }
  }

  /// Disconnect from WebSocket
  static Future<void> disconnect() async {
    if (_channel != null) {
      await _channel!.sink.close(status.goingAway);
      _channel = null;
      }
  }

  /// Check if connected
  static bool isConnected() {
    return _channel != null;
  }
}
