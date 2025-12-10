import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lottie/lottie.dart';

class SplashScreen extends StatefulWidget {
  final int duration;
  final double logoSize;

  const SplashScreen({
    super.key,
    this.duration = 4500,
    this.logoSize = 200,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _fade;

  final String lottieLoaderUrl =
      'https://lottie.host/e65720c4-edec-43c2-9e44-7f053f7b25ab/rYfnhmSqTh.json';

  @override
  void initState() {
    super.initState();

    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeInOut);

    _anim.forward();

    _startSplash();
  }

  Future<void> _startSplash() async {
    debugPrint('Splash: started');

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
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF6B9EFF), // Biru soft terang
                Color(0xFF5B8FFF), // Biru medium
                Color(0xFF4B7FFF), // Biru cerah
                Color(0xFF3B70EE), // Biru medium-dark
              ],
            ),
          ),
          child: Stack(
            children: [
              // Decorative circles background
              Positioned(
                top: -100,
                right: -100,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05),
                  ),
                ),
              ),
              Positioned(
                top: 150,
                left: -150,
                child: Container(
                  width: 350,
                  height: 350,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05),
                  ),
                ),
              ),
              Positioned(
                bottom: -80,
                left: 50,
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05),
                  ),
                ),
              ),
              Positioned(
                bottom: 100,
                right: -50,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05),
                  ),
                ),
              ),
              
              // Main content
              SafeArea(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo dengan efek glow
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                    
                          
                        ),
                        child: Image.asset(
                          'lib/assets/images/logo_siboji.png',
                          width: widget.logoSize,
                          height: widget.logoSize,
                          fit: BoxFit.contain,
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Loading indicator
                      SizedBox(
                        width: 100,
                        height: 100,
                        child: Lottie.network(
                          lottieLoaderUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return SizedBox(
                              width: 40,
                              height: 40,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation(
                                  Colors.white.withOpacity(0.9),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}