import 'package:flutter/material.dart';
import 'package:starsyncapp/Screens/AstrologerProfile.dart';

import 'AnswerQuestions.dart';
import 'EarningPage.dart';
import 'PickQuestion.dart';

class AstrologersHome extends StatefulWidget {
  @override
  _AstrologersHomeState createState() => _AstrologersHomeState();
}

class _AstrologersHomeState extends State<AstrologersHome>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;

  // Controller and animation for header size
  late AnimationController _controller;
  late Animation<double> _headerHeightAnimation;

  // Footer slide animation
  late Animation<Offset> _footerSlideAnimation;

  // Pages for navigation
  static List<Widget> _pages = <Widget>[
    PickQuestionPage(),
    AnswerQuestionsPage(),
    EarningsPage(),
    AstrologerProfile(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    // Initialize animation controller
    _controller = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    );

    // Header will expand and then shrink back to its normal size
    _headerHeightAnimation = Tween<double>(begin: 250, end: 140).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    // Footer will slide in from the bottom
    _footerSlideAnimation = Tween<Offset>(begin: Offset(0, 1), end: Offset(0, 0))
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    // Start the animation
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: false,
      // appBar: PreferredSize(
      //   preferredSize: Size.fromHeight(250), // Start with expanded height
      //   child: AnimatedBuilder(
      //     animation: _headerHeightAnimation,
      //     builder: (context, child) {
      //       return Container(
      //         height: _headerHeightAnimation.value,
      //         child: AppBar(
      //           backgroundColor: Colors.transparent,
      //           elevation: 0,
      //           flexibleSpace: ClipPath(
      //             clipper: HeaderClipper(),
      //             child: Container(
      //               decoration: BoxDecoration(
      //                 gradient: LinearGradient(
      //                   colors: [Colors.amber.shade800, Colors.amber.shade400],
      //                   begin: Alignment.topLeft,
      //                   end: Alignment.bottomRight,
      //                 ),
      //                 boxShadow: [
      //                   BoxShadow(
      //                     color: Colors.black26,
      //                     offset: Offset(0, 4),
      //                     blurRadius: 10,
      //                   ),
      //                 ],
      //               ),
      //               child: Column(
      //                 mainAxisAlignment: MainAxisAlignment.center,
      //                 children: [
      //                   Column(
      //                     mainAxisAlignment: MainAxisAlignment.start,
      //                     children: [
      //                       CircleAvatar(
      //                         backgroundImage:
      //                         AssetImage('assets/logo.png'), // Replace with astrologer image or logo
      //                         radius: _headerHeightAnimation.value / 8,
      //                       ),
      //                       SizedBox(width: 10),
      //                       _headerHeightAnimation.value > 180
      //                           ? Text(
      //                         "Astrologer's Dashboard",
      //                         style: TextStyle(
      //                           fontSize: 24,
      //                           fontWeight: FontWeight.bold,
      //                           color: Colors.white,
      //                         ),
      //                       )
      //                           : Container(),
      //                     ],
      //                   ),
      //                 ],
      //               ),
      //             ),
      //           ),
      //         ),
      //       );
      //     },
      //   ),
      // ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/background.png'), // Add your background image here
            fit: BoxFit.cover,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 0.0), // Adjust to match header size
          child: _pages[_selectedIndex],
        ),
      ),
      bottomNavigationBar: SlideTransition(
        position: _footerSlideAnimation,
        child: ClipPath(
          clipper: FooterClipper(),
          child: BottomNavigationBar(
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: Icon(Icons.question_answer),
                label: 'Pick Question',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.question_mark),
                label: 'Answer',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.attach_money),
                label: 'Earnings',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
            currentIndex: _selectedIndex,
            selectedItemColor: Colors.amber[800],
            unselectedItemColor: Colors.grey,
            onTap: _onItemTapped,
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            elevation: 5,
          ),
        ),
      ),
    );
  }
}

// Custom clipper for creating rounded header
class HeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 80);
    path.quadraticBezierTo(size.width / 2, size.height, size.width, size.height - 80);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) {
    return false;
  }
}

// Custom clipper for creating rounded footer
class FooterClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.moveTo(0, 20);
    path.quadraticBezierTo(size.width / 2, -40, size.width, 20);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) {
    return false;
  }
}
