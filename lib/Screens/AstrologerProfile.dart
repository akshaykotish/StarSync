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
  final TextEditingController _currentPasswordController =
  TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
  TextEditingController();

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
      DocumentSnapshot astrologerDoc =
      await _firestore.collection('astrologers').doc(astrologerId).get();

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
            SnackBar(
                content:
                Text("New password and confirm password do not match.")),
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
    await prefs.clear(); // Clear shared preferences

    // Navigate back to the login screen (or any other screen you want)
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (context)=>ProfilePage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Light background
      appBar: AppBar(
        title: Text(
          "Profile",
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black), // Back button color
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Profile Picture and Name (Optional)
            _buildProfileHeader(),

            SizedBox(height: 30),

            // Password Change Section
            _buildPasswordChangeSection(),

            SizedBox(height: 30),

            // Logout Button
            _buildLogoutButton(),
          ],
        ),
      ),
    );
  }

  // Build Profile Header with Avatar and Name
  Widget _buildProfileHeader() {
    return Column(
      children: [
        CircleAvatar(
          radius: 60,
          backgroundColor: Colors.amber[800],
          child: Icon(
            Icons.person,
            color: Colors.white,
            size: 60,
          ),
        ),
        SizedBox(height: 15),
        Text(
          "StarSync", // Replace with actual name if available
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }

  // Password Change Section with validation
  Widget _buildPasswordChangeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Change Password",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 20),
        _buildPasswordTextField(
            "Current Password", _currentPasswordController),
        SizedBox(height: 15),
        _buildPasswordTextField("New Password", _newPasswordController),
        SizedBox(height: 15),
        _buildPasswordTextField(
            "Confirm New Password", _confirmPasswordController),
        SizedBox(height: 30),
        ElevatedButton(
          onPressed: _changePassword,
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(vertical: 15, horizontal: 30),
            backgroundColor: Colors.amber[800],
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
          child: Text(
            "Change Password",
            style: TextStyle(fontSize: 18, color: Colors.white),
          ),
        ),
        if (_passwordChanged)
          Padding(
            padding: const EdgeInsets.only(top: 20.0),
            child: Text(
              "Password has been changed successfully.",
              style: TextStyle(color: Colors.green[700]),
            ),
          ),
      ],
    );
  }

  // Helper to build password TextFields
  Widget _buildPasswordTextField(
      String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      obscureText: true,
      cursorColor: Colors.amber[800],
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[800]),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.amber[800]!),
          borderRadius: BorderRadius.circular(15),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey[400]!),
          borderRadius: BorderRadius.circular(15),
        ),
        prefixIcon: Icon(
          Icons.lock_outline,
          color: Colors.amber[800],
        ),
      ),
    );
  }

  // Logout Button
  Widget _buildLogoutButton() {
    return ElevatedButton.icon(
      onPressed: _logout,
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(vertical: 15, horizontal: 30),
        backgroundColor: Colors.red[700],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
      icon: Icon(Icons.logout, color: Colors.white),
      label: Text(
        "Logout",
        style: TextStyle(fontSize: 18, color: Colors.white),
      ),
    );
  }
}
