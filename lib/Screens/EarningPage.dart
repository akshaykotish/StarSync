import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class EarningsPage extends StatefulWidget {
  @override
  _EarningsPageState createState() => _EarningsPageState();
}

class _EarningsPageState extends State<EarningsPage> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? astrologerId;
  int withdrawableAmount = 0;
  String? bankAccount;
  String? bankName;
  String? ifscCode;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _loadAstrologerId();
    _fetchWithdrawableAmount();
    _tabController = TabController(length: 2, vsync: this);
  }

  Future<void> _loadAstrologerId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      astrologerId = prefs.getString('astrologer_phone');
    });
  }

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

  Future<void> _requestWithdrawal() async {
    if (astrologerId != null &&
        bankAccount != null &&
        bankName != null &&
        ifscCode != null) {
      try {
        // Create a new withdrawal request in Firestore
        String withdrawalId = _firestore.collection('astrologers').doc(astrologerId)
            .collection('withdrawals').doc().id;

        await _firestore.collection('astrologers').doc(astrologerId)
            .collection('withdrawals').doc(withdrawalId).set({
          'amount': withdrawableAmount,
          'status': 'pending',
          'bank_account': bankAccount,
          'bank_name': bankName,
          'ifsc_code': ifscCode,
          'timestamp': FieldValue.serverTimestamp(),
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
              child: Column(
                children: [
                  _buildWithdrawableCard(context),
                  TabBar(
                    controller: _tabController,
                    tabs: [
                      Tab(text: "Answered Questions"),
                      Tab(text: "Withdrawal Requests"),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildSolvedChatsList(),
                        _buildWithdrawalsList(),
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

            return ListTile(
              title: Text("Question ID: $questionId"),
              subtitle: Text("Answered for User: $userId on ${DateFormat.yMMMd().format(date)}"),
              trailing: Text("₹$cost"),
            );
          },
        );
      },
    );
  }

  Widget _buildWithdrawalsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('astrologers')
          .doc(astrologerId)
          .collection('withdrawals')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(),
          );
        }

        var withdrawals = snapshot.data!.docs;

        if (withdrawals.isEmpty) {
          return Center(
            child: Text(
              "No withdrawal requests found.",
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          );
        }


        return ListView.builder(
          itemCount: withdrawals.length,
          itemBuilder: (context, index) {
            var withdrawal = withdrawals[index].data() as Map<String, dynamic>;
            DateTime date = (withdrawal['timestamp'] as Timestamp).toDate();
            String status = withdrawal['status'] ?? 'unknown';
            int amount = withdrawal['amount'] ?? 0;

            return ListTile(
              title: Text("Requested Withdrawal: ₹$amount"),
              subtitle: Text(
                  "Status: $status on ${DateFormat.yMMMd().format(date)}"),
              trailing: Icon(
                status == 'pending' ? Icons.hourglass_empty : Icons.check_circle,
                color: status == 'pending' ? Colors.orange : Colors.green,
              ),
            );
          },
        );
      },
    );
  }
}
