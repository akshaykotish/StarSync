import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:starsyncapp/Screens/AstrologerLogin.dart';
import 'package:pinput/pinput.dart';
import 'package:smart_auth/smart_auth.dart';
import 'package:starsyncapp/Screens/SmsRetrieverImpl.dart';

import 'ChatPage.dart';

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  bool _isLoading = false;


  String _verificationId = '';
  String _gender = 'Male';
  List<String> cities = ['New York', 'Los Angeles', 'Chicago', 'Houston', 'Phoenix']; // Sample dataset for cities
  List<String> filteredCities = [];
  bool showSuggestions = false;
  bool _isPhoneVerified = false;

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

  Future<void> _verifyPhoneNumber() async {
    setState(() {
      _isLoading = true;
    });

    if(_contactController.text.length == 10)
      {
        _contactController.text = "+91" + _contactController.text;
      }

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: _contactController.text,
      verificationCompleted: (PhoneAuthCredential credential) async {
        _dismissLoadingIndicator();
        // Auto-retrieval or instant verification callback
      },
      verificationFailed: (FirebaseAuthException e) {
        _dismissLoadingIndicator();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Verification failed: ${e.message}")));
      },
      codeSent: (String verificationId, int? resendToken) {
        _dismissLoadingIndicator();
        setState(() {
          _verificationId = verificationId;
        });
        _showOtpModal();
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _dismissLoadingIndicator();
        setState(() {
          _verificationId = verificationId;
        });
      },
    );
  }

  void _dismissLoadingIndicator() {
    if (_isLoading) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showOtpModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: MediaQuery.of(context).viewInsets,
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).platform == TargetPlatform.iOS ? Colors.grey[100] : Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "OTP Verification",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  "Enter the OTP sent to your registered mobile number",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 20),
                Pinput(
                  length: 6, // Set OTP length to 6 digits
                  smsRetriever: SmsRetrieverImpl(SmartAuth()),
                  controller: _otpController,
                  focusNode: FocusNode(),
                  defaultPinTheme: PinTheme(
                    width: 56,
                    height: 56,
                    textStyle: const TextStyle(
                      fontSize: 22,
                      color: Color.fromRGBO(30, 60, 87, 1),
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(19),
                      border: Border.all(color: Colors.amber), // Updated color to amber
                    ),
                  ),
                  separatorBuilder: (index) => const SizedBox(width: 8),
                  validator: (value) {
                    return value?.length == 6 ? null : 'Pin must be 6 digits';
                  },
                  hapticFeedbackType: HapticFeedbackType.lightImpact,
                  onCompleted: (pin) {
                    debugPrint('onCompleted: $pin');
                    _submitOtp(context);
                  },
                  onChanged: (value) {
                    debugPrint('onChanged: $value');
                  },
                  cursor: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(bottom: 9),
                        width: 22,
                        height: 1,
                        color: Colors.amber,
                      ),
                    ],
                  ),
                  focusedPinTheme: PinTheme(
                    width: 56,
                    height: 56,
                    textStyle: const TextStyle(
                      fontSize: 22,
                      color: Color.fromRGBO(30, 60, 87, 1),
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber), // Updated color to amber
                    ),
                  ),
                  submittedPinTheme: PinTheme(
                    width: 56,
                    height: 56,
                    textStyle: const TextStyle(
                      fontSize: 22,
                      color: Color.fromRGBO(30, 60, 87, 1),
                    ),
                    decoration: BoxDecoration(
                      color: Color.fromRGBO(243, 246, 249, 0),
                      borderRadius: BorderRadius.circular(19),
                      border: Border.all(color: Colors.amber), // Updated color to amber
                    ),
                  ),
                  errorPinTheme: PinTheme(
                    width: 56,
                    height: 56,
                    textStyle: const TextStyle(
                      fontSize: 22,
                      color: Color.fromRGBO(30, 60, 87, 1),
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(19),
                      border: Border.all(color: Colors.redAccent),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: (){_submitOtp(context);},
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 15, horizontal: 100),
                    backgroundColor: Colors.amber,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 5,
                  ),
                  child: Text(
                    "Verify",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    // Logic for resending OTP
                  },
                  child: Text(
                    "Resend OTP",
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _submitOtp(modalcontext) async {
    String otp = _otpController.text.trim();
    PhoneAuthCredential credential = PhoneAuthProvider.credential(
      verificationId: _verificationId,
      smsCode: otp,
    );
    try {
      await FirebaseAuth.instance.signInWithCredential(credential);
      _dismissLoadingIndicator();

      Navigator.of(modalcontext).pop();

      setState(() {
        _isLoading = false;
        _isPhoneVerified = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Phone number verified successfully")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Invalid OTP. Please try again.")));
    }
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

    _isLoading = false;
    setState(() {

    });
  }

  Future<void> saveProfile() async {
    _isLoading = true;
    setState(() {

    });
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
                borderRadius: BorderRadius.circular(10)
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
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(height: 20,),
                        // Top logo image
                        Image.asset(
                          'assets/logo.png', // Add your logo image here
                          height: 100,
                          width: 100,
                        ),
                        SizedBox(height: 10),

                        // Page Title
                        Text(
                          "StarSync - The Real Astrology",
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          "Your Birth Details",
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w300,
                            fontSize: 14,
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
                        SizedBox(height: 15),

                        // Contact Number field with label and verify button
                        _buildLabel("Contact Number"),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _contactController,
                                hint: "+919990912230",
                                icon: Icons.phone,
                                keyboardType: TextInputType.phone,
                                enabled: !_isPhoneVerified,
                              ),
                            ),
                            SizedBox(width: 10),
                            if (!_isPhoneVerified)
                              ElevatedButton(
                                onPressed: _verifyPhoneNumber,
                                style: ElevatedButton.styleFrom(
                                  minimumSize: Size(100, 55),
                                  foregroundColor: Colors.white, backgroundColor: Colors.amber,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text("Verify"),
                              ),
                          ],
                        ),
                        SizedBox(height: 15),

                        // Date of Birth Picker
                        _buildLabel("Date of Birth"),
                        _buildDatePickerField(
                          label: _formatDate(),
                          onTap: _pickDate,
                        ),
                        SizedBox(height: 15),

                        // Time of Birth Picker
                        _buildLabel("Time of Birth"),
                        _buildTimePickerField(
                          label: _formatTime(),
                          onTap: _pickTime,
                        ),
                        SizedBox(height: 15),

                        // Location field with Label and suggestions
                        _buildLabel("Location of Birth"),
                        _buildLocationTextField(),
                        SizedBox(height: 15),
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

                        // Save Profile Button (visible only after phone verification)
                        if (_isPhoneVerified)
                          ElevatedButton(
                            onPressed: () {
                              if (_nameController.text.isEmpty || _contactController.text.isEmpty || _selectedDate == null || _selectedTime == null || _locationController.text.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Please fill in all the details.")));
                              } else {
                                saveProfile();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.black, backgroundColor: Colors.amber, // Dark yellow button
                              padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 5,
                            ),
                            child: Text(
                              "Process Chart",
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
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black45, // Semi-transparent background
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.amber), // Optional: match your theme color
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
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
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
        enabled: enabled,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.black54),
          prefixIcon: Icon(icon, color: Colors.amber), // Updated icon color to match dark yellow
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
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 15),
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
            Icon(Icons.calendar_today, color: Colors.amber),
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
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 15),
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
            Icon(Icons.access_time, color: Colors.amber),
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
          prefixIcon: Icon(Icons.location_on, color: Colors.amber), // Updated icon color to match dark yellow
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
        color: selected ? Colors.amber : Colors.white,
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
          foregroundColor: selected ? Colors.white : Colors.black, backgroundColor: selected ? Colors.amber : Colors.white,
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
              color: selected ? Colors.white : Colors.amber,
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
