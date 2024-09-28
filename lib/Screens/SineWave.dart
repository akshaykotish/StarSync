import 'dart:math';
import 'package:flutter/material.dart';


class SineWaveWidget extends StatefulWidget {

  bool isPlaying;
  SineWaveWidget({required this.isPlaying});

  @override
  _SineWaveWidgetState createState() => _SineWaveWidgetState();
}

class _SineWaveWidgetState extends State<SineWaveWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    ); // Loop the animation

    _animation = Tween<double>(begin: 0, end: 2 * pi).animate(_controller);
    if (widget.isPlaying) {
      _controller.repeat(); // Start repeating if playing
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      height: 40,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return CustomPaint(
            painter: AudioWavePainter(_animation.value),
          );
        },
      ),
    );
  }
}


class SineWavePainter extends CustomPainter {
  final double offset;

  SineWavePainter(this.offset);

  @override
  void paint(Canvas canvas, Size size) {
    // List of colors for the sine waves
    final List<Color> colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.yellow,
    ];

    // List of vertical offsets for each sine wave
    final List<double> verticalOffsets = [
      0.0,   // Center wave
      10.0,  // Slightly above center
      -10.0, // Slightly below center
      5.0,   // A bit above center
      -5.0,  // A bit below center
      0.0,   // Center wave for more intersection
    ];

    // All waves start from -20 on the x-axis
    final double startX = 0.0;

    // Draw each sine wave
    for (int i = 0; i < 1; i++) {
      final paint = Paint()
        ..color = Colors.black38
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      final path = Path();
      path.moveTo(startX, (size.height / 2) + verticalOffsets[i]); // Adjust initial x and y position

      double y_u = 0;
      bool signpos = true;
      var random = Random();
      int rand = random.nextInt(5);
      // Draw the sine wave
      for (double x = 0; x <= size.width; x++) {
         double y = (size.height / 2) + verticalOffsets[i] + (size.height / 4) * sin((x / size.width) * (2 * pi) + offset + (i * pi / 10)); // Adjust the phase shift for intersection
        path.lineTo(x, y); // Adjust x position for sine wave

      }

      // Draw the path on the canvas
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; // Repaint whenever the offset changes
  }
}


class AudioWavePainter extends CustomPainter {
  final double offset;

  AudioWavePainter(this.offset);

  @override
  void paint(Canvas canvas, Size size) {
    // Define colors for the waves (black and white theme)
    final List<Color> colors = [
      Colors.black,
      Colors.grey, // Slightly lighter for variation
      Colors.white,
      Colors.black.withOpacity(0.5), // Semi-transparent black
      Colors.grey.withOpacity(0.5),  // Semi-transparent grey
      Colors.white.withOpacity(0.5), // Semi-transparent white
    ];

    // Draw each wave
    for (int i = 0; i < colors.length; i++) {
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 + (i * 0.5); // Vary the stroke width for effect

      final path = Path();
      path.moveTo(0, size.height / 2); // Start from the center

      // Draw the wave
      for (double x = 0; x <= size.width; x++) {
        double frequency = 2 + (i * 0.5); // Vary frequency
        double amplitude = (size.height / 4) + (i * 2); // Vary amplitude
        double y = (size.height / 2) + amplitude * sin((x / size.width) * (2 * pi * frequency) + offset);
        path.lineTo(x, y);
      }

      // Draw the path on the canvas
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; // Repaint whenever the offset changes
  }
}