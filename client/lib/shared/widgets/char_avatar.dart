import 'package:flutter/material.dart';
import 'package:weather_friend/app/theme/design_tokens.dart';
import 'package:weather_friend/features/character/domain/character.dart';

enum CharAvatarVariant { plain, photo }

class CharAvatar extends StatelessWidget {
  const CharAvatar({
    required this.charId,
    this.size = 48,
    this.variant = CharAvatarVariant.plain,
    this.ring = false,
    super.key,
  });

  final CharacterId charId;
  final double size;
  final CharAvatarVariant variant;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final v = visualFor(charId);
    final character = Character.byId(charId);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: variant == CharAvatarVariant.photo
            ? null
            : RadialGradient(
                center: const Alignment(-0.3, -0.4),
                colors: [v.colorSoft, v.color],
              ),
        color: variant == CharAvatarVariant.photo ? v.color : null,
        boxShadow: ring
            ? [
                BoxShadow(
                  color: const Color(0xFFFFFFFF).withValues(alpha: 0.7),
                  spreadRadius: 3,
                ),
                BoxShadow(color: v.color, spreadRadius: 4),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: variant == CharAvatarVariant.photo
          ? _PhotoPlaceholder(charName: character.displayName.split(' ').last, v: v, size: size)
          : Center(
              child: Text(
                v.initial,
                style: TextStyle(
                  color: v.colorDeep,
                  fontWeight: FontWeight.w700,
                  fontSize: size * 0.42,
                  height: 1.0,
                  letterSpacing: -0.5,
                ),
              ),
            ),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({
    required this.charName,
    required this.v,
    required this.size,
  });

  final String charName;
  final CharVisual v;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: _StripesPainter(soft: v.colorSoft, base: v.color)),
        Center(
          child: Text(
            charName,
            style: TextStyle(
              fontFamily: 'ui-monospace',
              fontSize: size * 0.18,
              fontWeight: FontWeight.w500,
              color: v.colorDeep.withValues(alpha: 0.85),
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _StripesPainter extends CustomPainter {
  _StripesPainter({required this.soft, required this.base});

  final Color soft;
  final Color base;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final stripeW = 6.0;
    final diag = size.width + size.height;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(135 * 3.14159 / 180);
    canvas.translate(-size.width / 2, -size.height / 2);
    for (var x = -diag; x < diag; x += stripeW * 2) {
      paint.color = soft;
      canvas.drawRect(Rect.fromLTWH(x, -diag, stripeW, diag * 3), paint);
      paint.color = base;
      canvas.drawRect(
        Rect.fromLTWH(x + stripeW, -diag, stripeW, diag * 3),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StripesPainter oldDelegate) =>
      oldDelegate.soft != soft || oldDelegate.base != base;
}
