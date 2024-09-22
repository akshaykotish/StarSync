import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:starsyncapp/Screens/Profile.dart';

// Stateful widget for "Profile" page
class AstrologerProfile extends StatefulWidget {
  @override
  _AstrologerProfileState createState() => _AstrologerProfileState();
}

class _AstrologerProfileState extends State<AstrologerProfile> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? astrologerId;
  bool _passwordChanged = false;
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAstrologerId();
  }

  // Load astrologer ID from SharedPreferences
  Future<void> _loadAstrologerId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      astrologerId = prefs.getString('astrologer_phone');
    });
  }

  // Validate the current password and update with the new password
  Future<void> _changePassword() async {
    if (astrologerId == null) return;

    try {
      // Get the current astrologer document
      DocumentSnapshot astrologerDoc = await _firestore.collection('astrologers').doc(astrologerId).get();

      if (astrologerDoc.exists) {
        String storedPassword = astrologerDoc['password'];

        // Validate the current password
        if (_currentPasswordController.text != storedPassword) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Current password is incorrect.")),
          );
          return;
        }

        // Validate new password and confirm password match
        if (_newPasswordController.text != _confirmPasswordController.text) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("New password and confirm password do not match.")),
          );
          return;
        }

        // Update the password in Firestore
        await _firestore.collection('astrologers').doc(astrologerId).update({
          'password': _newPasswordController.text,
        });

        setState(() {
          _passwordChanged = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Password changed successfully.")),
        );

        // Clear the input fields
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error changing password: $e")),
      );
    }
  }

  // Logout functionality
  Future<void> _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();  // Clear shared preferences

    // Navigate back to the login screen (or any other screen you want)
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context)=>ProfilePage())); // Adjust the route name for your LoginPage
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Profile", style: Theme.of(context).textTheme.titleLarge),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Information Section (optional: Add profile details)
            Text(
              "Profile Information",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 20),

            // Password Change Section
            _buildPasswordChangeSection(),

            SizedBox(height: 20),

            ElevatedButton(
              onPressed: _changePassword,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 15, horizontal: 30),
                backgroundColor: Colors.amber[800],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: Text("Change Password", style: TextStyle(fontSize: 18)),
            ),

            if (_passwordChanged)
              Padding(
                padding: const EdgeInsets.only(top: 20.0),
                child: Text(
                  "Password has been changed successfully.",
                  style: TextStyle(color: Colors.green),
                ),
              ),

            SizedBox(height: 30),

            // Logout Button
            ElevatedButton(
              onPressed: _logout,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 15, horizontal: 30),
                backgroundColor: Colors.red[700],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: Text("Logout", style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }

  // Password Change Section with validation
  Widget _buildPasswordChangeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Change Password",
          style: Theme.of(context).textTheme.titleLarge,
        ),
        SizedBox(height: 10),
        _buildPasswordTextField("Current Password", _currentPasswordController, obscureText: true),
        SizedBox(height: 10),
        _buildPasswordTextField("New Password", _newPasswordController, obscureText: true),
        SizedBox(height: 10),
        _buildPasswordTextField("Confirm New Password", _confirmPasswordController, obscureText: true),
      ],
    );
  }

  // Helper to build password TextFields
  Widget _buildPasswordTextField(String label, TextEditingController controller, {bool obscureText = false}) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(),
      ),
    );
  }
}
