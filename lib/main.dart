import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard/userDashboard.dart';
import 'screens/dashboard/adminDashboard.dart';
import 'screens/booking_page.dart';
import 'screens/profilePage/profileUser.dart';
import 'screens/profilePage/profileAdmin.dart';
import 'screens/profilePage/changePass.dart';
import 'screens/profilePage/editProfile.dart';
import 'screens/profilePage/helpPage.dart';
import 'screens/splash_screen.dart';
import 'firebase_options.dart';
import 'services/notificaton_service.dart';

// ============================================================
// BACKGROUND MESSAGE HANDLER
// Harus di top-level (di luar class), dipanggil saat app tertutup
// ============================================================
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase jika belum
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  print('📩 Background Message Received!');
  print('Message ID: ${message.messageId}');
  print('Title: ${message.notification?.title}');
  print('Body: ${message.notification?.body}');
  print('Data: ${message.data}');
  
  // Background notification akan otomatis muncul di Android
  // Untuk iOS, perlu handle manual jika perlu
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // Register background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  // Initialize date formatting
  try {
    await initializeDateFormatting('id_ID');
  } catch (e) {
    debugPrint('Locale init failed: $e');
  }
  
  // Initialize Notification Service
  try {
    await NotificationService().initialize();
    debugPrint('✅ Notification Service initialized');
  } catch (e) {
    debugPrint('❌ Notification Service initialization failed: $e');
  }
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final NotificationService _notificationService = NotificationService();
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupNotifications();
    _setupAuthStateListener();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Setup notification handlers
  void _setupNotifications() {
    // Handle notification tap when app is in foreground/background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('📱 Notification tapped! (App in background)');
      _handleNotificationTap(message);
    });

    // Check if app was opened from a terminated state notification
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint('📱 App opened from notification! (Terminated state)');
        _handleNotificationTap(message);
      }
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📬 Foreground message received!');
      debugPrint('Title: ${message.notification?.title}');
      debugPrint('Body: ${message.notification?.body}');
      
      // Show in-app notification or dialog
      if (message.notification != null) {
        _showInAppNotification(
          message.notification!.title ?? 'Notification',
          message.notification!.body ?? '',
        );
      }
    });

    // Request notification permission (untuk iOS)
    _requestNotificationPermission();
  }

  /// Request notification permission
  Future<void> _requestNotificationPermission() async {
    final messaging = FirebaseMessaging.instance;
    
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('✅ User granted notification permission');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      debugPrint('⚠️ User granted provisional notification permission');
    } else {
      debugPrint('❌ User declined notification permission');
    }
  }

  /// Handle notification tap - navigate to appropriate screen
  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] as String?;

    debugPrint('Handling notification tap: $type');

    // Delay navigation untuk memastikan app sudah ready
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;

      if (type == 'new_booking') {
        // Navigate to admin dashboard (booking list)
        navigatorKey.currentState?.pushNamed('/adminDashboard');
      } else if (type == 'booking_status_update') {
        // Navigate to user dashboard (my bookings)
        navigatorKey.currentState?.pushNamed('/userDashboard');
      }
    });
  }

  /// Show in-app notification banner
  void _showInAppNotification(String title, String body) {
    final context = navigatorKey.currentContext;
    if (context == null || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              body,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blueAccent,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        action: SnackBarAction(
          label: 'Lihat',
          textColor: Colors.white,
          onPressed: () {
            // Handle view action
            navigatorKey.currentState?.pushNamed('/userDashboard');
          },
        ),
      ),
    );
  }

  /// Setup auth state listener untuk auto save FCM token
  void _setupAuthStateListener() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        debugPrint('🔐 User logged in: ${user.uid}');
        
        // Save FCM token to Firestore
        _notificationService.saveFCMToken(user.uid).then((_) {
          debugPrint('✅ FCM token saved for user: ${user.uid}');
        }).catchError((error) {
          debugPrint('❌ Error saving FCM token: $error');
        });

        // Get and print token for debugging
        FirebaseMessaging.instance.getToken().then((token) {
          debugPrint('📱 FCM Token: $token');
        });
      } else {
        debugPrint('🔓 User logged out');
      }
    });
  }

  /// Handle app lifecycle changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.resumed:
        debugPrint('📱 App resumed');
        // Refresh FCM token jika perlu
        _refreshFCMToken();
        break;
      case AppLifecycleState.paused:
        debugPrint('📱 App paused');
        break;
      case AppLifecycleState.inactive:
        debugPrint('📱 App inactive');
        break;
      case AppLifecycleState.detached:
        debugPrint('📱 App detached');
        break;
      case AppLifecycleState.hidden:
        debugPrint('📱 App hidden');
        break;
    }
  }

  /// Refresh FCM token
  Future<void> _refreshFCMToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await _notificationService.saveFCMToken(user.uid);
        debugPrint('🔄 FCM token refreshed');
      } catch (e) {
        debugPrint('❌ Error refreshing FCM token: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Jadwal Laboratorium',
      navigatorKey: navigatorKey, // ← PENTING: untuk handle notification navigation
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blueAccent,
        fontFamily: 'Poppins',
        
        // Snackbar theme untuk notifikasi
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: const SplashScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/adminDashboard': (context) => const AdminDashboard(),
        '/userDashboard': (context) => const UserDashboard(),
        '/booking': (context) => const RoomBookingPage(),
        '/profileUser': (context) => const ProfilePage(),
        '/profileAdmin': (context) => const AdminProfilePage(),
        '/changePassword': (context) => const ChangePasswordPage(),
        '/editProfile': (context) => const EditProfilePage(),
        '/help': (context) => const HelpPage(),
      },
    );
  }
}
