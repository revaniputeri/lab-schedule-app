import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Handler untuk background messages (HARUS di top-level)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Handling background message: ${message.messageId}');
  print('Message data: ${message.data}');
  print('Message notification: ${message.notification?.title}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Channel ID untuk Android
  static const String _channelId = 'booking_channel';
  static const String _channelName = 'Booking Notifications';
  static const String _channelDescription = 'Notifikasi untuk booking lab';

  // Inisialisasi FCM dan Local Notifications
  Future<void> initialize() async {
    // Request permission untuk iOS
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      criticalAlert: false,
      announcement: false,
    );

    print('User granted permission: ${settings.authorizationStatus}');

    // Setup Android notification channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Setup local notifications
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Set foreground notification presentation options untuk iOS
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle notification opened app
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Check for initial message if app was opened from notification
    RemoteMessage? initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageOpenedApp(initialMessage);
    }

    // Get FCM token
    String? token = await _messaging.getToken();
    print('FCM Token: $token');

    // Listen untuk token refresh
    _messaging.onTokenRefresh.listen((newToken) {
      print('FCM Token refreshed: $newToken');
      // TODO: Update token di Firestore jika user sudah login
    });
  }

  // Save FCM token ke Firestore
  Future<void> saveFCMToken(String userId) async {
    try {
      String? token = await _messaging.getToken();
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({
          'fcmToken': token,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        });
        print('FCM Token saved for user: $userId');
      }
    } catch (e) {
      print('Error saving FCM token: $e');
    }
  }

  // Handle foreground messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('Got a message in foreground!');
    print('Message data: ${message.data}');
    print('Message notification: ${message.notification?.title}');

    // Tampilkan notifikasi lokal ketika app di foreground
    if (message.notification != null) {
      await _showLocalNotification(
        title: message.notification!.title ?? 'Booking Notification',
        body: message.notification!.body ?? '',
        payload: message.data.toString(),
      );
    }
  }

  // Handle ketika notifikasi di-tap
  void _onNotificationTapped(NotificationResponse response) {
    print('Notification tapped: ${response.payload}');
    // TODO: Navigate ke halaman detail booking
    // Gunakan GlobalKey<NavigatorState> atau GetX untuk navigation
  }

  // Handle ketika notifikasi membuka app dari background/terminated
  void _handleMessageOpenedApp(RemoteMessage message) {
    print('Message clicked: ${message.messageId}');
    print('Message data: ${message.data}');
    // TODO: Navigate ke halaman detail booking berdasarkan message.data
  }

  // Show local notification
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      enableLights: true,
      color: Color(0xFF4A90E2),
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  // ==================== METHODS UNTUK BOOKING SERVICE ====================
  
  /// Get all admin FCM tokens
  Future<List<String>> getAdminTokens() async {
    List<String> tokens = [];
    
    try {
      QuerySnapshot adminSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();

      for (var doc in adminSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          String? token = data['fcmToken'] as String?;
          if (token != null && token.isNotEmpty) {
            tokens.add(token);
          }
        }
      }
      
      print('Found ${tokens.length} admin tokens');
    } catch (e) {
      print('Error getting admin tokens: $e');
    }

    return tokens;
  }

  /// Send booking notification via Cloud Function trigger
  /// Ini akan membuat document di collection 'notifications' yang akan
  /// di-trigger oleh Cloud Function untuk mengirim push notification
  Future<void> sendBookingNotification({
    required String bookingId,
    required String userName,
    required String labName,
    required String time,
    required String date,
    required List<String> adminTokens,
  }) async {
    try {
      // Jika tidak ada admin token, skip
      if (adminTokens.isEmpty) {
        print('No admin tokens to send notification');
        return;
      }

      // Simpan notifikasi untuk SETIAP admin token
      // Cloud Function akan membaca dan mengirim ke masing-masing token
      for (String token in adminTokens) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'type': 'new_booking',
          'bookingId': bookingId,
          'userName': userName,
          'labName': labName,
          'time': time,
          'date': date,
          'userToken': token, // Token admin yang akan menerima notifikasi
          'title': '🔔 Booking Baru!',
          'body': '$userName mengajukan booking $labName untuk $date pukul $time',
          'createdAt': FieldValue.serverTimestamp(),
          'sent': false,
        });
      }
      
      print('Queued ${adminTokens.length} notifications for new booking');
    } catch (e) {
      print('Error sending booking notification: $e');
      rethrow; // Propagate error ke caller
    }
  }

  /// Send notification untuk status change (approved/rejected)
  /// Method ini sudah tidak diperlukan karena sudah ada di booking_service.dart
  /// Tapi saya tetap sediakan untuk kompatibilitas
  Future<void> sendStatusChangeNotification({
    required String bookingId,
    required String userId,
    required String userToken,
    required String labName,
    required String time,
    required String date,
    required String status,
    String? reason,
  }) async {
    try {
      if (userToken.isEmpty) {
        print('No user token to send notification');
        return;
      }

      String title;
      String body;
      
      if (status.toLowerCase() == 'approved') {
        title = '✅ Booking Disetujui!';
        body = 'Booking Anda untuk $labName pada $date ($time) telah disetujui';
      } else {
        title = '❌ Booking Ditolak';
        final reasonText = reason != null && reason.isNotEmpty 
            ? ' Alasan: $reason' 
            : '';
        body = 'Booking Anda untuk $labName pada $date ($time) ditolak.$reasonText';
      }

      await FirebaseFirestore.instance.collection('notifications').add({
        'type': 'booking_status_update',
        'bookingId': bookingId,
        'userId': userId,
        'userToken': userToken,
        'labName': labName,
        'time': time,
        'date': date,
        'status': status,
        'title': title,
        'body': body,
        'reason': reason,
        'createdAt': FieldValue.serverTimestamp(),
        'sent': true,
      });
      
      print('Queued status change notification');
    } catch (e) {
      print('Error sending status change notification: $e');
      rethrow;
    }
  }

  // Delete FCM token (untuk logout)
  Future<void> deleteFCMToken(String userId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'fcmToken': FieldValue.delete(),
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
      await _messaging.deleteToken();
      print('FCM Token deleted for user: $userId');
    } catch (e) {
      print('Error deleting FCM token: $e');
    }
  }
}