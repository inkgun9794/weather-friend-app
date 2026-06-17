/// 간격 토큰 — 4pt 그리드.
///
/// 코드에 흩어져 있던 간격 22종을 정리한 단계. off-grid 값(6·10·14 등)은
/// 마이그레이션 때 가까운 단계로 수렴시킨다.
class AppSpace {
  AppSpace._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}

/// 모서리 반경 토큰.
///
/// 코드에 흩어져 있던 반경 18종을 정리한 단계 (16/17/18, 20/22/24 등 미세 중복 통합).
class AppRadius {
  AppRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double pill = 999;
}
