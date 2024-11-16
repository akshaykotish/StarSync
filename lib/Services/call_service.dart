// call_service.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';

import '../Screens/VideoCallScreen.dart';

class CallService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  final AudioPlayer _audioPlayer = AudioPlayer();

  StreamSubscription<DocumentSnapshot>? _callSubscription;


  Future<void> startCall({
    required String callerId,
    required String receiverId,
    required BuildContext context,
  }) async {
    String callId = '$callerId-$receiverId-${DateTime.now().millisecondsSinceEpoch}';

    // Create initial call details
    Map<String, dynamic> callData = {
      'callId': callId,
      'astrologerId': callerId,
      'status': 'calling', // or 'ringing'
      'startTime': FieldValue.serverTimestamp(),
      'endTime': null,
      'duration': null,
    };

    // Create a call document in the user's calls subcollection
    await _firestore
        .collection('users')
        .doc(receiverId)
        .collection('calls')
        .doc(callId)
        .set(callData);

    // Create offer and save to Firestore
    await _createOffer(callId, receiverId);


    // Navigate to VideoCallScreen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoCallScreen(
          callId: callId,
          userId: callerId,
          isCaller: true,
          receiverId: receiverId,
        ),
      ),
    );
  }

  Future<void> acceptCall(String callId, String userId) async {
    // Update call status to 'in_progress'
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('calls')
        .doc(callId)
        .update({'status': 'in_progress'});

    // Answer the call and save to Firestore
    await _createAnswer(callId, userId);
  }

  Future<void> rejectCall(String callId, String receiverId) async {
    // Update the call document status to 'rejected'
    String callDocPath = 'users/$receiverId/calls/$callId';

    await _firestore.doc(callDocPath).update({
      'status': 'rejected',
      'endTime': FieldValue.serverTimestamp(),
    });

    // Generate a new message ID
    String messageId = _firestore.collection('users').doc(receiverId).collection('message').doc().id;

    // Retrieve the caller's ID from the call document
    DocumentSnapshot<Map<String, dynamic>> callDoc = await _firestore.doc(callDocPath).get();
    Map<String, dynamic>? callData = callDoc.data();

    String callerId = callData?['astrologerId'] ?? 'Unknown';

    // Construct the message text
    String messageText = 'You missed a call from the astrologer.\nTime: ${FieldValue.serverTimestamp()}';

    // Prepare message data
    Map<String, dynamic> messageData = {
      'from': callerId,
      'media_files': null,
      'message_id': messageId,
      'message_text': messageText,
      'timestamp': FieldValue.serverTimestamp(),
      'usertype': 'astrologer',
    };

    // Save the message document
    await _firestore
        .collection('users')
        .doc(receiverId)
        .collection('message')
        .doc(messageId)
        .set(messageData);

    print("Message saved to user's messages.");

    // Cancel the call subscription if any
    await _callSubscription?.cancel();

    print("Call rejected and call document updated.");
  }

  Future<void> joinCall(
      String callId,
      String userId,
      RTCVideoRenderer localRenderer,
      RTCVideoRenderer remoteRenderer,
      bool isCaller,
      String receiverId,
      BuildContext context, // Add context to navigate
      ) async {
    // Implement the logic to handle joining the call
    // This involves setting up the RTCPeerConnection and exchanging SDP and ICE candidates
    await _setupPeerConnection(localRenderer, remoteRenderer);

    // Set up media streams
    _localStream?.getTracks().forEach((track) {
      _peerConnection?.addTrack(track, _localStream!);
    });

    _peerConnection?.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        remoteRenderer.srcObject = event.streams[0];
      }
    };

    // Listen for call document changes
    String callDocPath = 'users/$receiverId/calls/$callId';

    // Listen for remote session description
    _firestore.doc(callDocPath).snapshots().listen((snapshot) async {
      if (snapshot.exists) {
        var data = snapshot.data();
        if (data != null) {


          // Check if the call has ended
          if (data['status'] == 'ended') {
            print("Call has been ended by the other participant.");
            await _peerConnection?.close();
            await _localStream?.dispose();
            _peerConnection = null;
            _localStream = null;

            // Cancel the call subscription
            await _callSubscription?.cancel();

            // Close the video call screen
            if (context != null) {
              Navigator.of(context).pop();
            }


            // Handle remote session description
          if (data['answer'] != null && isCaller) {
            var answer = RTCSessionDescription(
              data['answer']['sdp'],
              data['answer']['type'],
            );
            await _peerConnection?.setRemoteDescription(answer);
          }
          if (data['offer'] != null && !isCaller) {
            var offer = RTCSessionDescription(
              data['offer']['sdp'],
              data['offer']['type'],
            );
            await _peerConnection?.setRemoteDescription(offer);
          }

          // Check if the call was rejected
          if (data['status'] == 'rejected') {
            print('Call was rejected by the receiver.');

            // End the call and navigate back
            await _peerConnection?.close();
            _localStream?.dispose();
            _peerConnection = null;
            _localStream = null;

            // Close the video call screen and show a message
            if (context != null) {
              Navigator.of(context).pop();

              // Optionally, show a dialog to notify the caller
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Call Rejected'),
                  content: Text('The receiver has rejected the call.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(), // Close the dialog
                      child: Text('OK'),
                    ),
                  ],
                ),
              );
            }
          }


}
        }
      }
    });

    // Listen for ICE candidates from the remote peer
    String remoteCandidatesCollection = isCaller ? 'calleeCandidates' : 'callerCandidates';

    _firestore
        .doc(callDocPath)
        .collection(remoteCandidatesCollection)
        .snapshots()
        .listen((snapshot) {
      for (var document in snapshot.docs) {
        var data = document.data();
        RTCIceCandidate candidate = RTCIceCandidate(
          data['candidate'],
          data['sdpMid'],
          data['sdpMLineIndex'],
        );
        _peerConnection?.addCandidate(candidate);
      }
    });
  }

  //bool _isCallEnded = false;

  Future<void> endCall(String callId, String userId, String receiverId, bool isCaller) async {
    // if (_isCallEnded) {
    //   return;
    // }
    //_isCallEnded = true;

    await _peerConnection?.close();
    _localStream?.dispose();
    _peerConnection = null;
    _localStream = null;

    // Get startTime to calculate duration
    DocumentSnapshot<Map<String, dynamic>> callDoc = await _firestore
        .collection('users')
        .doc(receiverId)
        .collection('calls')
        .doc(callId)
        .get();

    if (callDoc.exists) {
      Timestamp? startTime = callDoc.data()?['startTime'];
      Timestamp endTime = Timestamp.now();

      int duration = 0;
      if (startTime != null) {
        duration = endTime.seconds - startTime.seconds;
      }

      // Update call document
      await _firestore
          .collection('users')
          .doc(receiverId)
          .collection('calls')
          .doc(callId)
          .update({
        'status': 'ended',
        'endTime': endTime,
        'duration': duration, // in seconds
      });

      String callDocPath = 'users/$receiverId/calls/$callId';


      // Only proceed if this instance is the caller to avoid duplicate messages
      if (isCaller) {
        // Generate a new message ID
        String messageId = _firestore.collection('users').doc(receiverId).collection('message').doc().id;

        // Retrieve call details to calculate duration
        DocumentSnapshot<Map<String, dynamic>> callDoc = await _firestore.doc(callDocPath).get();
        Map<String, dynamic>? callData = callDoc.data();

        Timestamp? startTime = callData?['startTime'];
        int durationInSeconds = 0;
        if (startTime != null) {
          durationInSeconds = endTime.seconds - startTime.seconds;
        }

        String messageText;
        if (durationInSeconds > 0) {
          int minutes = durationInSeconds ~/ 60;
          int seconds = durationInSeconds % 60;
          String durationString = '${minutes}m ${seconds}s';
          messageText = 'You had a call with the astrologer.\nDuration: $durationString\nTime: ${endTime.toDate()}';
        } else {
          messageText = 'You missed a call from the astrologer.\nTime: ${endTime.toDate()}';
        }

        // Prepare message data
        Map<String, dynamic> messageData = {
          'from': userId, // Caller ID (astrologer ID)
          'media_files': null,
          'message_id': messageId,
          'message_text': messageText,
          'timestamp': endTime,
          'usertype': 'astrologer',
        };

        // Save the message document
        await _firestore
            .collection('users')
            .doc(receiverId)
            .collection('message')
            .doc(messageId)
            .set(messageData);

        print("Message saved to user's messages.");
      }


      // Cancel the subscription
      await _callSubscription?.cancel();

      print("Call ended and call document updated.");

    }
  }

  Future<void> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.microphone,
    ].request();

    if (statuses[Permission.camera] != PermissionStatus.granted ||
        statuses[Permission.microphone] != PermissionStatus.granted) {
      // Handle the case when permissions are not granted
      print("Camera and microphone permissions are required.");
      // Show an alert dialog or navigate back
    }
  }

  Future<void> openUserMedia(
      RTCVideoRenderer localRenderer,
      RTCVideoRenderer remoteRenderer,
      ) async {

    try {
      // Request permissions
      await _requestPermissions();


      final Map<String, dynamic> mediaConstraints = {
        'audio': true,
        'video': {'facingMode': 'user'},
      };

      try {
        _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
        print("Local stream obtained: $_localStream");
        print("Local stream tracks: ${_localStream?.getTracks()}");

      } catch (e) {
        print("Error obtaining user media: $e");
      }

      localRenderer.srcObject = _localStream;
      print("Local renderer assigned.");
    }
    catch (e) {
      print("Error obtaining user media: $e");
    }

  }

  void toggleMute(bool mute) {
    _localStream?.getAudioTracks()[0].enabled = !mute;
  }

  Future<void> _createOffer(String callId, String receiverId) async {
    await _setupPeerConnection(null, null);

    RTCSessionDescription offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    // Save offer to the call document
    await _firestore
        .collection('users')
        .doc(receiverId)
        .collection('calls')
        .doc(callId)
        .update({
      'offer': offer.toMap(),
    });

    // Listen for ICE candidates and add them to Firestore
    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) async {
      print("New ICE candidate: ${candidate.toMap()}");

      _firestore
          .collection('users')
          .doc(receiverId)
          .collection('calls')
          .doc(callId)
          .collection('callerCandidates')
          .add(candidate.toMap());
    };
  }

  Future<void> _createAnswer(String callId, String userId) async {
    DocumentSnapshot<Map<String, dynamic>> callDoc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('calls')
        .doc(callId)
        .get();


    if (callDoc.exists) {
      var data = callDoc.data();
      if (data != null && data['offer'] != null) {
        await _setupPeerConnection(null, null);

        RTCSessionDescription offer = RTCSessionDescription(
          data['offer']['sdp'],
          data['offer']['type'],
        );
        await _peerConnection!.setRemoteDescription(offer);

        RTCSessionDescription answer = await _peerConnection!.createAnswer();
        await _peerConnection!.setLocalDescription(answer);

        // Save answer to Firestore
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('calls')
            .doc(callId)
            .update({
          'answer': answer.toMap(),
        });

        // Listen for ICE candidates and add them to Firestore
        _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
          _firestore
              .collection('users')
              .doc(userId)
              .collection('calls')
              .doc(callId)
              .collection('calleeCandidates')
              .add(candidate.toMap());
        };
      }
    }
  }

  Future<void> _setupPeerConnection(RTCVideoRenderer? localRenderer,
      RTCVideoRenderer? remoteRenderer,) async {
    final Map<String, dynamic> configuration = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ]
    };

    _peerConnection = await createPeerConnection(configuration);

    _peerConnection?.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        if (remoteRenderer != null) {
          remoteRenderer.srcObject = event.streams[0];
        }
      }
    };
  }

  void playRingtone() async {
    await _audioPlayer.play(AssetSource('ringtone.mp3'), volume: 1.0);
  }

  void stopRingtone() {
    _audioPlayer.stop();
  }
}
