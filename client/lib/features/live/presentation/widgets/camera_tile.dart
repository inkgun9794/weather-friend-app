import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:weather_friend/app/theme/app_dimens.dart';
import 'package:weather_friend/app/theme/app_type.dart';
import 'package:weather_friend/app/theme/design_tokens.dart';
import 'package:weather_friend/features/live/data/cctv_camera.dart';

/// 근처 카메라 목록의 한 줄 — 이름·거리. 탭하면 위 플레이어에 로드되고,
/// 선택된 항목은 강조된다.
class CameraTile extends StatelessWidget {
  const CameraTile({
    required this.camera,
    required this.center,
    required this.selected,
    required this.onTap,
    this.dead = false,
    super.key,
  });

  final CctvCamera camera;
  final LatLng center;
  final bool selected;
  final VoidCallback onTap;

  /// 재생 실패로 죽은 것으로 확인된 카메라 — 흐리게 + "응답없음" 표시.
  final bool dead;

  @override
  Widget build(BuildContext context) {
    final km = const Distance().as(
      LengthUnit.Kilometer,
      center,
      camera.location,
    );
    final distanceText = km < 1
        ? '${(km * 1000).round()}m'
        : '${km.toStringAsFixed(1)}km';

    final icon = dead
        ? Icons.videocam_off_rounded
        : (selected ? Icons.play_circle_rounded : Icons.videocam_rounded);
    final iconColor = dead
        ? AppColors.inkFaint
        : (selected ? AppColors.ink : AppColors.inkMute);

    return Opacity(
      opacity: dead ? 0.55 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.md,
              vertical: AppSpace.sm + 2,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: selected ? 0.66 : 0.34),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: selected
                    ? AppColors.ink.withValues(alpha: 0.45)
                    : Colors.white.withValues(alpha: 0.5),
                width: selected ? 1.2 : 0.6,
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: iconColor),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: Text(
                    _clean(camera.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.body.copyWith(
                      color: AppColors.ink,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                Text(
                  dead ? '응답없음' : distanceText,
                  style: AppType.micro.copyWith(
                    color: dead ? AppColors.inkFaint : AppColors.inkMute,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 이름의 과한 공백만 정리("[서울][강변북로]" 같은 접두 라벨은 유지).
  String _clean(String raw) => raw.replaceAll(RegExp(r'\s+'), ' ').trim();
}
