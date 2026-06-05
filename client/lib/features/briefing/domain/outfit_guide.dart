class OutfitOption {
  const OutfitOption({
    required this.theme,
    required this.combination,
    required this.assetPath,
  });

  final String theme;
  final String combination;
  final String assetPath;
}

class OutfitGuide {
  const OutfitGuide({
    required this.key,
    required this.minTemp,
    required this.maxTemp,
    required this.title,
    required this.message,
    required this.options,
  });

  final String key;
  final int? minTemp;
  final int? maxTemp;
  final String title;
  final String message;
  final List<OutfitOption> options;

  String get temperatureLabel {
    if (minTemp == null) return '체감 ${maxTemp!}° 이하';
    if (maxTemp == null) return '체감 $minTemp° 이상';
    return '체감 $minTemp°~$maxTemp°';
  }

  bool contains(int temperature) {
    final aboveMin = minTemp == null || temperature >= minTemp!;
    final belowMax = maxTemp == null || temperature <= maxTemp!;
    return aboveMin && belowMax;
  }

  OutfitOption recommendationFor(String seed) {
    return options[_stableHash('$key|$seed') % options.length];
  }
}

OutfitGuide outfitGuideFor(int feelsLikeTemp) {
  return outfitGuides.firstWhere((guide) => guide.contains(feelsLikeTemp));
}

int _stableHash(String value) {
  var hash = 0;
  for (final codeUnit in value.codeUnits) {
    hash = ((hash * 31) + codeUnit) & 0x7fffffff;
  }
  return hash;
}

const outfitGuides = <OutfitGuide>[
  OutfitGuide(
    key: 'minus5',
    minTemp: null,
    maxTemp: -5,
    title: '완전 한겨울',
    message: '체감온도가 매우 낮아요. 멋보다 보온이 먼저예요. 목도리와 장갑까지 챙겨주세요.',
    options: [
      OutfitOption(
        theme: '블랙 롱패딩 데일리',
        combination: '롱패딩 + 후드 니트 + 조거팬츠 + 머플러 + 방한 스니커즈',
        assetPath: 'assets/outfits/minus5/1.webp',
      ),
      OutfitOption(
        theme: '크림 퍼 코트 클래식',
        combination: '퍼 롱코트 + 목폴라 니트 + 니트 원피스 + 롱부츠 + 귀마개',
        assetPath: 'assets/outfits/minus5/2.webp',
      ),
      OutfitOption(
        theme: '모노톤 롱패딩 레이어드',
        combination: '롱패딩 + 두꺼운 니트 + 와이드팬츠 + 롱부츠 + 머플러',
        assetPath: 'assets/outfits/minus5/3.webp',
      ),
      OutfitOption(
        theme: '화이트 숏패딩 캐주얼',
        combination: '숏패딩 + 후드티 + 데님 + 목도리 + 장갑',
        assetPath: 'assets/outfits/minus5/4.webp',
      ),
    ],
  ),
  OutfitGuide(
    key: 'minus4_0',
    minTemp: -4,
    maxTemp: 0,
    title: '두꺼운 아우터 필수',
    message: '패딩이나 두꺼운 코트가 필요한 날이에요. 안쪽도 니트나 기모 소재로 따뜻하게 입어주세요.',
    options: [
      OutfitOption(
        theme: '아이보리 숏패딩 캐주얼',
        combination: '숏패딩 + 후드티 + 데님 + 머플러 + 스니커즈',
        assetPath: 'assets/outfits/minus4_0/1.webp',
      ),
      OutfitOption(
        theme: '다크 롱코트 클래식',
        combination: '울 롱코트 + 목폴라 + 크림 팬츠 + 로퍼 + 장갑',
        assetPath: 'assets/outfits/minus4_0/2.webp',
      ),
      OutfitOption(
        theme: '테디 재킷 스커트 룩',
        combination: '퍼 재킷 + 니트 + 롱스커트 + 롱부츠 + 머플러',
        assetPath: 'assets/outfits/minus4_0/3.webp',
      ),
      OutfitOption(
        theme: '브라운 무스탕 페미닌',
        combination: '무스탕 + 목폴라 + 니트 스커트 + 롱부츠 + 장갑',
        assetPath: 'assets/outfits/minus4_0/4.webp',
      ),
    ],
  ),
  OutfitGuide(
    key: '1_4',
    minTemp: 1,
    maxTemp: 4,
    title: '초겨울 옷차림',
    message: '아직은 꽤 추워요. 패딩이나 두꺼운 코트에 니트류를 함께 입는 게 좋아요.',
    options: [
      OutfitOption(
        theme: '블랙 코트 모던 룩',
        combination: '울코트 + 목폴라 + 크림 팬츠 + 롱부츠 + 머플러',
        assetPath: 'assets/outfits/1_4/1.webp',
      ),
      OutfitOption(
        theme: '아이보리 패딩 데님',
        combination: '숏패딩 + 후드 니트 + 데님 + 스니커즈 + 머플러',
        assetPath: 'assets/outfits/1_4/2.webp',
      ),
      OutfitOption(
        theme: '크림 재킷 스커트 룩',
        combination: '두꺼운 재킷 + 목폴라 + 롱스커트 + 롱부츠 + 머플러',
        assetPath: 'assets/outfits/1_4/3.webp',
      ),
      OutfitOption(
        theme: '브라운 무스탕 데님',
        combination: '무스탕 + 니트 + 와이드 데님 + 비니 + 스니커즈',
        assetPath: 'assets/outfits/1_4/4.webp',
      ),
    ],
  ),
  OutfitGuide(
    key: '5_8',
    minTemp: 5,
    maxTemp: 8,
    title: '코트가 안정적인 날',
    message: '쌀쌀한 날씨예요. 얇은 겉옷보다는 코트, 누빔 재킷이나 무스탕이 안정적이에요.',
    options: [
      OutfitOption(
        theme: '크림 재킷 클래식',
        combination: '울 재킷 + 니트 + 롱스커트 + 앵클부츠 + 머플러',
        assetPath: 'assets/outfits/5_8/1.webp',
      ),
      OutfitOption(
        theme: '카키 퀼팅 캐주얼',
        combination: '누빔 재킷 + 스트라이프 티 + 데님 + 스니커즈',
        assetPath: 'assets/outfits/5_8/2.webp',
      ),
      OutfitOption(
        theme: '토프 롱코트 데일리',
        combination: '롱코트 + 니트 + 데님 + 로퍼 + 머플러',
        assetPath: 'assets/outfits/5_8/3.webp',
      ),
      OutfitOption(
        theme: '브라운 무스탕 캐주얼',
        combination: '무스탕 + 니트 + 와이드 데님 + 비니 + 스니커즈',
        assetPath: 'assets/outfits/5_8/4.webp',
      ),
    ],
  ),
  OutfitGuide(
    key: '9_11',
    minTemp: 9,
    maxTemp: 11,
    title: '자켓을 걸칠 날',
    message: '가디건만 입기엔 살짝 쌀쌀해요. 자켓을 걸치거나 니트를 레이어드하면 좋아요.',
    options: [
      OutfitOption(
        theme: '네이비 니트 이지 룩',
        combination: '니트 + 긴팔 이너 + 조거팬츠 + 스니커즈',
        assetPath: 'assets/outfits/9_11/1.webp',
      ),
      OutfitOption(
        theme: '그레이 니트 스커트',
        combination: '니트 + 긴팔 이너 + 롱스커트 + 스니커즈',
        assetPath: 'assets/outfits/9_11/2.webp',
      ),
      OutfitOption(
        theme: '브라운 자켓 오피스',
        combination: '울자켓 + 얇은 니트 + 슬랙스 + 로퍼',
        assetPath: 'assets/outfits/9_11/3.webp',
      ),
      OutfitOption(
        theme: '세이지 후디 데님',
        combination: '도톰한 후드티 + 데님 + 스니커즈 + 숄더백',
        assetPath: 'assets/outfits/9_11/4.webp',
      ),
    ],
  ),
  OutfitGuide(
    key: '12_16',
    minTemp: 12,
    maxTemp: 16,
    title: '가벼운 간절기',
    message: '얇은 자켓이나 가디건이 잘 맞아요. 낮에 더우면 쉽게 벗을 수 있게 코디해보세요.',
    options: [
      OutfitOption(
        theme: '핑크 가디건 데님',
        combination: '가디건 + 반팔티 + 데님 롱스커트 + 스니커즈',
        assetPath: 'assets/outfits/12_16/1.webp',
      ),
      OutfitOption(
        theme: '그레이 맨투맨 스커트',
        combination: '맨투맨 + 롱스커트 + 스니커즈 + 숄더백',
        assetPath: 'assets/outfits/12_16/2.webp',
      ),
      OutfitOption(
        theme: '베이지 자켓 모던 룩',
        combination: '자켓 + 셔츠 + 슬랙스 + 플랫슈즈',
        assetPath: 'assets/outfits/12_16/3.webp',
      ),
      OutfitOption(
        theme: '크림 가디건 데일리',
        combination: '케이블 가디건 + 반팔티 + 데님 + 스니커즈',
        assetPath: 'assets/outfits/12_16/4.webp',
      ),
      OutfitOption(
        theme: '데님 자켓 스커트',
        combination: '데님 자켓 + 긴팔티 + 롱스커트 + 스니커즈',
        assetPath: 'assets/outfits/12_16/5.webp',
      ),
    ],
  ),
  OutfitGuide(
    key: '17_22',
    minTemp: 17,
    maxTemp: 22,
    title: '얇은 긴팔이 좋은 날',
    message: '선선하고 활동하기 좋아요. 셔츠나 얇은 가디건 하나면 아침저녁까지 든든해요.',
    options: [
      OutfitOption(
        theme: '블루 셔츠 클린 룩',
        combination: '셔츠 + 반팔 이너 + 화이트 팬츠 + 스니커즈',
        assetPath: 'assets/outfits/17_22/1.webp',
      ),
      OutfitOption(
        theme: '그레이 니트 스커트',
        combination: '얇은 니트 + 크림 롱스커트 + 스니커즈',
        assetPath: 'assets/outfits/17_22/2.webp',
      ),
      OutfitOption(
        theme: '세이지 가디건 데님',
        combination: '가디건 + 반팔티 + 데님 + 스니커즈',
        assetPath: 'assets/outfits/17_22/3.webp',
      ),
      OutfitOption(
        theme: '핑크 가디건 페미닌',
        combination: '가디건 + 반팔티 + 데님 스커트 + 스니커즈',
        assetPath: 'assets/outfits/17_22/4.webp',
      ),
      OutfitOption(
        theme: '스트라이프 데님 캐주얼',
        combination: '스트라이프 긴팔티 + 데님 + 스니커즈',
        assetPath: 'assets/outfits/17_22/5.webp',
      ),
      OutfitOption(
        theme: '세이지 셔츠 내추럴',
        combination: '셔츠 + 화이트 팬츠 + 로퍼 + 숄더백',
        assetPath: 'assets/outfits/17_22/6.webp',
      ),
      OutfitOption(
        theme: '블루 셔츠 스커트',
        combination: '오버핏 셔츠 + 슬리브리스 + 롱스커트 + 스니커즈',
        assetPath: 'assets/outfits/17_22/7.webp',
      ),
      OutfitOption(
        theme: '스트라이프 가디건 룩',
        combination: '얇은 가디건 + 반팔 이너 + 크림 팬츠 + 스니커즈',
        assetPath: 'assets/outfits/17_22/8.webp',
      ),
    ],
  ),
  OutfitGuide(
    key: '23_26',
    minTemp: 23,
    maxTemp: 26,
    title: '산뜻한 초여름',
    message: '따뜻한 날씨예요. 반팔이나 얇은 셔츠처럼 가볍고 통풍 잘 되는 옷이 좋아요.',
    options: [
      OutfitOption(
        theme: '화이트 셔츠 데님',
        combination: '반팔 셔츠 + 와이드 데님 + 스니커즈',
        assetPath: 'assets/outfits/23_26/1.webp',
      ),
      OutfitOption(
        theme: '세이지 니트 클린 룩',
        combination: '반팔 카라 니트 + 화이트 팬츠 + 스니커즈',
        assetPath: 'assets/outfits/23_26/2.webp',
      ),
      OutfitOption(
        theme: '블루 블라우스 스커트',
        combination: '반팔 블라우스 + 롱스커트 + 스니커즈',
        assetPath: 'assets/outfits/23_26/3.webp',
      ),
      OutfitOption(
        theme: '라벤더 니트 내추럴',
        combination: '반팔 니트 + 린넨 와이드팬츠 + 플랫슈즈',
        assetPath: 'assets/outfits/23_26/4.webp',
      ),
    ],
  ),
  OutfitGuide(
    key: '27_plus',
    minTemp: 27,
    maxTemp: null,
    title: '한여름 옷차림',
    message: '더운 날이에요. 통풍 잘 되는 옷을 입고, 실내 냉방용 얇은 겉옷도 챙겨주세요.',
    options: [
      OutfitOption(
        theme: '화이트 티 데님 쇼츠',
        combination: '반팔티 + 데님 반바지 + 스니커즈 + 미니백',
        assetPath: 'assets/outfits/27_plus/1.webp',
      ),
      OutfitOption(
        theme: '세이지 니트 쇼츠',
        combination: '반팔 니트 + 가벼운 반바지 + 샌들 + 에코백',
        assetPath: 'assets/outfits/27_plus/2.webp',
      ),
      OutfitOption(
        theme: '블루 블라우스 스커트',
        combination: '반팔 블라우스 + 시폰 롱스커트 + 스니커즈',
        assetPath: 'assets/outfits/27_plus/3.webp',
      ),
      OutfitOption(
        theme: '라벤더 블라우스 린넨',
        combination: '반팔 블라우스 + 린넨 팬츠 + 샌들',
        assetPath: 'assets/outfits/27_plus/4.webp',
      ),
      OutfitOption(
        theme: '화이트 슬리브리스 원피스',
        combination: '민소매 원피스 + 샌들 + 가벼운 숄더백',
        assetPath: 'assets/outfits/27_plus/5.webp',
      ),
    ],
  ),
];
