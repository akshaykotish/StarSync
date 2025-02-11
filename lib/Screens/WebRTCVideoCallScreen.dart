// lib/Screens/WebRTCVideoCallScreen.dart
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class WebRTCVideoCallScreen extends StatefulWidget {
  final String roomId;
  final String astrologerId;
  final String userId;

  const WebRTCVideoCallScreen({
    Key? key,
    required this.roomId,
    required this.astrologerId,
    required this.userId,
  }) : super(key: key);

  @override
  State<WebRTCVideoCallScreen> createState() => _WebRTCVideoCallScreenState();
}

class _WebRTCVideoCallScreenState extends State<WebRTCVideoCallScreen> {
  InAppWebViewController? _webViewController;
  late final WebUri _initialUrl;

  @override
  void initState() {
    super.initState();
    _initialUrl = WebUri(
      "https://starsyncvc-1085028424107.asia-south2.run.app/?roomname=${widget.roomId}",
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Call'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Optionally update call status before leaving the screen
            Navigator.pop(context);
          },
        ),
      ),
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: _initialUrl),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          mediaPlaybackRequiresUserGesture: false,
          allowFileAccessFromFileURLs: true,
          allowUniversalAccessFromFileURLs: true,
        ),
        onWebViewCreated: (controller) {
          _webViewController = controller;
        },
        androidOnPermissionRequest: (controller, origin, resources) async {
          return PermissionRequestResponse(
            resources: resources,
            action: PermissionRequestResponseAction.GRANT,
          );
        },
        onLoadError: (controller, url, code, message) {
          debugPrint("Failed to load: $url, error: $message");
        },
        onLoadHttpError: (controller, url, code, message) {
          debugPrint("HTTP error: $code for $url, message: $message");
        },
      ),
    );
  }
}
