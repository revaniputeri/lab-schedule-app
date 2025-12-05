import 'package:flutter/material.dart';

class Navbar extends StatelessWidget {
  final String userRole;
  final int currentIndex;

  const Navbar({Key? key, required this.userRole, this.currentIndex = 1})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Untuk user, home di kiri. Untuk admin, home di tengah
    bool isAdmin = userRole == 'admin';
    
    return SizedBox(
      height: 70,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // Background navbar dengan clipper untuk admin dan user
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipPath(
              clipper: NavBarClipper(),
              child: Container(
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.blue.shade400,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 6,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Circle button di tengah
          Positioned(
            top: -25,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 70,
                  width: 70,
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: () {
                      // Navigate ke dashboard sesuai role
                      if (isAdmin) {
                        Navigator.pushNamed(context, '/adminDashboard');
                      } else {
                        Navigator.pushNamed(context, '/booking');
                      }
                    },
                    icon: Icon(
                      isAdmin ? Icons.home : Icons.calendar_month,
                      size: 32,
                      color: (isAdmin && currentIndex == 0) || (!isAdmin && currentIndex == 1)
                          ? Colors.white
                          : Colors.white70,
                    ),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  isAdmin ? 'Home' : 'Booking',
                  style: TextStyle(
                    color: (isAdmin && currentIndex == 0) || (!isAdmin && currentIndex == 1)
                        ? Colors.white
                        : Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Navigation buttons
          Positioned.fill(
            top: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 50),
              child: isAdmin
                  ? _buildAdminButtons(context)
                  : _buildUserButtons(context),
            ),
          ),
        ],
      ),
    );
  }

  // Buttons untuk Admin (Lab - Home - Profile)
  Widget _buildAdminButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: () {
                Navigator.pushNamed(context, '/lab');
              },
              icon: Icon(
                Icons.monitor,
                size: 28,
                color: currentIndex == 1 ? Colors.white : Colors.white70,
              ),
            ),
            Text(
              'Lab',
              style: TextStyle(
                color: currentIndex == 1 ? Colors.white : Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),

        const SizedBox(width: 80),

        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: () {
                Navigator.pushNamed(context, '/profileAdmin');
              },
              icon: Icon(
                Icons.person,
                size: 28,
                color: currentIndex == 2 ? Colors.white : Colors.white70,
              ),
            ),
            Text(
              'Profile',
              style: TextStyle(
                color: currentIndex == 2 ? Colors.white : Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Buttons untuk User (Home - Booking(elevated) - Profile)
  Widget _buildUserButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Home button di kiri untuk user
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: () {
                Navigator.pushNamed(context, '/userDashboard');
              },
              icon: Icon(
                Icons.home,
                size: 28,
                color: currentIndex == 0 ? Colors.white : Colors.white70,
              ),
            ),
            Text(
              'Home',
              style: TextStyle(
                color: currentIndex == 0 ? Colors.white : Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),

        const SizedBox(width: 80),

        // Profile button di kanan
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: () {
                Navigator.pushNamed(context, '/profileUser');
              },
              icon: Icon(
                Icons.person,
                size: 28,
                color: currentIndex == 2 ? Colors.white : Colors.white70,
              ),
            ),
            Text(
              'Profile',
              style: TextStyle(
                color: currentIndex == 2 ? Colors.white : Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class NavBarClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();

    path.moveTo(0, size.height);
    path.lineTo(0, 0);
    path.lineTo(size.width * 0.35, 0);
    path.quadraticBezierTo(size.width * 0.40, 0, size.width * 0.42, 20);
    path.quadraticBezierTo(size.width * 0.50, 70, size.width * 0.58, 20);
    path.quadraticBezierTo(size.width * 0.60, 0, size.width * 0.65, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}