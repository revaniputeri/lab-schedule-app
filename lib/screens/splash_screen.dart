import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lottie/lottie.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _fade;

  // URL Lottie loader dari LottieFiles
  final String lottieLoaderUrl =
      'https://lottie.host/e65720c4-edec-43c2-9e44-7f053f7b25ab/rYfnhmSqTh.json';

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeIn);
    _anim.forward();

    _startSplash();
  }

  Future<void> _startSplash() async {
    debugPrint('Splash: started');
    await Future.delayed(const Duration(milliseconds: 2500));
    debugPrint('Splash: delay finished, checking auth');

    if (!mounted) return;
    final user = FirebaseAuth.instance.currentUser;
    debugPrint('Splash: currentUser = ${user?.uid ?? "null"}');

    if (user == null) {
      debugPrint('Splash: navigate -> /login');
      Navigator.of(context).pushReplacementNamed('/login');
    } else {
      final isAdmin = (user.email?.toLowerCase().contains('admin') ?? false);
      debugPrint('Splash: navigate -> ${isAdmin ? "/adminDashboard" : "/userDashboard"}');
      Navigator.of(context).pushReplacementNamed(isAdmin ? '/adminDashboard' : '/userDashboard');
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(
        opacity: _fade,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF4A90E2),    // deep blue (like appbar)
                Color(0xFF5B9FEE),    // medium blue
                Color(0xFF6BADFF),    // light blue (like background)
              ],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo / Icon dengan shadow
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.science,
                    size: 80,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 30),
                // Title
                const Text(
                  'Jadwal Laboratorium',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                // Subtitle
                Text(
                  'Sistem Manajemen Booking Lab',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.85),
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 40),
                // Loading indicator dari Lottie
                SizedBox(
                  width: 150,
                  height: 150,
                  child: Lottie.network(
                    lottieLoaderUrl,
                    fit: BoxFit.contain,
                    repeat: true,
                    reverse: false,
                    frameRate: FrameRate.max,
                    errorBuilder: (context, error, stackTrace) {
                      debugPrint('Lottie load error: $error');
                      // Fallback ke CircularProgressIndicator jika Lottie gagal
                      return const SizedBox(
                        width: 100,
                        height: 100,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          strokeWidth: 4,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}