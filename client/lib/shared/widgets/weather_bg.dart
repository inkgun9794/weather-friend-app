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
    // 흐림/강수면 하늘 전체를 회색 쪽으로 가라앉힌다 — 구름 낀 확산광 느낌.
    final overcast = condition != WeatherCondition.clear;
    Color tone(Color c) =>
        overcast ? Color.lerp(c, const Color(0xFF8E99A4), 0.30)! : c;

    // 정적 배경(그라디언트 + 색 번짐 + 비네트)을 RepaintBoundary 안에 격리.
    // 위에 올라가는 스크롤 콘텐츠가 매 프레임 갱신돼도 배경은 캐시된 레이어로
    // 재사용되므로, BackdropFilter가 샘플링하는 비용이 일정하게 유지된다.
    //
    // 천체(태양/달 구체)와 헤이즈 밴드는 의도적으로 없다 — 작은 구체는
    // 글래스 카드가 그 위를 지날 때만 frost가 보여서 스크롤 위치에 따라
    // blur가 꺼진 것처럼 보이는 비일관성을 만들었다. 대신 화면 전체에
    // 걸친 넓은 색 번짐(atmosphere wash)으로 어디서나 균일한 톤을 깐다.
    final background = RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [tone(sky.top), tone(sky.mid), tone(sky.bot)],
            stops: const [0.0, 0.45, 1.0],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _AtmospherePainter(sky: sky, overcast: overcast),
              ),
            ),
            const _Vignette(),
          ],
        ),
      ),
    );
    final hasPrecipitation =
        condition == WeatherCondition.rain ||
        condition == WeatherCondition.snow;
    return Stack(
      children: [
        Positioned.fill(child: background),
        // 비/눈은 매 프레임 repaint라 정적 배경 캐시 밖의 자체 레이어에 격리.
        // (위 BackdropFilter들은 강수 동안 매 프레임 재샘플링하게 되지만,
        // grouped blur 1패스 비용이라 강수 시에만 감수한다.)
        if (hasPrecipitation)
          Positioned.fill(
            child: RepaintBoundary(
              child: PrecipitationLayer(condition: condition),
            ),
          ),
        if (child != null) Positioned.fill(child: child!),
      ],
    );
  }
}

/// 화면을 넓게 덮는 부드러운 색 번짐 — 천체 구체 대신 쓰는 추상적 광원.
/// BlendMode.plus(가산 혼합)라 빛이 "섞여 탁해지지" 않고 "더해져 밝아진다".
/// (예: 낮 하늘의 노란 햇살이 파란 배경과 섞여 녹색이 되는 문제 방지)
class _AtmospherePainter extends CustomPainter {
  const _AtmospherePainter({required this.sky, required this.overcast});

  final SkyPalette sky;
  final bool overcast;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    void wash(Color color, Alignment center, double radius, double alpha) {
      final paint = Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          center: center,
          radius: radius,
          colors: [
            color.withValues(alpha: alpha),
            color.withValues(alpha: 0),
          ],
        ).createShader(rect);
      canvas.drawRect(rect, paint);
    }

    // 흐리면 광원이 구름에 가려 약해진다.
    final dim = overcast ? 0.45 : 1.0;
    // 상단의 큰 빛 — 시간대 광원(sun 컬러)을 형태 없이 넓게.
    wash(sky.sun, const Alignment(0.9, -0.95), 1.25, 0.4 * dim);
    // 중단 반대편의 은은한 깊이감.
    wash(sky.top, const Alignment(-1.1, 0.1), 1.0, 0.14);
    // 하단에도 옅은 빛 반사 — 스크롤 끝까지 톤이 이어진다.
    wash(sky.sun, const Alignment(-0.7, 1.1), 1.0, 0.16 * dim);
  }

  @override
  bool shouldRepaint(_AtmospherePainter oldDelegate) =>
      oldDelegate.sky != sky || oldDelegate.overcast != overcast;
}

/// 떨어지는 비/눈 파티클 레이어.
/// - 루프당 낙하 횟수를 정수로 맞춰 repeat 이음새가 보이지 않는다.
/// - 깊이(z)에 따라 길이/속도/굵기/투명도를 달리해 원근감을 준다.
/// - 모션 최소화(접근성) 설정이면 기존 정적 표현으로 폴백.
class PrecipitationLayer extends StatefulWidget {
  const PrecipitationLayer({required this.condition, super.key});

  final WeatherCondition condition;

  @override
  State<PrecipitationLayer> createState() => _PrecipitationLayerState();
}

class _PrecipitationLayerState extends State<PrecipitationLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _loopDuration(widget.condition),
  );

  static Duration _loopDuration(WeatherCondition condition) {
    // 빗줄기는 루프당 3~6회 낙하(0.7~1.3초/회), 눈은 1~2회(5~10초/회).
    return condition == WeatherCondition.snow
        ? const Duration(seconds: 10)
        : const Duration(seconds: 4);
  }

  @override
  void didUpdateWidget(PrecipitationLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.condition != widget.condition) {
      _controller
        ..stop()
        ..duration = _loopDuration(widget.condition);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSnow = widget.condition == WeatherCondition.snow;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      return IgnorePointer(
        child: Opacity(
          opacity: 0.35,
          child: CustomPaint(
            key: Key(isSnow ? 'static-snow' : 'static-rain'),
            size: Size.infinite,
            painter: isSnow ? _StaticSnowPainter() : _StaticRainPainter(),
          ),
        ),
      );
    }
    if (!_controller.isAnimating) _controller.repeat();
    return IgnorePointer(
      child: CustomPaint(
        key: Key(isSnow ? 'snow-anim' : 'rain-anim'),
        size: Size.infinite,
        painter: isSnow
            ? _SnowFallPainter(t: _controller)
            : _RainFallPainter(t: _controller),
      ),
    );
  }
}

/// 파티클 한 개 — 모든 값은 화면 크기 무관한 정규화 좌표.
class _Particle {
  const _Particle({
    required this.x,
    required this.y,
    required this.z,
    required this.fallsPerLoop,
    required this.swayPhase,
    required this.swayCycles,
  });

  final double x; // 0..1 가로 스폰 위치
  final double y; // 0..1 초기 낙하 위상
  final double z; // 0..1 깊이 (1 = 가장 가까움)
  final int fallsPerLoop; // 루프당 화면 통과 횟수 — 정수여야 루프가 이어진다
  final double swayPhase; // 눈 좌우 흔들림 시작 위상
  final int swayCycles; // 루프당 흔들림 횟수 — 역시 정수
}

List<_Particle> _generateParticles(
  int count, {
  required int minFalls,
  required int maxFalls,
  required int seed,
}) {
  final rng = math.Random(seed);
  return List.generate(count, (_) {
    final z = 0.35 + rng.nextDouble() * 0.65;
    return _Particle(
      x: rng.nextDouble(),
      y: rng.nextDouble(),
      z: z,
      // 가까운 파티클일수록 빠르게 떨어진다.
      fallsPerLoop: (minFalls + (maxFalls - minFalls) * z).round(),
      swayPhase: rng.nextDouble(),
      swayCycles: 2 + rng.nextInt(2),
    );
  });
}

class _RainFallPainter extends CustomPainter {
  _RainFallPainter({required Animation<double> t})
      : _t = t,
        super(repaint: t);

  final Animation<double> _t;

  // 빗방울 진행 방향 기울기 (dx/dy) — 기존 정적 빗줄기와 동일한 좌하향.
  static const double _slant = -0.18;
  static final List<_Particle> _drops =
      _generateParticles(70, minFalls: 3, maxFalls: 6, seed: 42);

  @override
  void paint(Canvas canvas, Size size) {
    final t = _t.value;
    final paint = Paint()..strokeCap = StrokeCap.round;
    // 기울어져 내려가는 만큼 스폰 범위를 오른쪽으로 넓혀 화면 전체를 덮는다.
    final travel = size.height * 1.2;
    final driftBudget = _slant.abs() * travel;

    for (final drop in _drops) {
      final length = size.height * (0.03 + 0.035 * drop.z);
      final phase = (drop.y + t * drop.fallsPerLoop) % 1.0;
      final headY = phase * travel - size.height * 0.1;
      final headX =
          drop.x * (size.width + driftBudget) + _slant * phase * travel;
      paint
        ..color = const Color(0xFFFCFCFD)
            .withValues(alpha: 0.16 + 0.3 * drop.z)
        ..strokeWidth = 1.0 + 0.9 * drop.z;
      canvas.drawLine(
        Offset(headX, headY),
        Offset(headX - _slant * length, headY - length),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RainFallPainter oldDelegate) => false;
}

class _SnowFallPainter extends CustomPainter {
  _SnowFallPainter({required Animation<double> t})
      : _t = t,
        super(repaint: t);

  final Animation<double> _t;

  static final List<_Particle> _flakes =
      _generateParticles(54, minFalls: 1, maxFalls: 2, seed: 7);

  @override
  void paint(Canvas canvas, Size size) {
    final t = _t.value;
    final paint = Paint();
    final travel = size.height * 1.1;

    for (final flake in _flakes) {
      final phase = (flake.y + t * flake.fallsPerLoop) % 1.0;
      final y = phase * travel - size.height * 0.05;
      final sway = math.sin(
            (flake.swayPhase + t * flake.swayCycles) * 2 * math.pi,
          ) *
          (8 + 12 * flake.z);
      final x = flake.x * size.width + sway;
      paint.color =
          Colors.white.withValues(alpha: 0.35 + 0.45 * flake.z);
      canvas.drawCircle(Offset(x, y), 1.2 + 2.0 * flake.z, paint);
    }
  }

  @override
  bool shouldRepaint(_SnowFallPainter oldDelegate) => false;
}

/// 모션 최소화 폴백 — 예전의 고정 빗줄기 표현 그대로.
class _StaticRainPainter extends CustomPainter {
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
  bool shouldRepaint(_StaticRainPainter oldDelegate) => false;
}

/// 모션 최소화 폴백 — 고정 눈송이.
class _StaticSnowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    for (var i = 0; i < 24; i++) {
      final x = (i * 53) % size.width;
      final y = (i * 31) % size.height;
      canvas.drawCircle(
        Offset(x.toDouble(), y.toDouble()),
        1.5 + (i % 3),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_StaticSnowPainter oldDelegate) => false;
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
