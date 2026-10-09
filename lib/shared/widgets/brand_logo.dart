import 'package:flutter/material.dart';

/// Logo de la marca dentro de la app (assets/logo.png).
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.height = 40, this.whiteBox = true});

  final double height;
  final bool whiteBox;

  @override
  Widget build(BuildContext context) {
    final logo = Image.asset(
      'assets/logo.png',
      height: height,
      fit: BoxFit.contain,
    );
    if (!whiteBox) return logo;
    final radius = (height * 0.18).clamp(4.0, 12.0);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
      padding: const EdgeInsets.all(4),
      child: logo,
    );
  }
}