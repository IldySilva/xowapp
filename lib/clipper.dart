import 'package:flutter/material.dart';

class DeviceClipper extends CustomClipper<Rect> {
  final double top;
  final double bottom;
  final double left;
  final double right;

  DeviceClipper({
    required this.top,
    required this.bottom,
    required this.left,
    required this.right,
  });

  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(
      size.width * left,
      size.height * top,
      size.width * (1 - right),
      size.height * (1 - bottom),
    );
  }

  @override
  bool shouldReclip(DeviceClipper oldClipper) {
    return oldClipper.top != top ||
        oldClipper.bottom != bottom ||
        oldClipper.left != left ||
        oldClipper.right != right;
  }
}
