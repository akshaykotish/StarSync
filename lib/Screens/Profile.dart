import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:starsyncapp/Screens/AstrologerLogin.dart';

import 'ChatPage.dart'; // Import SharedPreferences

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  String _gender = 'Male';
  List<String> cities = ['New York', 'Los Angeles', 'Chicago', 'Houston', 'Phoenix']; // Sample dataset for cities
  List<String> filteredCities = [];
  bool showSuggestions = false;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _filterCities(String query) {
    setState(() {
      if (query.isEmpty) {
        showSuggestions = false;
      } else {
        filteredCities = cities.where((city) => city.toLowerCase().startsWith(query.toLowerCase())).toList();
        showSuggestions = true;
      }
    });
  }

  Future<void> _pickDate() async {
    DateTime? date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() {
        _selectedDate = date;
      });
    }
  }

  Future<void> _pickTime() async {
    TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (time != null) {
      setState(() {
        _selectedTime = time;
      });
    }
  }

  String _formatDate() {
    if (_selectedDate == null) return "Select your date of birth";
    return "${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}";
  }

  String _formatTime() {
    if (_selectedTime == null) return "Select your time of birth";
    return "${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}";
  }

  Future<void> _saveToSharedPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();


    // Save data to SharedPreferences
    await prefs.setString('name', _nameController.text);
    await prefs.setString('dob', _selectedDate?.toIso8601String() ?? '');
    await prefs.setString('time_of_birth', _selectedTime?.format(context) ?? '');
    await prefs.setString('contact_number', _contactController.text);
    await prefs.setString('location', _locationController.text);
    await prefs.setString('gender', _gender);

    // Navigate to Chat Page
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => ChatPage()), // Navigate to the ChatPage
    );
  }

  Future<void> saveProfile() async {
      await FirebaseFirestore.instance.collection('users').doc(_contactController.text).set({
        'name': _nameController.text,
        'dob': _selectedDate?.toIso8601String(),
        'time_of_birth': _selectedTime?.format(context),
        'contact_number': _contactController.text,
        'location': _locationController.text,
        'gender': _gender,
      });

      // Save profile to SharedPreferences
      _saveToSharedPreferences();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/background.png'), // Add your background image here
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Wrap the main content in SingleChildScrollView to handle overflow
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Top logo image
                        Image.asset(
                          'assets/logo.png', // Add your logo image here
                          height: 150,
                          width: 150,
                        ),
                        SizedBox(height: 10),

                        // Page Title
                        Text(
                          "StarSync - True Astrology",
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 28,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          "Your Kundali",
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w600,
                            fontSize: 20,
                          ),
                        ),
                        SizedBox(height: 10),

                        // Name field with label
                        _buildLabel("Name"),
                        _buildTextField(
                          controller: _nameController,
                          hint: "Enter your name",
                          icon: Icons.person,
                        ),
                        SizedBox(height: 20),

                        // Contact Number field with label
                        _buildLabel("Contact Number"),
                        _buildTextField(
                          controller: _contactController,
                          hint: "Enter your contact number",
                          icon: Icons.phone,
                          keyboardType: TextInputType.phone,
                        ),
                        SizedBox(height: 20),

                        // Date of Birth Picker
                        _buildLabel("Date of Birth"),
                        _buildDatePickerField(
                          label: _formatDate(),
                          onTap: _pickDate,
                        ),
                        SizedBox(height: 20),

                        // Time of Birth Picker
                        _buildLabel("Time of Birth"),
                        _buildTimePickerField(
                          label: _formatTime(),
                          onTap: _pickTime,
                        ),
                        SizedBox(height: 20),

                        // Location field with Label and suggestions
                        _buildLabel("Location of Birth"),
                        _buildLocationTextField(),
                        SizedBox(height: 20),
                        if (showSuggestions && filteredCities.isNotEmpty)
                          _buildSuggestions(),

                        // Gender Selection Buttons
                        Text(
                          "Gender",
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildAnimatedGenderButton(
                              icon: Icons.male,
                              label: "Male",
                              selected: _gender == 'Male',
                              onPressed: () {
                                setState(() {
                                  _gender = 'Male';
                                });
                              },
                            ),
                            SizedBox(width: 20),
                            _buildAnimatedGenderButton(
                              icon: Icons.female,
                              label: "Female",
                              selected: _gender == 'Female',
                              onPressed: () {
                                setState(() {
                                  _gender = 'Female';
                                });
                              },
                            ),
                          ],
                        ),
                        SizedBox(height: 30),

                        // Save Profile Button
                        ElevatedButton(
                          onPressed: saveProfile,
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.black, backgroundColor: Colors.amber[800], // Dark yellow button
                            padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 5,
                          ),
                          child: Text(
                            "Create Kundali",
                            style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        SizedBox(height: 10),

                        // Login as Astrologer Button
                        TextButton(
                          onPressed: () {
                            // Implement the astrologer login function here
                            print('Astrologer login clicked');
                            Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context)=>AstrologerLoginPage()));
                          },
                          child: Text(
                            "Login as StarSync team",
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.black54),
          prefixIcon: Icon(icon, color: Colors.amber[800]), // Updated icon color to match dark yellow
          border: InputBorder.none,
        ),
        textAlign: TextAlign.left,
        textAlignVertical: TextAlignVertical.center,
      ),
    );
  }

  // Custom method to build date picker field
  Widget _buildDatePickerField({required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 20),
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
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: Colors.amber[800]),
            SizedBox(width: 15),
            Text(
              label,
              style: TextStyle(color: Colors.black54, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  // Custom method to build time picker field
  Widget _buildTimePickerField({required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 20),
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
        child: Row(
          children: [
            Icon(Icons.access_time, color: Colors.amber[800]),
            SizedBox(width: 15),
            Text(
              label,
              style: TextStyle(color: Colors.black54, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  // Custom method to build the location text field with typing suggestions
  Widget _buildLocationTextField() {
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
        controller: _locationController,
        onChanged: _filterCities,
        decoration: InputDecoration(
          hintText: "Type your location",
          hintStyle: TextStyle(color: Colors.black54),
          prefixIcon: Icon(Icons.location_on, color: Colors.amber[800]), // Updated icon color to match dark yellow
          border: InputBorder.none,
        ),
        textAlign: TextAlign.left,
        textAlignVertical: TextAlignVertical.center,
      ),
    );
  }

  // Custom method to build suggestions for the location
  Widget _buildSuggestions() {
    return Container(
      height: 100,
      padding: EdgeInsets.symmetric(horizontal: 10),
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
      child: ListView.builder(
        itemCount: filteredCities.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(filteredCities[index]),
            onTap: () {
              setState(() {
                _locationController.text = filteredCities[index];
                showSuggestions = false;
              });
            },
          );
        },
      ),
    );
  }

  // Custom method to build labels for the text fields
  Widget _buildLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: TextStyle(
          color: Colors.black,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // Custom method to build gender buttons with animations
  Widget _buildAnimatedGenderButton({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onPressed,
  }) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: selected ? Colors.amber[800] : Colors.white,
        borderRadius: BorderRadius.circular(10), // Updated to a radius of 10
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          foregroundColor: selected ? Colors.white : Colors.black, backgroundColor: selected ? Colors.amber[800] : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10), // Updated to a radius of 10
          ),
          elevation: 5,
          padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? Colors.white : Colors.amber[800],
            ),
            SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.black,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
