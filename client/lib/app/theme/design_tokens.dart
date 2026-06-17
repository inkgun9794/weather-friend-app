import 'package:flutter/painting.dart';
import 'package:weather_friend/core/utils/oklch.dart';
import 'package:weather_friend/features/character/domain/character.dart';

class AppColors {
  AppColors._();

  static final ink = oklch(0.22, 0.018, 250);
  static final inkSoft = oklch(0.38, 0.014, 250);
  static final inkMute = oklch(0.58, 0.014, 250);
  static final inkFaint = oklch(0.74, 0.010, 250);
  static final paper = oklch(0.985, 0.004, 95);
  static final paper2 = oklch(0.965, 0.006, 95);
  static final paper3 = oklch(0.93, 0.008, 95);
  static final line = oklch(0.88, 0.008, 95);
  static final hairline = oklch(0.92, 0.006, 95);
  static final fortuneAccent = oklch(0.82, 0.13, 70);

  /// 비 소식 강조용 옅은 하늘색 (옷추천 우산 타일 등).
  static const rainTint = Color(0xFFE4EFFC);
}

class CharVisual {
  const CharVisual({
    required this.color,
    required this.colorDeep,
    required this.colorSoft,
  });

  final Color color;
  final Color colorDeep;
  final Color colorSoft;
}

final _charVisuals = <CharacterId, CharVisual>{
  CharacterId.jiyoung: CharVisual(
    color: oklch(0.74, 0.13, 30),
    colorDeep: oklch(0.54, 0.14, 30),
    colorSoft: oklch(0.94, 0.04, 30),
  ),
  CharacterId.sohee: CharVisual(
    color: oklch(0.62, 0.10, 330),
    colorDeep: oklch(0.42, 0.12, 330),
    colorSoft: oklch(0.94, 0.03, 330),
  ),
  CharacterId.jihoon: CharVisual(
    color: oklch(0.55, 0.11, 240),
    colorDeep: oklch(0.38, 0.12, 240),
    colorSoft: oklch(0.94, 0.03, 240),
  ),
  CharacterId.siwon: CharVisual(
    color: oklch(0.78, 0.14, 135),
    colorDeep: oklch(0.56, 0.16, 135),
    colorSoft: oklch(0.95, 0.05, 135),
  ),
};

CharVisual visualFor(CharacterId id) => _charVisuals[id]!;

enum SkyPaletteKey { dawn, day, dusk, night }

class SkyPalette {
  const SkyPalette({
    required this.top,
    required this.mid,
    required this.bot,
    required this.sun,
    required this.ink,
    required this.inkSoft,
    required this.label,
  });

  final Color top;
  final Color mid;
  final Color bot;
  final Color sun;
  final Color ink;
  final Color inkSoft;
  final String label;
}

final _skies = <SkyPaletteKey, SkyPalette>{
  SkyPaletteKey.dawn: SkyPalette(
    top: oklch(0.78, 0.10, 30),
    mid: oklch(0.86, 0.08, 70),
    bot: oklch(0.93, 0.05, 90),
    sun: oklch(0.86, 0.12, 70),
    ink: oklch(0.28, 0.04, 30),
    inkSoft: oklch(0.42, 0.03, 30),
    label: '아침 햇살',
  ),
  SkyPaletteKey.day: SkyPalette(
    top: oklch(0.74, 0.10, 235),
    mid: oklch(0.85, 0.06, 220),
    bot: oklch(0.94, 0.03, 220),
    sun: oklch(0.92, 0.10, 90),
    ink: oklch(0.24, 0.04, 240),
    inkSoft: oklch(0.42, 0.03, 240),
    label: '맑은 한낮',
  ),
  SkyPaletteKey.dusk: SkyPalette(
    top: oklch(0.55, 0.14, 25),
    mid: oklch(0.62, 0.13, 350),
    bot: oklch(0.50, 0.13, 300),
    sun: oklch(0.78, 0.14, 50),
    ink: oklch(0.95, 0.02, 30),
    inkSoft: oklch(0.82, 0.03, 30),
    label: '저무는 하늘',
  ),
  SkyPaletteKey.night: SkyPalette(
    top: oklch(0.22, 0.08, 265),
    mid: oklch(0.28, 0.08, 280),
    bot: oklch(0.18, 0.06, 270),
    sun: oklch(0.78, 0.05, 260),
    ink: oklch(0.96, 0.01, 260),
    inkSoft: oklch(0.78, 0.02, 260),
    label: '깊은 밤',
  ),
};

SkyPaletteKey paletteKeyForHour(int hour) {
  if (hour >= 4 && hour < 8) return SkyPaletteKey.dawn;
  if (hour >= 8 && hour < 17) return SkyPaletteKey.day;
  if (hour >= 17 && hour < 21) return SkyPaletteKey.dusk;
  return SkyPaletteKey.night;
}

SkyPalette skyFor(int hour) => _skies[paletteKeyForHour(hour)]!;
