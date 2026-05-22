import 'dart:math' as math;
import 'dart:ui';

/// Convert CSS `oklch(L C H)` → Flutter [Color] in sRGB.
///
/// Spec reference: CSS Color Module Level 4 — Oklab → linear sRGB → sRGB.
/// - [l]: lightness 0..1
/// - [c]: chroma (typically 0..0.4)
/// - [h]: hue in degrees 0..360
/// - [alpha]: 0..1
Color oklch(double l, double c, double h, [double alpha = 1.0]) {
  final hRad = h * math.pi / 180.0;
  final a = c * math.cos(hRad);
  final b = c * math.sin(hRad);
  return _oklabToColor(l, a, b, alpha);
}

Color _oklabToColor(double l, double a, double b, double alpha) {
  // Oklab → LMS (cube)
  final l_ = l + 0.3963377774 * a + 0.2158037573 * b;
  final m_ = l - 0.1055613458 * a - 0.0638541728 * b;
  final s_ = l - 0.0894841775 * a - 1.2914855480 * b;

  final lc = l_ * l_ * l_;
  final mc = m_ * m_ * m_;
  final sc = s_ * s_ * s_;

  // LMS → linear sRGB
  final lr =  4.0767416621 * lc - 3.3077115913 * mc + 0.2309699292 * sc;
  final lg = -1.2684380046 * lc + 2.6097574011 * mc - 0.3413193965 * sc;
  final lb = -0.0041960863 * lc - 0.7034186147 * mc + 1.7076147010 * sc;

  return Color.fromARGB(
    (alpha.clamp(0.0, 1.0) * 255).round(),
    _toSrgb8(lr),
    _toSrgb8(lg),
    _toSrgb8(lb),
  );
}

int _toSrgb8(double linear) {
  final c = linear.clamp(0.0, 1.0);
  final v = c <= 0.0031308
      ? 12.92 * c
      : 1.055 * math.pow(c, 1.0 / 2.4) - 0.055;
  return (v * 255).round().clamp(0, 255);
}
