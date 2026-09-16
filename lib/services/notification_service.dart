import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Privacy-first, zero-cloud instant notification service for M-Pesa transactions.
class NotificationService {
  static const String channelId = 'vault_alerts';
  static const String channelName = 'Vault Alerts';
  static const String channelDescription =
      'Instant M-Pesa transaction alerts and review reminders';

  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Initializes local notifications plugin, registers the Android channel,
  /// configures notification tap handling, and requests notification permissions on Android 13+.
  static Future<void> initNotifications({
    void Function(NotificationResponse response)? onNotificationTap,
  }) async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: onNotificationTap,
    );

    // Create high-importance Android notification channel
    final androidImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      const androidChannel = AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDescription,
        importance: Importance.max,
      );
      await androidImplementation.createNotificationChannel(androidChannel);
      await androidImplementation.requestNotificationsPermission();
    }
  }

  /// Triggers an immediate local notification card the exact moment an M-Pesa transaction arrives.
  static Future<void> showInstantTransactionNotification(
    String id,
    double amount,
    String description,
    bool isIncome,
  ) async {
    final title = isIncome
        ? '📥 Cashflow Inflow Received'
        : '💸 Expense Outlay Tracked';
    final body =
        'KSh ${amount.toStringAsFixed(2)} - $description. Tap to select category now.';

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
      ),
    );

    final notificationDetails =
        NotificationDetails(android: androidDetails);

    try {
      final notificationId = id.hashCode.abs() % 100000;
      await _notificationsPlugin.show(
        notificationId,
        title,
        body,
        notificationDetails,
        payload: id,
      );
      debugPrint('🔔 Instant transaction notification shown for ID: $id');
    } catch (e) {
      debugPrint('⚠️ Error showing instant notification: $e');
    }
  }
}
