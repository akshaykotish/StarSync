// connect.dart
import 'package:flutter/material.dart';
import '../Services/call_service.dart';

class Connect extends StatefulWidget {
  final String astrologerId;
  final String userId;

  const Connect({super.key, required this.astrologerId, required this.userId});

  @override
  State<Connect> createState() => _ConnectState();
}

class _ConnectState extends State<Connect> {
  final CallService _callService = CallService();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.call),
      color: Colors.green,
      onPressed: () async {
        // Initiate the call
        await _callService.startCall(
          callerId: widget.astrologerId,
          receiverId: widget.userId,
          context: context,
        );
      },
    );
  }
}
