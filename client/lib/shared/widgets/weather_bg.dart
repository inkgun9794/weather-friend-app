import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:weather_friend/app/theme/design_tokens.dart';

enum WeatherCondition { clear, cloudy, rain, snow }

class WeatherBg extends StatelessWidget {
  const WeatherBg({
    required this.hour,
    this.condition = WeatherCondition.clear,
    this.child,
    super.key,
  });

  final int hour;
  final WeatherCondition condition;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final sky = skyFor(hour);
    final isNight = hour >= 21 || hour < 5;

    Offset? pos;
    if (isNight) {
      pos = const Offset(70, 18);
    } else if (hour >= 5 && hour <= 21) {
      final t = (hour - 5) / 16.0;
      pos = Offset(12 + t * 76, 70 - math.sin(t * math.pi) * 60);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        const bodySize = 88.0;
        // 정적 배경(그라디언트 + 천체 + 컨디션 레이어 + 비네트)을 RepaintBoundary
        // 안에 격리. 위에 올라가는 스크롤 콘텐츠가 매 프레임 갱신돼도 배경은
        // 캐시된 레이어로 재사용되므로, BackdropFilter가 샘플링하는 비용이
        // 일정하게 유지된다.
        final background = RepaintBoundary(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [sky.top, sky.mid, sky.bot],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
            child: Stack(
              children: [
                if (pos != null)
                  Positioned(
                    left: w * pos.dx / 100 - bodySize / 2,
                    top: h * pos.dy / 100 - bodySize / 2,
                    child: _CelestialBody(sky: sky, isNight: isNight),
                  ),
                if (condition != WeatherCondition.clear) const _HazeBand(),
                if (condition == WeatherCondition.rain) const _RainStreaks(),
                const _Vignette(),
              ],
            ),
          ),
        );
        return Stack(
          children: [
            Positioned.fill(child: background),
            if (child != null) Positioned.fill(child: child!),
          ],
        );
      },
    );
  }
}

class _CelestialBody extends StatelessWidget {
  const _CelestialBody({required this.sky, required this.isNight});

  final SkyPalette sky;
  final bool isNight;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      height: 88,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.3, -0.3),
            radius: 0.7,
            colors: isNight
                ? [
                    const Color(0xFFF6F4F2),
                    sky.sun.withValues(alpha: 0.6),
                    Colors.transparent,
                  ]
                : [sky.sun, sky.sun.withValues(alpha: 0.0)],
            stops: isNight ? const [0.0, 0.6, 0.7] : const [0.0, 0.7],
          ),
        ),
      ),
    );
  }
}

class _HazeBand extends StatelessWidget {
  const _HazeBand();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Align(
        alignment: const Alignment(0, -0.4),
        child: FractionallySizedBox(
          widthFactor: 1,
          child: SizedBox(
            height: 80,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.4, 0),
                  radius: 0.6,
                  colors: [
                    const Color(0xFFFFFFFF).withValues(alpha: 0.5),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RainStreaks extends StatelessWidget {
  const _RainStreaks();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Opacity(
        opacity: 0.35,
        child: CustomPaint(painter: _RainPainter()),
      ),
    );
  }
}

class _RainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFCFCFD)
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 28; i++) {
      final x1 = (i * 37) % size.width;
      final y1 = (i * 23) % size.height;
      canvas.drawLine(
        Offset(x1.toDouble(), y1.toDouble()),
        Offset(x1 - 6, y1 + 28),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RainPainter oldDelegate) => false;
}

class _Vignette extends StatelessWidget {
  const _Vignette();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, 1.2),
              radius: 1.0,
              colors: [
                Colors.black.withValues(alpha: 0.18),
                Colors.transparent,
              ],
              stops: const [0.0, 0.6],
            ),
          ),
        ),
      ),
    );
  }
}
