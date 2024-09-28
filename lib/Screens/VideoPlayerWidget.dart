import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';
import 'package:flutter/services.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;

  const VideoPlayerWidget({required this.videoUrl, Key? key}) : super(key: key);

  @override
  _VideoPlayerWidgetState createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;
  Future<void>? _initializeVideoPlayerFuture;
  bool _isControlsVisible = false;
  bool _isFullScreen = false;
  Timer? _hideControlsTimer;

  @override
  void initState() {
    super.initState();

    // Initialize the video player controller with audio enabled
    _controller = VideoPlayerController.network(widget.videoUrl);
    _initializeVideoPlayerFuture = _controller.initialize().then((_) {
      setState(() {});
      _controller.setVolume(1.0); // Set volume to maximum to ensure audio is enabled
    }).catchError((error) {
      print("Video player initialization error: $error");
    });

    // Add a listener to handle video player changes
    _controller.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _hideControlsTimer?.cancel();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
        _startHideControlsTimer();
      }
    });
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      setState(() {
        _isControlsVisible = false;
      });
    });
  }

  void _showControls() {
    setState(() {
      _isControlsVisible = true;
    });
    _startHideControlsTimer();
  }

  void _seekVideo(double value) {
    final position = Duration(seconds: value.toInt());
    _controller.seekTo(position);
  }

  void _toggleFullScreen() async {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });

    if (_isFullScreen) {
      // Switch to full-screen mode in landscape orientation
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => Scaffold(
            backgroundColor: Colors.black,
            body: Stack(
              alignment: Alignment.center,
              children: [
                GestureDetector(
                  onTap: _showControls,
                  child: AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  ),
                ),
                if (_isControlsVisible) _buildFullScreenControls(),
                Positioned(
                  top: 20,
                  left: 20,
                  child: IconButton(
                    icon: Icon(Icons.arrow_back, color: Colors.white, size: 30),
                    onPressed: () async {
                      // Exit full-screen mode and return to portrait
                      await _exitFullScreen();
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ).then((_) async {
        // Return to portrait mode when exiting full-screen
        await _exitFullScreen();
      });
    }
  }

  Future<void> _exitFullScreen() async {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    setState(() {
      _isFullScreen = false;
      _isControlsVisible = false;
    });
  }

  Widget _buildFullScreenControls() {
    return Container(
      color: Colors.black26, // Semi-transparent overlay to indicate controls are active
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(
              _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 50,
            ),
            onPressed: _togglePlayPause,
          ),
          Row(
            children: [
              Expanded(
                child: Slider(
                  min: 0.0,
                  max: _controller.value.duration.inSeconds.toDouble(),
                  value: _controller.value.position.inSeconds.toDouble().clamp(0.0, _controller.value.duration.inSeconds.toDouble()),
                  onChanged: (value) {
                    _seekVideo(value);
                  },
                ),
              ),
              IconButton(
                icon: Icon(
                  _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                  color: Colors.white,
                  size: 30,
                ),
                onPressed: () async {
                  // Exit full-screen mode
                  await _exitFullScreen();
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _showControls,
      child: Stack(
        alignment: Alignment.center,
        children: [
          FutureBuilder(
            future: _initializeVideoPlayerFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                return AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                );
              } else {
                return Container(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
            },
          ),
          if (_isControlsVisible) _buildControls(),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      color: Colors.black26, // Semi-transparent overlay to indicate controls are active
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(
              _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 50,
            ),
            onPressed: _togglePlayPause,
          ),
          Row(
            children: [
              Expanded(
                child: Slider(
                  min: 0.0,
                  max: _controller.value.duration.inSeconds.toDouble(),
                  value: _controller.value.position.inSeconds.toDouble().clamp(0.0, _controller.value.duration.inSeconds.toDouble()),
                  onChanged: (value) {
                    _seekVideo(value);
                  },
                ),
              ),
              IconButton(
                icon: Icon(
                  _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                  color: Colors.white,
                  size: 30,
                ),
                onPressed: _toggleFullScreen,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
