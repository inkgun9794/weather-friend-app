import 'package:flutter/material.dart';
import 'package:weather_friend/app/theme/app_type.dart';
import 'package:weather_friend/app/theme/design_tokens.dart';

/// 기록 추가 방식 선택 결과.
enum ImageSourceChoice { gallery, camera, moodOnly }

/// 갤러리/카메라(+옵션: 기분만) 선택 바텀시트. 취소 시 null.
Future<ImageSourceChoice?> showImageSourceSheet(
  BuildContext context, {
  bool includeMoodOnly = false,
}) {
  return showModalBottomSheet<ImageSourceChoice>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.paper,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '오늘 기록 추가',
                  style: AppType.caption.copyWith(
                    color: AppColors.inkSoft,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              _SourceTile(
                icon: Icons.photo_library_rounded,
                label: '갤러리에서 선택',
                onTap: () => Navigator.pop(ctx, ImageSourceChoice.gallery),
              ),
              _SourceTile(
                icon: Icons.photo_camera_rounded,
                label: '카메라로 촬영',
                onTap: () => Navigator.pop(ctx, ImageSourceChoice.camera),
              ),
              if (includeMoodOnly)
                _SourceTile(
                  icon: Icons.wb_sunny_rounded,
                  label: '사진 없이 기분만 기록',
                  onTap: () => Navigator.pop(ctx, ImageSourceChoice.moodOnly),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    ),
  );
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: AppColors.ink, size: 22),
      title: Text(
        label,
        style: AppType.subhead.copyWith(color: AppColors.ink),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: AppColors.inkFaint),
    );
  }
}
