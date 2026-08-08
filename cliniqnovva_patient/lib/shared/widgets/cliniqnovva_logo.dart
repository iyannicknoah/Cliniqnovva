import 'package:flutter/material.dart';

/// The brand logo mark — same asset/usage convention as
/// cliniqnovva/lib/shared/widgets/cliniqnovva_logo.dart. Use this
/// everywhere the logo appears, never `Image.asset` a logo file directly.
class CliniqnovvaLogo extends StatelessWidget {
  const CliniqnovvaLogo({super.key, this.size = 24, this.radius = 8});

  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset(
        'assets/images/logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}
