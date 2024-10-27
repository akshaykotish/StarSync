import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:firebase_analytics/firebase_analytics.dart';


class BuyQuestionPage extends StatefulWidget {
  @override
  _BuyQuestionPageState createState() => _BuyQuestionPageState();
}

class _BuyQuestionPageState extends State<BuyQuestionPage> {
  bool _isPurchased = false;
  late Razorpay _razorpay;

  late FirebaseAnalytics analytics; // Add this line


  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  String? questionId;
  String? questionName;
  double? cost;
  double? platformFees;
  double? margin;
  double? tax;
  double? price;
  String? purchaseId;
  String? contactNumber;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();

    analytics = FirebaseAnalytics.instance; // Initialize Firebase Analytics


    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

    fetchQuestionData();
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void fetchQuestionData() async {
    try {
      DocumentSnapshot docSnapshot = await _firestore
          .collection('questions')
          .doc('question50')
          .get();

      if (docSnapshot.exists) {
        Map<String, dynamic> data = docSnapshot.data() as Map<String, dynamic>;
        print("FMFO");
        print(data);
        setState(() {
          questionId = docSnapshot.id;
          questionName = data['question_name'];
          cost = double.parse(data['question_cost'].toString());
          platformFees = double.parse(data['platform_fees'].toString());
          margin = double.parse(data['margin'].toString());
          tax = double.parse(data['tax'].toString());
          price = double.parse(data['price'].toString());
          _isLoading = false;
        });
      } else {
        // Create the document with default values
        int defaultCost = 25;
        int defaultMargin = 25;
        int defaultTax = 9;
        int defaultPlatformFees = 0;
        int defaultPrice =
            defaultCost + defaultMargin + defaultTax + defaultPlatformFees;

        await _firestore.collection('questions').doc('question50').set({
          'question_name': 'Default Question',
          'question_cost': defaultCost,
          'platform_fees': defaultPlatformFees,
          'margin': defaultMargin,
          'tax': defaultTax,
          'price': defaultPrice,
          'default': true,
        });

        setState(() {
          questionId = 'question50';
          questionName = 'Default Question';
          cost = defaultCost.toDouble();
          platformFees = defaultPlatformFees.toDouble();
          margin = defaultMargin.toDouble();
          tax = defaultTax.toDouble();
          price = defaultPrice.toDouble();
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching or creating question data: $e");
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching question data.")),
      );
    }
  }

  void openCheckout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    contactNumber = prefs.getString('contact_number') ?? 'Unknown';

    // Generate purchaseId before initiating payment
    purchaseId = Uuid().v4();

    var options = {
      'key': 'rzp_live_tix0poupMkd0TQ',
      'amount': price! * 100,
      'name': 'StarSync',
      'description': 'Purchase Question',
      'prefill': {
        'contact': contactNumber,
      },
      'notes': {
        'question_id': questionId,
        'purchase_id': purchaseId,
        'user_id': contactNumber,
        // Add other information if needed
      },
      'external': {
        'wallets': ['paytm']
      }
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      print(e.toString());
    }
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    if (contactNumber != null && purchaseId != null) {
      try {
        await _firestore.collection('purchase').doc(purchaseId).set({
          'purchase_id': purchaseId,
          'question_id': questionId,
          'user_id': contactNumber,
          'cost': cost,
          'platform_fees': platformFees,
          'margin': margin,
          'tax': tax,
          'price': price,
          'payment_id': response.paymentId,
          'signature': response.signature,
          'timestamp': Timestamp.now(),
        });

        await _firestore
            .collection('users')
            .doc(contactNumber)
            .collection('purchases')
            .doc(purchaseId)
            .set({
          'purchase_id': purchaseId,
          'question_id': questionId,
          'timestamp': Timestamp.now(),
        });

        DocumentSnapshot userDoc =
        await _firestore.collection('users').doc(contactNumber).get();
        int availableQuestions = userDoc.exists &&
            (userDoc.data() as Map<String, dynamic>)
                .containsKey('available_questions')
            ? (userDoc.data() as Map<String, dynamic>)['available_questions']
            : 0;

        await _firestore.collection('users').doc(contactNumber).update({
          'available_questions': availableQuestions + 1,
        });

        // Log event to Firebase Analytics
        await analytics.logEvent(
          name: 'purchase_successful',
          parameters: {
            'purchase_id': purchaseId!,
            'question_id': questionId!,
            'user_id': contactNumber!,
            'price': price!,
            'payment_id': response.paymentId!,
          },
        );

        setState(() {
          _isPurchased = true;
        });

        Timer(Duration(seconds: 3), () {
          Navigator.pop(context, true);
        });
      } catch (e) {
        print("Error purchasing question: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error purchasing question.")),
        );
      }
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Payment failed. Please try again.")),
    );

    // Log event to Firebase Analytics
    analytics.logEvent(
      name: 'payment_failed',
      parameters: {
        'error_code': response.code!,
        'error_message': response.message!,
        'user_id': contactNumber!,
      },
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
          Text("External wallet selected: ${response.walletName}")),
    );

    // Log event to Firebase Analytics
    analytics.logEvent(
      name: 'external_wallet_selected',
      parameters: {
        'wallet_name': response.walletName!,
        'user_id': contactNumber!,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/buypage.png"),
            fit: BoxFit.cover,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  if (!_isPurchased)
                    Column(
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height/10),
                        Text(
                          "Get a solution to your question.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[900]),
                        ),
                        SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: openCheckout,
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.blue,
                            padding: EdgeInsets.symmetric(
                                horizontal: 50, vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            "Pay ₹$price",
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  if (_isPurchased)
                    Container(
                      padding: EdgeInsets.only(top: 75,),
                      child: Column(
                        children: [
                          Icon(Icons.check_circle,
                              color: Colors.green, size: 80),
                          SizedBox(height: 10),
                          Text(
                            "Purchase Complete!",
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 10),
                          Text("You can now ask your question."),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Positioned(
              top: 50,
              left: 10,
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                },
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back,
                          color: Colors.black, size: 20),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                    Text("Chat")
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
