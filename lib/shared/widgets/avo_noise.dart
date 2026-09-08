import 'dart:math' as math;

/// p5's seeded random generator (also used by noiseSeed).
class AvoRandom {
  AvoRandom(int seed) : _state = seed & 0xffffffff;
  int _state;

  double nextDouble() {
    _state = (_state * 1664525 + 1013904223) & 0xffffffff;
    return _state / 4294967296;
  }
}

/// The four-octave, cosine-interpolated noise used by p5.noise.
///
/// A fixed table makes the same avatar coherent across native and web clients.
/// The reference chooses a random table per p5 instance; its algorithm, spatial
/// frequency and amplitude are retained, without substituting radial sine lobes.
class AvoNoise {
  AvoNoise(int seed) {
    final random = AvoRandom(seed);
    _table = List<double>.generate(4096, (_) => random.nextDouble());
  }

  late final List<double> _table;
  static double _cosine(double t) => .5 * (1 - math.cos(t * math.pi));

  double sample(double x, double y, double z) {
    x = x.abs();
    y = y.abs();
    z = z.abs();
    var xi = x.floor();
    var yi = y.floor();
    var zi = z.floor();
    var xf = x - xi;
    var yf = y - yi;
    var zf = z - zi;
    var result = 0.0;
    var amplitude = .5;
    for (var octave = 0; octave < 4; octave++) {
      var offset = xi + (yi << 4) + (zi << 8);
      final rx = _cosine(xf);
      final ry = _cosine(yf);
      var n1 = _table[offset & 4095];
      n1 += rx * (_table[(offset + 1) & 4095] - n1);
      var n2 = _table[(offset + 16) & 4095];
      n2 += rx * (_table[(offset + 17) & 4095] - n2);
      n1 += ry * (n2 - n1);
      offset += 256;
      n2 = _table[offset & 4095];
      n2 += rx * (_table[(offset + 1) & 4095] - n2);
      var n3 = _table[(offset + 16) & 4095];
      n3 += rx * (_table[(offset + 17) & 4095] - n3);
      n2 += ry * (n3 - n2);
      n1 += _cosine(zf) * (n2 - n1);
      result += n1 * amplitude;
      amplitude *= .5;
      xi <<= 1;
      yi <<= 1;
      zi <<= 1;
      xf *= 2;
      yf *= 2;
      zf *= 2;
      if (xf >= 1) {
        xi++;
        xf--;
      }
      if (yf >= 1) {
        yi++;
        yf--;
      }
      if (zf >= 1) {
        zi++;
        zf--;
      }
    }
    return result;
  }
}
