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
      
      print('🔗 [WEBSOCKET] Connecting to: $wsUrl');
      
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

      print('✅ [WEBSOCKET] Connected successfully');

      // Listen for messages
      _channel!.stream.listen(
        (message) {
          _handleMessage(message);
        },
        onError: (error) {
          print('❌ [WEBSOCKET] Error: $error');
          _reconnect(apiUrl, onStatusUpdated, onNewClaim, onClaimsChanged);
        },
        onDone: () {
          print('⚠️ [WEBSOCKET] Connection closed');
          _reconnect(apiUrl, onStatusUpdated, onNewClaim, onClaimsChanged);
        },
      );

      return true;
    } catch (e) {
      print('❌ [WEBSOCKET] Connection failed: $e');
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

      print('📬 [WEBSOCKET] Received: $eventName');

      switch (eventName) {
        case 'claim:statusUpdated':
          print('🔄 [REALTIME] Status update received:');
          print('   Claim: ${data['claimId']}');
          print('   Status: ${data['oldStatus']} → ${data['newStatus']}');
          _onStatusUpdated?.call(data);
          break;

        case 'claim:created':
          print('✨ [REALTIME] New claim received: ${data['claim']['id']}');
          _onNewClaim?.call(data['claim']);
          break;

        case 'claims:changed':
          print('📊 [REALTIME] Claims changed event received');
          _onClaimsChanged?.call(data['claims']);
          break;

        case 'admin:connected':
          print('✅ [WEBSOCKET] Admin connection confirmed');
          break;

        default:
          print('❓ [WEBSOCKET] Unknown event: $eventName');
      }
    } catch (e) {
      print('❌ [WEBSOCKET] Failed to parse message: $e');
    }
  }

  /// Reconnect with exponential backoff
  static Future<void> _reconnect(
    String apiUrl,
    StatusUpdatedCallback onStatusUpdated,
    Function? onNewClaim,
    Function? onClaimsChanged,
  ) async {
    print('⏳ [WEBSOCKET] Attempting to reconnect in 3 seconds...');
    await Future.delayed(Duration(seconds: 3));
    
    final success = await connect(apiUrl, onStatusUpdated, onNewClaim: onNewClaim, onClaimsChanged: onClaimsChanged);
    if (!success) {
      print('⚠️ [WEBSOCKET] Reconnection failed, will retry...');
      _reconnect(apiUrl, onStatusUpdated, onNewClaim, onClaimsChanged);
    }
  }

  /// Disconnect from WebSocket
  static Future<void> disconnect() async {
    if (_channel != null) {
      await _channel!.sink.close(status.goingAway);
      _channel = null;
      print('🔌 [WEBSOCKET] Disconnected');
    }
  }

  /// Check if connected
  static bool isConnected() {
    return _channel != null;
  }
}
