import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class EarningsPage extends StatefulWidget {
  @override
  _EarningsPageState createState() => _EarningsPageState();
}

class _EarningsPageState extends State<EarningsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? astrologerId;
  int withdrawableAmount = 0;
  String? bankAccount;
  String? bankName;
  String? ifscCode;

  @override
  void initState() {
    super.initState();
    _loadAstrologerId();
    _fetchWithdrawableAmount();
  }

  // Load astrologer ID from SharedPreferences
  Future<void> _loadAstrologerId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      astrologerId = prefs.getString('astrologer_phone');
    });
  }

  // Fetch withdrawable income from Firestore
  Future<void> _fetchWithdrawableAmount() async {
    await _loadAstrologerId();
    if (astrologerId != null) {
      DocumentSnapshot astrologerDoc =
      await _firestore.collection('astrologers').doc(astrologerId).get();
      setState(() {
        withdrawableAmount = astrologerDoc.exists
            ? astrologerDoc['withdrawable_amount'] ?? 0
            : 0;
      });
    }
  }

  // Request withdrawal, store bank information
  Future<void> _requestWithdrawal() async {
    if (astrologerId != null &&
        bankAccount != null &&
        bankName != null &&
        ifscCode != null) {
      try {
        // Update astrologer document with bank information
        await _firestore.collection('astrologers').doc(astrologerId).update({
          'bank_account': bankAccount,
          'bank_name': bankName,
          'ifsc_code': ifscCode,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Withdrawal request submitted successfully.")),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error submitting withdrawal request: $e")),
        );
      }
    }
  }

  // Show bank information input form
  Future<void> _showBankInfoDialog() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Enter Bank Information",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 20),
                  _buildTextField("Bank Account", (value) => bankAccount = value),
                  SizedBox(height: 10),
                  _buildTextField("Bank Name", (value) => bankName = value),
                  SizedBox(height: 10),
                  _buildTextField("IFSC Code", (value) => ifscCode = value),
                  SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        child: Text(
                          "Cancel",
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                      SizedBox(width: 10),
                      ElevatedButton(
                        child: Text("Submit"),
                        onPressed: () {
                          Navigator.of(context).pop();
                          _requestWithdrawal();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextField(String label, Function(String) onChanged) {
    return TextField(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[800]),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.grey[800]!),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.grey[800]!),
        ),
      ),
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top,
        left: 10,
        right: 10,
        bottom: 10,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        children: [
          Center(
            child: Text(
              "Earnings",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          SizedBox(height: 10),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildWithdrawableCard(context), // Withdrawable amount card
                    Text("Answered Questions"),
                    Expanded(child: _buildSolvedChatsList()), // Solved chats
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Card showing the astrologer's withdrawable amount with icon button
  Widget _buildWithdrawableCard(BuildContext context) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: EdgeInsets.symmetric(vertical: 10),
      child: InkWell(
        onTap: _showBankInfoDialog,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(30.0),
          decoration: BoxDecoration(
            color: Colors.blue[600],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(
                Icons.account_balance_wallet,
                size: 50,
                color: Colors.white,
              ),
              SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Withdrawable Income",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "₹$withdrawableAmount",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // List of solved chats as transactions
  Widget _buildSolvedChatsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('astrologers')
          .doc(astrologerId)
          .collection('solved')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(),
          );
        }

        var solvedChats = snapshot.data!.docs;

        if (solvedChats.isEmpty) {
          return Center(
            child: Text(
              "No transactions found.",
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          );
        }

        return ListView.builder(
          itemCount: solvedChats.length,
          itemBuilder: (context, index) {
            var solvedChat = solvedChats[index].data() as Map<String, dynamic>;
            DateTime date = (solvedChat['timestamp'] as Timestamp).toDate();
            int cost = solvedChat['cost'] ?? 0;
            String questionId = solvedChat['question_id'];
            String userId = solvedChat['user_id'];

            return _buildTransactionCard(questionId, userId, date, cost, index);
          },
        );
      },
    );
  }

  // Card for each solved transaction with unique styles
  Widget _buildTransactionCard(
      String questionId, String userId, DateTime date, int cost, int index) {
    // Define a list of colors and shapes for unique styles
    final List<Color> colors = [
      Colors.black!,
      Colors.purple[400]!,
      Colors.orange[400]!,
      Colors.indigo[400]!,
      Colors.green[400]!,
    ];

    final List<BoxDecoration> decorations = [
      BoxDecoration(
        color: colors[index % colors.length],
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            spreadRadius: 2,
            blurRadius: 5,
            offset: Offset(0, 3),
          ),
        ],
      ),
      BoxDecoration(
        gradient: LinearGradient(
          colors: [colors[index % colors.length], Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: colors[index % colors.length], width: 2),
      ),
      BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(15),
      ),
      BoxDecoration(
        color: colors[index % colors.length],
        borderRadius: BorderRadius.circular(0),
      ),
    ];

    return Card(
      elevation: 3,
      margin: EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        decoration: decorations[index % decorations.length],
        child: ListTile(
          contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
          leading: Icon(
            Icons.question_answer,
            color: index % 2 == 0 ? Colors.white : colors[index % colors.length],
            size: 30,
          ),
          title: Text(
            "Question ID: \n$questionId",
            style: TextStyle(
              color: index % 2 == 0 ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 12
            ),
          ),
          subtitle: Text(
            "${DateFormat('yyyy-MM-dd HH:mm').format(date)}",
            style: TextStyle(
              color: index % 2 == 0 ? Colors.white70 : Colors.grey[700],
            ),
          ),
          trailing: Text(
            "₹$cost",
            style: TextStyle(
              color: index % 2 == 0 ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
      ),
    );
  }
}
