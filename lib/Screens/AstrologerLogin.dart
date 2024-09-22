import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';  // Import SharedPreferences
import 'AstrologersHome.dart';

class AstrologerLoginPage extends StatefulWidget {
  @override
  _AstrologerLoginPageState createState() => _AstrologerLoginPageState();
}

class _AstrologerLoginPageState extends State<AstrologerLoginPage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool isLoading = false;

  // Firestore reference
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Login logic for astrologer
  Future<void> _loginAstrologer() async {
    setState(() {
      isLoading = true;
    });

    String phone = _phoneController.text.trim();
    String password = _passwordController.text.trim();

    try {
      if (phone.isNotEmpty && password.isNotEmpty) {
        // Check if astrologer exists in Firestore collection 'astrologers'
        DocumentSnapshot astrologerDoc = await _firestore.collection('astrologers').doc(phone).get();

        if (astrologerDoc.exists) {
          // Astrologer exists, now validate the password
          String storedPassword = (astrologerDoc.data() as Map<String, dynamic>)['password'];

          if (storedPassword == password) {
            // Password matches, save astrologer phone in SharedPreferences and navigate to AstrologersHome
            SharedPreferences prefs = await SharedPreferences.getInstance();
            await prefs.setString('astrologer_phone', phone);  // Save astrologer's phone in SharedPreferences

            setState(() {
              isLoading = false;
            });

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => AstrologersHome()),
            );
          } else {
            // Password is incorrect
            setState(() {
              isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Incorrect password. Please try again."),
                backgroundColor: Colors.red,
              ),
            );
          }
        } else {
          // Astrologer doesn't exist, show snack bar
          setState(() {
            isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Astrologer doesn't exist. Please check your credentials."),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Please fill in both fields."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print("Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("An error occurred. Please try again."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/background.png'), // Replace with your background image
                fit: BoxFit.cover,
              ),
            ),
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // App Logo
                      Image.asset(
                        'assets/logo.png', // Add your logo image here
                        height: 150,
                        width: 150,
                      ),
                      SizedBox(height: 30),

                      // Page Title
                      Text(
                        "Astrologer Login",
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 28,
                        ),
                      ),
                      SizedBox(height: 30),

                      // Phone Number Field
                      _buildTextField(
                        controller: _phoneController,
                        hint: "Enter your phone number",
                        icon: Icons.phone,
                        keyboardType: TextInputType.phone,
                      ),
                      SizedBox(height: 20),

                      // Password Field
                      _buildTextField(
                        controller: _passwordController,
                        hint: "Enter your password",
                        icon: Icons.lock,
                        isPassword: true,
                      ),
                      SizedBox(height: 30),

                      // Submit Button
                      ElevatedButton(
                        onPressed: isLoading ? null : _loginAstrologer,
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.amber[800], // Button background color
                          padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 5,
                        ),
                        child: isLoading
                            ? CircularProgressIndicator(
                          color: Colors.white,
                        )
                            : Text(
                          "Login",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      SizedBox(height: 20),

                      // Forgot Password Link (Optional)
                      TextButton(
                        onPressed: () {
                          // Add logic for "Forgot Password"
                          print("Forgot password tapped");
                        },
                        child: Text(
                          "Forgot Password?",
                          style: TextStyle(
                            color: Colors.black54,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Custom method to build text fields with rounded corners and shadows
  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: TextField(
        textAlignVertical: TextAlignVertical.center,
        controller: controller,
        obscureText: isPassword,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.black54),
          prefixIcon: Icon(icon, color: Colors.amber[800]),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

// Placeholder for the AstrologersHome page (Navigate to this page after a successful login)
class AstrologersHome extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Astrologer's Dashboard"),
        backgroundColor: Colors.amber[800],
      ),
      body: Center(
        child: Text(
          "Welcome to Astrologer's Home Page",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
