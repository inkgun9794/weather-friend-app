import 'package:flutter/painting.dart';

/// 타이포 스케일 — Pretendard 기준.
///
/// 코드에 흩어져 있던 fontSize 28종을 실사용 빈도 기준으로 묶은 단계.
/// 색은 담지 않는다(주변 텍스트색/테마를 상속) — 필요하면 `.copyWith(color: ...)`.
class AppType {
  AppType._();

  static const _f = 'Pretendard';

  /// 특대 수치·히어로 (기온 등 더 큰 값은 `.copyWith(fontSize: ...)`).
  static const hero =
      TextStyle(fontFamily: _f, fontSize: 40, height: 1.05, fontWeight: FontWeight.w800, letterSpacing: -0.6);

  /// 화면/카드 대표 제목.
  static const display =
      TextStyle(fontFamily: _f, fontSize: 28, height: 1.12, fontWeight: FontWeight.w800, letterSpacing: -0.4);
  static const titleLg =
      TextStyle(fontFamily: _f, fontSize: 22, height: 1.2, fontWeight: FontWeight.w800, letterSpacing: -0.3);
  static const title =
      TextStyle(fontFamily: _f, fontSize: 18, height: 1.25, fontWeight: FontWeight.w700, letterSpacing: -0.2);

  /// 섹션 헤더.
  static const headline =
      TextStyle(fontFamily: _f, fontSize: 16, height: 1.3, fontWeight: FontWeight.w800, letterSpacing: -0.2);
  static const subhead =
      TextStyle(fontFamily: _f, fontSize: 15, height: 1.35, fontWeight: FontWeight.w600, letterSpacing: -0.1);

  /// 본문.
  static const bodyLg =
      TextStyle(fontFamily: _f, fontSize: 14, height: 1.5, fontWeight: FontWeight.w500, letterSpacing: -0.1);

  /// 긴 본문(운세·대화 등 읽기 텍스트) — 여유 있는 행간.
  static const reading =
      TextStyle(fontFamily: _f, fontSize: 14, height: 1.6, fontWeight: FontWeight.w400, letterSpacing: -0.1);
  static const body =
      TextStyle(fontFamily: _f, fontSize: 13, height: 1.5, fontWeight: FontWeight.w500, letterSpacing: -0.1);
  static const caption =
      TextStyle(fontFamily: _f, fontSize: 12, height: 1.45, fontWeight: FontWeight.w500, letterSpacing: -0.1);

  /// 버튼·탭·강조 라벨 (작지만 굵게).
  static const label =
      TextStyle(fontFamily: _f, fontSize: 12, height: 1.3, fontWeight: FontWeight.w800, letterSpacing: -0.1);

  /// 메타·아주 작은 라벨.
  static const micro =
      TextStyle(fontFamily: _f, fontSize: 11, height: 1.3, fontWeight: FontWeight.w600, letterSpacing: -0.1);
  static const micro2 =
      TextStyle(fontFamily: _f, fontSize: 10, height: 1.3, fontWeight: FontWeight.w600, letterSpacing: -0.1);
}
