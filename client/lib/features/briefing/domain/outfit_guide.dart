class OutfitGuide {
  const OutfitGuide({
    required this.key,
    required this.minTemp,
    required this.maxTemp,
    required this.title,
    required this.items,
    required this.message,
  });

  final String key;
  final int? minTemp;
  final int? maxTemp;
  final String title;
  final List<String> items;
  final String message;

  bool contains(int temperature) {
    final aboveMin = minTemp == null || temperature >= minTemp!;
    final belowMax = maxTemp == null || temperature <= maxTemp!;
    return aboveMin && belowMax;
  }
}

OutfitGuide outfitGuideFor(int feelsLikeTemp) {
  return outfitGuides.firstWhere((guide) => guide.contains(feelsLikeTemp));
}

const outfitGuides = <OutfitGuide>[
  OutfitGuide(
    key: 'minus5',
    minTemp: null,
    maxTemp: -5,
    title: '한파급 추위',
    items: ['롱패딩', '발열내의', '기모바지', '목도리', '장갑'],
    message: '보온이 최우선이에요. 목과 손까지 따뜻하게 챙겨주세요.',
  ),
  OutfitGuide(
    key: 'minus4_0',
    minTemp: -4,
    maxTemp: 0,
    title: '두꺼운 아우터 필수',
    items: ['패딩', '두꺼운 코트', '목폴라', '기모 하의'],
    message: '두꺼운 아우터에 니트나 기모 소재를 함께 입는 게 좋아요.',
  ),
  OutfitGuide(
    key: '1_4',
    minTemp: 1,
    maxTemp: 4,
    title: '초겨울 옷차림',
    items: ['숏패딩', '울코트', '니트', '머플러'],
    message: '아직 꽤 추워요. 도톰한 아우터와 니트를 추천해요.',
  ),
  OutfitGuide(
    key: '5_8',
    minTemp: 5,
    maxTemp: 8,
    title: '쌀쌀한 날씨',
    items: ['코트', '경량패딩', '무스탕', '두꺼운 니트'],
    message: '가벼운 겉옷보다는 코트나 경량패딩이 안정적이에요.',
  ),
  OutfitGuide(
    key: '9_11',
    minTemp: 9,
    maxTemp: 11,
    title: '자켓이 필요한 날',
    items: ['트렌치코트', '야상', '울자켓', '맨투맨'],
    message: '가디건만 입기엔 쌀쌀할 수 있어 자켓을 걸치는 게 좋아요.',
  ),
  OutfitGuide(
    key: '12_16',
    minTemp: 12,
    maxTemp: 16,
    title: '간절기 날씨',
    items: ['얇은 자켓', '가디건', '니트', '맨투맨'],
    message: '낮에는 벗기 쉽도록 얇은 아우터를 챙겨보세요.',
  ),
  OutfitGuide(
    key: '17_19',
    minTemp: 17,
    maxTemp: 19,
    title: '선선한 날씨',
    items: ['얇은 니트', '셔츠', '맨투맨', '가디건'],
    message: '두꺼운 아우터 없이 가벼운 긴팔이면 충분해요.',
  ),
  OutfitGuide(
    key: '20_22',
    minTemp: 20,
    maxTemp: 22,
    title: '포근한 날씨',
    items: ['긴팔티', '블라우스', '얇은 셔츠', '면바지'],
    message: '낮에는 포근하지만 아침저녁엔 얇은 겉옷이 유용해요.',
  ),
  OutfitGuide(
    key: '23_26',
    minTemp: 23,
    maxTemp: 26,
    title: '따뜻한 날씨',
    items: ['반팔', '얇은 셔츠', '린넨팬츠', '가벼운 원피스'],
    message: '얇고 통풍이 잘 되는 옷차림이 좋아요.',
  ),
  OutfitGuide(
    key: '27_plus',
    minTemp: 27,
    maxTemp: null,
    title: '더운 날씨',
    items: ['반팔', '민소매', '반바지', '린넨'],
    message: '통풍이 잘 되는 옷을 입고, 실내 냉방용 겉옷을 챙겨주세요.',
  ),
];
