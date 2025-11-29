import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard/userDashboard.dart';
import 'screens/dashboard/adminDashboard.dart';
import 'screens/booking_page.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Init locale data for Indonesian date formatting used in dashboard
  try {
    await initializeDateFormatting('id_ID');
  } catch (e) {
    debugPrint('Locale init failed: $e');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Jadwal Laboratorium',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blueAccent,
      ),
      routes: {
        '/': (context) => const LoginScreen(),
        '/adminDashboard': (context) => const AdminDashboard(),
        '/userDashboard': (context) => const UserDashboard(),
        '/booking': (context) => const RoomBookingPage(),
      },
    );
  }
}
