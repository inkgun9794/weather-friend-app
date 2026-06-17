import 'package:flutter/material.dart';
import 'package:weather_friend/app/theme/app_type.dart';
import 'package:weather_friend/app/theme/design_tokens.dart';

class AppTheme {
  AppTheme._();

  static const fontFamily = 'Pretendard';

  static const _seed = Color(0xFF7CB9E8);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    var colorScheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
    if (isLight) {
      // 디자인 토큰을 Material 색 역할에 연결 — 커스텀 위젯이 쓰는 ink/paper와
      // 기본 Material 컴포넌트의 색을 한 출처로 맞춘다.
      colorScheme = colorScheme.copyWith(
        surface: AppColors.paper,
        onSurface: AppColors.ink,
        onSurfaceVariant: AppColors.inkMute,
        outline: AppColors.line,
        outlineVariant: AppColors.hairline,
      );
    }
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: isLight ? AppColors.paper : colorScheme.surface,
      textTheme: _textTheme(colorScheme.onSurface),
    );
  }

  static TextTheme _textTheme(Color onSurface) {
    TextStyle t(TextStyle s) => s.copyWith(color: onSurface);
    return TextTheme(
      displayLarge: t(AppType.hero),
      displayMedium: t(AppType.display),
      headlineMedium: t(AppType.titleLg),
      titleLarge: t(AppType.title),
      titleMedium: t(AppType.headline),
      titleSmall: t(AppType.subhead),
      bodyLarge: t(AppType.bodyLg),
      bodyMedium: t(AppType.body),
      bodySmall: t(AppType.caption),
      labelLarge: t(AppType.label),
      labelMedium: t(AppType.micro),
      labelSmall: t(AppType.micro2),
    );
  }
}
