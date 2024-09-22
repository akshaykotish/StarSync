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
    print("SMFKM" + astrologerId.toString());
    if (astrologerId != null) {
      DocumentSnapshot astrologerDoc = await _firestore.collection('astrologers').doc(astrologerId).get();
      setState(() {
        withdrawableAmount = astrologerDoc.exists
            ? astrologerDoc['withdrawable_amount'] ?? 0
            : 0;
      });
    }
  }

  // Request withdrawal, store bank information
  Future<void> _requestWithdrawal() async {
    if (astrologerId != null && bankAccount != null && bankName != null && ifscCode != null) {
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
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
          ),
          title: Text("Enter Bank Information", style: Theme.of(context).textTheme.titleLarge),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField("Bank Account", (value) => bankAccount = value),
              _buildTextField("Bank Name", (value) => bankName = value),
              _buildTextField("IFSC Code", (value) => ifscCode = value),
            ],
          ),
          actions: [
            TextButton(
              child: Text("Cancel", style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: Text("Submit"),
              onPressed: () {
                Navigator.of(context).pop();
                _requestWithdrawal();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildTextField(String label, Function(String) onChanged) {
    return TextField(
      decoration: InputDecoration(labelText: label),
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Earnings", style: Theme.of(context).textTheme.titleLarge),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildWithdrawableCard(context), // Withdrawable amount card
            SizedBox(height: 20),
            _buildRequestWithdrawalButton(), // Request withdrawal button
            SizedBox(height: 20),
            Expanded(child: _buildSolvedChatsList()), // Solved chats transactions
          ],
        ),
      ),
    );
  }

  // Card showing the astrologer's withdrawable amount
  Widget _buildWithdrawableCard(BuildContext context) {
    return Card(
      elevation: 10,
      shadowColor: Colors.amber[800],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.amber[400]!, Colors.amber[800]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Withdrawable Income",
              style: Theme.of(context).textTheme.titleLarge!.copyWith(color: Colors.white),
            ),
            SizedBox(height: 10),
            Text(
              "\$$withdrawableAmount",
              style: Theme.of(context).textTheme.headlineMedium!.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  // Button to request withdrawal
  Widget _buildRequestWithdrawalButton() {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(vertical: 15, horizontal: 30),
        backgroundColor: Colors.amber[800],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      icon: Icon(Icons.request_page, size: 26),
      label: Text("Request Withdrawal", style: TextStyle(fontSize: 18)),
      onPressed: _showBankInfoDialog,
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
          return Center(child: CircularProgressIndicator());
        }

        var solvedChats = snapshot.data!.docs;

        if (solvedChats.isEmpty) {
          return Center(
            child: Text(
              "No transactions found.",
              style: TextStyle(color: Colors.grey, fontSize: 16),
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

            return _buildTransactionCard(questionId, userId, date, cost);
          },
        );
      },
    );
  }

  // Card for each solved transaction
  Widget _buildTransactionCard(String questionId, String userId, DateTime date, int cost) {
    return Card(
      elevation: 5,
      margin: EdgeInsets.symmetric(vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        title: Text(
          "Question ID: $questionId",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          "User ID: $userId\nDate: ${DateFormat('yyyy-MM-dd HH:mm').format(date)}",
          style: TextStyle(color: Colors.grey[700]),
        ),
        trailing: Text(
          "\$$cost",
          style: TextStyle(
            color: Colors.green[700],
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}
