// lib/components/zigzag_clipper.dart
import 'package:flutter/material.dart';

class ZigzagClipper extends CustomClipper<Path> {
  final double zigzagHeight;
  final int zigzags;
  final bool invert;

  const ZigzagClipper({
    this.zigzagHeight = 6.0,
    this.zigzags = 15,
    this.invert = false,
  });

  @override
  Path getClip(Size size) {
    final path = Path();
    final double zigzagWidth = size.width / zigzags;

    if (invert) {
      path.moveTo(0, size.height);
      for (int i = 0; i <= zigzags; i++) {
        final double x = i * zigzagWidth;
        final double y =
            (i % 2 == 0) ? (size.height - zigzagHeight) : size.height;
        path.lineTo(x, y);
      }
      path.lineTo(size.width, 0);
      path.lineTo(0, 0);
    } else {
      path.moveTo(0, zigzagHeight);
      for (int i = 0; i <= zigzags; i++) {
        final double x = i * zigzagWidth;
        final double y = (i % 2 == 0) ? 0.0 : zigzagHeight;
        path.lineTo(x, y);
      }
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
    }

    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
