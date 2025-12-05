import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lottie/lottie.dart';

class SplashScreen extends StatefulWidget {
  final int duration;      // durasi dalam milidetik
  final double logoSize;   // ukuran logo SIBOJI

  const SplashScreen({
    super.key,
    this.duration = 4500,   
    this.logoSize = 250,  
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _fade;

  // URL Lottie loader
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

    // durasi splash berasal dari parameter
    await Future.delayed(Duration(milliseconds: widget.duration));

    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    final isAdmin = (user?.email?.toLowerCase().contains('admin') ?? false);

    if (user == null) {
      Navigator.of(context).pushReplacementNamed('/login');
    } else {
      Navigator.of(context).pushReplacementNamed(
          isAdmin ? '/adminDashboard' : '/userDashboard');
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
                Color(0xFF4A90E2),
                Color(0xFF5B9FEE),
                Color(0xFF6BADFF),
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // LOGO SIBOJI — ukuran bisa diatur
                Container(
                  padding: const EdgeInsets.all(25),
                  child: Image.asset(
                    'lib/assets/images/logo_siboji.png',
                    width: widget.logoSize,
                    height: widget.logoSize,
                  ),
                ),

                // const SizedBox(height: 10),

         
                // const SizedBox(height: 8),

                // // Text(
                // //   'Sistem Manajemen Booking Lab',
                // //   style: TextStyle(
                // //     fontSize: 14,
                // //     color: Colors.white.withOpacity(0.85),
                // //   ),
                // // ),

                // const SizedBox(height: 35),

                SizedBox(
                  width: 150,
                  height: 150,
                  child: Lottie.network(
                    lottieLoaderUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) {
                      return const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(Colors.white),
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
