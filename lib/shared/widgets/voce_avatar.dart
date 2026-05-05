import 'package:flutter/material.dart';

/// A circular avatar that shows [imageUrl] if provided, otherwise falls back
/// to the first letter of [name] on a deterministic background color.
class VoceAvatar extends StatelessWidget {
  const VoceAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 40,
  });

  final String name;
  final String? imageUrl;
  final double size;

  static Color _colorFromName(String name) {
    const palette = [
      Color(0xFF6366F1),
      Color(0xFF8B5CF6),
      Color(0xFFEC4899),
      Color(0xFFEF4444),
      Color(0xFFF97316),
      Color(0xFF10B981),
      Color(0xFF06B6D4),
      Color(0xFF3B82F6),
    ];
    final hash = name.codeUnits.fold(0, (a, b) => a + b);
    return palette[hash % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final radius = size / 2;
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(imageUrl!),
        backgroundColor: _colorFromName(name),
      );
    }
    final letter = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final fontSize = size * 0.4;
    return CircleAvatar(
      radius: radius,
      backgroundColor: _colorFromName(name),
      child: Text(
        letter,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
