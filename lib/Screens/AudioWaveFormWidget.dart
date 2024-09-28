import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/material.dart';

class AudioWaveformWidget extends StatefulWidget {
  final String audioFilePath;
  final PlayerController controller; // Made controller `final`

  AudioWaveformWidget({
    required this.audioFilePath,
    required this.controller,
  });

  @override
  _AudioWaveformWidgetState createState() => _AudioWaveformWidgetState();
}

class _AudioWaveformWidgetState extends State<AudioWaveformWidget> {
  bool _isWaveformReady = true;

  @override
  void initState() {
    super.initState();
    _initializeWaveform();
  }

  Future<void> _initializeWaveform() async {
    try {
      await widget.controller.preparePlayer(
        path: widget.audioFilePath,
        shouldExtractWaveform: true,
      );
      setState(() {
        _isWaveformReady = true;
      });
    } catch (e) {
      print("Error initializing waveform: $e");
      // Optionally, show an error message to the user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load audio waveform.")),
      );
    }
  }

  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.0),
      child: _isWaveformReady
          ? AudioFileWaveforms(
        playerController: widget.controller,
        size: Size(MediaQuery.of(context).size.width/4.5, 50), // Increased height from 60 to 120
        playerWaveStyle: PlayerWaveStyle(
          fixedWaveColor: Colors.red,
          liveWaveColor: Colors.blueAccent,
          spacing: 8,
          waveThickness: 4, // Increased thickness from 2 to 4
          // Optional: Adjust other properties if needed
          // For example, you might want to adjust the gradient or background color
        ),
      )
          : Center(child: CircularProgressIndicator()),
    );
  }
}
