import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';

class NotificationMessage {
  final String id;
  final String type; // 'task_assigned', 'task_updated', 'task_completed'
  final String title;
  final String message;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  NotificationMessage({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.data,
    required this.timestamp,
  });

  factory NotificationMessage.fromJson(Map<String, dynamic> json) {
    return NotificationMessage(
      id: json['id']?.toString() ?? 'unknown',
      type: json['type']?.toString() ?? 'general',
      title: json['title']?.toString() ?? 'Notification',
      message: json['message']?.toString() ?? '',
      data: json['data'] ?? {},
      timestamp: DateTime.now(),
    );
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  WebSocketChannel? _channel;
  final StreamController<NotificationMessage> _notificationStream =
      StreamController<NotificationMessage>.broadcast();
  final StreamController<int> _pendingTaskCountStream =
      StreamController<int>.broadcast();

  bool _isConnected = false;
  Timer? _reconnectTimer;
  static const int _reconnectDelay = 3;

  /// Get the notification stream
  Stream<NotificationMessage> get notifications => _notificationStream.stream;

  /// Get the pending task count stream
  Stream<int> get pendingTaskCount => _pendingTaskCountStream.stream;

  /// Check if connected
  bool get isConnected => _isConnected;

  /// Connect to WebSocket for real-time notifications
  Future<void> connect() async {
    if (_isConnected) {
      return;
    }

    try {
      // Skip WebSocket entirely if not available
      print('📊 Using polling mode for task updates');
      _isConnected = false;
      return;
    } catch (e) {
      _isConnected = false;
    }
  }

  void _startReconnectTimer() {
    // Do nothing - no reconnection needed
  }

  void _handleMessage(dynamic message) {
    // No-op
  }

  void _handleDisconnection() {
    // No-op
  }

  /// Send a test notification (for debugging)
  void sendTestNotification(String taskTitle, String clientName) {
    final notification = NotificationMessage(
      id: 'test_${DateTime.now().millisecondsSinceEpoch}',
      type: 'task_assigned',
      title: 'New Task Assigned',
      message: '$taskTitle assigned to $clientName',
      data: {
        'taskTitle': taskTitle,
        'clientName': clientName,
        'assignedTime': DateTime.now().toString(),
      },
      timestamp: DateTime.now(),
    );

    print('🧪 Test notification: ${notification.title}');
    _notificationStream.add(notification);
  }

  /// Send a task re-open notification
  void sendReopenNotification(String claimId, String taskTitle) {
    final notification = NotificationMessage(
      id: 'reopen_${DateTime.now().millisecondsSinceEpoch}',
      type: 'task_reopened',
      title: '🔓 Task Reopened',
      message: '$taskTitle (#$claimId) has been re-opened by admin. You can now continue working on it.',
      data: {
        'claimId': claimId,
        'taskTitle': taskTitle,
        'reopenTime': DateTime.now().toString(),
      },
      timestamp: DateTime.now(),
    );

    print('🔓 Re-open notification: ${notification.title}');
    _notificationStream.add(notification);
  }

  /// Emit a notification from Socket.IO or other real-time source
  void emitNotification(NotificationMessage notification) {
    print('📢 Emitting notification: ${notification.title}');
    _notificationStream.add(notification);
  }

  /// Close connection
  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _isConnected = false;
    print('🛑 Notification service disconnected');
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _notificationStream.close();
    await _pendingTaskCountStream.close();
    await disconnect();
  }
}
