import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Avatar del perfil local. [base64Image] se guarda en las preferencias, así
/// que si está vacío o corrupto se muestra la inicial del nombre.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.base64Image,
    this.name = '',
    this.size = 44,
  });

  final String base64Image;
  final String name;
  final double size;

  Uint8List? get _bytes {
    if (base64Image.isEmpty) return null;
    try {
      return base64Decode(base64Image);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bytes = _bytes;
    final trimmed = name.trim();
    final initial = trimmed.isEmpty
        ? null
        : trimmed.substring(0, 1).toUpperCase();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scheme.primary.withValues(alpha: 0.18),
        image: bytes == null
            ? null
            : DecorationImage(image: MemoryImage(bytes), fit: BoxFit.cover),
      ),
      alignment: Alignment.center,
      child: bytes != null
          ? null
          : initial == null
          ? Icon(Icons.person_outline, size: size * 0.55, color: scheme.primary)
          : Text(
              initial,
              style: TextStyle(
                fontSize: size * 0.4,
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
    );
  }
}
