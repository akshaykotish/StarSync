import 'package:flutter/material.dart';

class BannerWidget extends StatefulWidget {
  final String imageUrl;
  final double height;
  final double width;

  const BannerWidget({
    Key? key,
    required this.imageUrl,
    this.height = 200.0,
    this.width = double.infinity,
  }) : super(key: key);

  @override
  State<BannerWidget> createState() => _BannerWidgetState();
}

class _BannerWidgetState extends State<BannerWidget> {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(16.0), // Proper margin
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.0), // Rounded borders
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2), // Shadow color
            spreadRadius: 2,
            blurRadius: 6,
            offset: Offset(0, 3), // Shadow position
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.0), // Apply rounded corners to the image
        child: Image.network(
          widget.imageUrl,
          height: widget.height,
          width: widget.width,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
