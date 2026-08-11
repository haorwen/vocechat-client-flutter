import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// A circular avatar that shows [imageUrl] if provided, otherwise falls back
/// to the first character of [name] on a deterministic background color.
///
/// Uses [CachedNetworkImage] so the same avatar isn't re-downloaded on every
/// rebuild / scroll / screen-transition. When the image has transparent
/// regions (PNG / WebP), they render as TRUE transparency over the parent
/// surface — no colored disc bleeds through behind alpha pixels.
class VoceAvatar extends StatelessWidget {
  const VoceAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 40,
    this.cacheImage = true,
  });

  final String name;
  final String? imageUrl;
  final double size;

  /// Disabled for ephemeral archive attachments that must not persist on disk.
  final bool cacheImage;

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
    // Hash by Unicode runes, not UTF-16 code units, so emoji-only names map
    // to a stable color (and to the same color across UTF-16 surrogate halves).
    final hash = name.runes.fold<int>(0, (a, b) => a + b);
    return palette[hash.abs() % palette.length];
  }

  /// First grapheme of [name] — preserves emoji and other multi-codepoint
  /// glyphs intact instead of slicing them across UTF-16 code units (which
  /// `name[0]` would do, producing a tofu replacement char).
  static String _firstGlyph(String name) {
    if (name.isEmpty) return '?';
    final runes = name.runes;
    if (runes.isEmpty) return '?';
    final first = runes.first;
    final ch = String.fromCharCode(first);
    // Letters get uppercased; emoji / symbols don't (uppercasing is a no-op
    // for them but the conditional keeps intent explicit).
    return ch.toUpperCase();
  }

  Widget _initials() {
    final letter = _firstGlyph(name);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _colorFromName(name),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.4,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _initials();
    }
    // ClipOval over the image keeps real transparency intact.
    // We deliberately do NOT set a backgroundColor on the clipped area,
    // so transparent PNGs let the surface behind show through.
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: cacheImage
            ? CachedNetworkImage(
                imageUrl: imageUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 120),
                fadeOutDuration: Duration.zero,
                placeholder: (_, __) => _initials(),
                errorWidget: (_, __, ___) => _initials(),
              )
            : Image.network(
                imageUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : _initials(),
                errorBuilder: (_, __, ___) => _initials(),
              ),
      ),
    );
  }
}
