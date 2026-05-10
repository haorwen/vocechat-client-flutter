/// Replace unpaired UTF-16 surrogates with U+FFFD so TextPainter
/// (which calls `_NativeParagraphBuilder.addText`) doesn't throw
/// "string is not well-formed UTF-16" on malformed input from the wire.
String safeText(String? input) {
  if (input == null || input.isEmpty) return input ?? '';
  final units = input.codeUnits;
  final out = StringBuffer();
  for (var i = 0; i < units.length; i++) {
    final unit = units[i];
    if (unit >= 0xD800 && unit <= 0xDBFF) {
      // High surrogate — must be followed by a low surrogate.
      if (i + 1 < units.length) {
        final next = units[i + 1];
        if (next >= 0xDC00 && next <= 0xDFFF) {
          out.writeCharCode(unit);
          out.writeCharCode(next);
          i++;
          continue;
        }
      }
      out.writeCharCode(0xFFFD);
    } else if (unit >= 0xDC00 && unit <= 0xDFFF) {
      // Stray low surrogate.
      out.writeCharCode(0xFFFD);
    } else {
      out.writeCharCode(unit);
    }
  }
  return out.toString();
}
