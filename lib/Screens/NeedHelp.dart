import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NeedHelp extends StatefulWidget {
  @override
  _NeedHelpState createState() => _NeedHelpState();
}

class _NeedHelpState extends State<NeedHelp> {
  late DateTime lastInteractionDate;
  late String message;
  bool _isLoading = true;
  late String contactNumber;
  late int availableQuestions;
  int cost = 0;
  int price = 0;

  @override
  void initState() {
    super.initState();
    _getUserData();
  }

  void _getUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    contactNumber = prefs.getString('contact_number') ?? 'Unknown';

    // Get last interaction date
    int lastInteractionMillis = prefs.getInt('last_interaction') ?? 0;
    if (lastInteractionMillis != 0) {
      lastInteractionDate =
          DateTime.fromMillisecondsSinceEpoch(lastInteractionMillis);
    } else {
      // Set a default last interaction date (e.g., two days ago)
      lastInteractionDate = DateTime.now().subtract(Duration(days: 2));
    }

    // Get available_questions
    availableQuestions = prefs.getInt('available_questions') ?? 0;

    _checkLastInteraction();
  }

  void _checkLastInteraction() {
    final difference = DateTime.now().difference(lastInteractionDate).inDays;
    if (difference >= 1) {
      // User hasn't interacted in over a day
      _grantFreeQuestion();
      setState(() {
        message =
        "You haven't received any replies in a day or didn't match expectations. We've granted you a free question!";
        _isLoading = false;
      });
    } else {
      // User has recent interactions
      setState(() {
        message = "You will receive a message from astrologer. Check your messages in chat.";
        _isLoading = false;
      });
    }
  }

  void _grantFreeQuestion() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Increment available_questions
    int currentAvailableQuestions = prefs.getInt('available_questions') ?? 0;
    currentAvailableQuestions += 1;
    await prefs.setInt('available_questions', currentAvailableQuestions);

    // Update last interaction date
    await prefs.setInt(
        'last_interaction', DateTime.now().millisecondsSinceEpoch);

    // Record cost and price as 0 in SharedPreferences (optional)
    await prefs.setInt('free_question_cost', cost);
    await prefs.setInt('free_question_price', price);

    // Optionally, maintain a list of free question records
    List<String> freeQuestions = prefs.getStringList('free_questions') ?? [];
    String freeQuestionRecord = 'Date: ${DateTime.now()}, Cost: $cost, Price: $price';
    freeQuestions.add(freeQuestionRecord);
    await prefs.setStringList('free_questions', freeQuestions);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Need Help'),
        ),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            color: Color(0xFFFFFD77),
          ),
          child: Stack(
            children: [
              Container(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                padding: EdgeInsets.all(50),
                decoration: BoxDecoration(

                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset("assets/issue.png",scale: 4,),
                    SizedBox(height: 40,),
                    Text(
                      message ?? "Loading...",
                      style: TextStyle(fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 40,),
                    Text(
                      "You can also mail us to connect@akshaykotish.com",
                      style: TextStyle(fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 80,
                left: 20,
                child: GestureDetector(
                  onTap: (){Navigator.pop(context);},
                  child: Container(
                    child: Row(
                      children: [
                        Icon(Icons.arrow_back),
                        SizedBox(width: 5,),
                        Text("Back to Chat")
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ));
  }
}
