import 'package:flutter/material.dart';

class Navbar extends StatelessWidget {
  final String userRole;
  final int currentIndex;

  const Navbar({Key? key, required this.userRole, this.currentIndex = 1})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 70,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
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
                      if (userRole == 'admin') {
                        Navigator.pushNamed(context, '/adminDashboard');
                      } else {
                        Navigator.pushNamed(context, '/userDashboard');
                      }
                    },
                    icon: Icon(
                      Icons.home,
                      size: 32,
                      color: currentIndex == 1 ? Colors.white70 : Colors.white,
                    ),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Home',
                  style: TextStyle(
                    color: currentIndex == 1 ? Colors.white70 : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Navigation buttons kiri dan kanan
          Positioned.fill(
            top: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 50),
              child: userRole == 'admin'
                  ? _buildAdminButtons(context)
                  : _buildUserButtons(context),
            ),
          ),
        ],
      ),
    );
  }

  // Buttons untuk Admin
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
                color: currentIndex == 0 ? Colors.white70 : Colors.white,
              ),
            ),
            Text(
              'Lab',
              style: TextStyle(
                color: currentIndex == 0 ? Colors.white70 : Colors.white,
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
                // Navigate ke Admin Profile
                Navigator.pushNamed(context, '/profileAdmin');
              },
              icon: Icon(
                Icons.person,
                size: 28,
                color: currentIndex == 2 ? Colors.white70 : Colors.white,
              ),
            ),
            Text(
              'Profile',
              style: TextStyle(
                color: currentIndex == 2 ? Colors.white70 : Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Buttons untuk User
  Widget _buildUserButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: () {
                Navigator.pushNamed(context, '/booking');
              },
              icon: Icon(
                Icons.calendar_month,
                size: 28,
                color: currentIndex == 0 ? Colors.white70 : Colors.white,
              ),
            ),
            Text(
              'Booking',
              style: TextStyle(
                color: currentIndex == 0 ? Colors.white70 : Colors.white,
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
                // Navigate ke User Profile
                Navigator.pushNamed(context, '/profileUser');
              },
              icon: Icon(
                Icons.person,
                size: 28,
                color: currentIndex == 2 ? Colors.white70 : Colors.white,
              ),
            ),
            Text(
              'Profile',
              style: TextStyle(
                color: currentIndex == 2 ? Colors.white70 : Colors.white,
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