import 'package:weather_friend/features/character/domain/character.dart';

/// 옷 추천 한 칸 — 아이콘과 그 아래 붙는 짧은 라벨.
/// 라벨은 수식어 없이 옷 이름만 쓴다 ("가벼운 원피스" X, "원피스" O).
class OutfitItem {
  const OutfitItem(this.label, this.asset);

  final String label;
  final String asset;
}

class OutfitGuide {
  const OutfitGuide({
    required this.key,
    required this.minTemp,
    required this.maxTemp,
    required this.title,
    required this.items,
    required this.message,
    this.wear = const [],
  });

  final String key;
  final int? minTemp;
  final int? maxTemp;
  final String title;
  final List<String> items;
  final String message;

  /// 카드에 그려지는 아이콘+라벨 셀 목록.
  /// 아이콘이 없는 항목(발열내의 등)은 빠지므로 [items]와 1:1은 아님.
  final List<OutfitItem> wear;

  bool contains(int temperature) {
    final aboveMin = minTemp == null || temperature >= minTemp!;
    final belowMax = maxTemp == null || temperature <= maxTemp!;
    return aboveMin && belowMax;
  }
}

OutfitGuide outfitGuideFor(int feelsLikeTemp) {
  return outfitGuides.firstWhere((guide) => guide.contains(feelsLikeTemp));
}

const kUmbrellaAsset = '$_c/umbrella.png';
const kUmbrellaItem = OutfitItem('우산', kUmbrellaAsset);

/// 우산을 챙겨야 하는 날인지 — 비/이슬비/소나기/천둥번개 컨디션이거나
/// 강수확률이 60% 이상이면 true. (눈은 우산 대신 보온을 우선해 제외.)
bool umbrellaNeeded({String? condition, int? precipitationProb}) {
  final c = condition ?? '';
  if (c.contains('비') || c.contains('소나기') || c.contains('천둥')) {
    return true;
  }
  return (precipitationProb ?? 0) >= 60;
}

/// 화면에 그릴 최종 셀 목록 — 비 소식이 있으면 우산이 마지막에 붙는다.
List<OutfitItem> outfitWearFor(OutfitGuide guide, {bool rainy = false}) {
  return [...guide.wear, if (rainy) kUmbrellaItem];
}

String outfitMessageForCharacter(CharacterId characterId, OutfitGuide guide) {
  return switch ((guide.key, characterId)) {
    ('minus5', CharacterId.jiyoung) => '오늘은 정말 추워. 롱패딩 단단히 입고 목도리랑 장갑까지 꼭 챙겨.',
    ('minus5', CharacterId.sohee) =>
      '오늘은 한파 수준의 추위가 예상됩니다. 롱패딩과 목도리, 장갑까지 준비해 주세요.',
    ('minus5', CharacterId.jihoon) =>
      '아가씨, 오늘은 보온이 가장 중요합니다. 롱패딩에 목도리와 장갑까지 꼭 챙기십시오.',
    ('minus5', CharacterId.siwon) => '오늘 진짜 춥다. 롱패딩에 목도리, 장갑까지 챙겨야 든든하겠어.',
    ('minus4_0', CharacterId.jiyoung) => '두꺼운 패딩이나 코트 입고, 안에도 니트나 기모로 따뜻하게 챙겨.',
    ('minus4_0', CharacterId.sohee) =>
      '두꺼운 패딩이나 코트가 필요하겠습니다. 니트나 기모 소재를 함께 착용해 주세요.',
    ('minus4_0', CharacterId.jihoon) =>
      '아가씨, 두꺼운 아우터가 필요합니다. 니트나 기모 소재도 함께 입으셔야 든든합니다.',
    ('minus4_0', CharacterId.siwon) => '패딩이나 두꺼운 코트가 딱이야. 안에도 따뜻하게 입어야 편하겠어.',
    ('1_4', CharacterId.jiyoung) => '아직 꽤 추워. 도톰한 패딩이나 코트에 니트도 함께 입어.',
    ('1_4', CharacterId.sohee) =>
      '아직 추운 날씨가 이어지겠습니다. 패딩이나 코트에 니트를 함께 입으시기 바랍니다.',
    ('1_4', CharacterId.jihoon) =>
      '아가씨, 초겨울 옷차림이 알맞겠습니다. 도톰한 아우터와 니트를 함께 입으시지요.',
    ('1_4', CharacterId.siwon) => '아직 겨울 느낌이야. 도톰한 아우터에 니트까지 입으면 딱 좋겠어.',
    ('5_8', CharacterId.jiyoung) => '쌀쌀하니까 코트나 경량패딩 챙겨. 얇은 겉옷만 입으면 추울 수 있어.',
    ('5_8', CharacterId.sohee) => '제법 쌀쌀하겠습니다. 얇은 겉옷보다는 코트나 경량패딩이 적당하겠습니다.',
    ('5_8', CharacterId.jihoon) =>
      '아가씨, 제법 쌀쌀한 날입니다. 코트나 경량패딩처럼 보온되는 아우터를 권해드립니다.',
    ('5_8', CharacterId.siwon) => '오늘은 꽤 쌀쌀해. 코트나 경량패딩 하나 입으면 든든하겠어.',
    ('9_11', CharacterId.jiyoung) => '가디건만 입으면 조금 추울 수 있어. 자켓이나 트렌치코트 하나 걸쳐.',
    ('9_11', CharacterId.sohee) => '가디건만으로는 다소 쌀쌀하겠습니다. 자켓이나 트렌치코트를 준비해 주세요.',
    ('9_11', CharacterId.jihoon) =>
      '아가씨, 가디건만으로는 쌀쌀할 수 있습니다. 자켓이나 트렌치코트를 걸치시지요.',
    ('9_11', CharacterId.siwon) => '가디건 하나로는 살짝 춥겠어. 자켓이나 트렌치코트 걸치면 딱이야.',
    ('12_16', CharacterId.jiyoung) => '얇은 자켓이나 가디건 챙겨. 낮에 더우면 편하게 벗어두면 돼.',
    ('12_16', CharacterId.sohee) =>
      '얇은 자켓이나 가디건이 적당하겠습니다. 낮에는 벗기 편한 옷차림이 좋겠습니다.',
    ('12_16', CharacterId.jihoon) =>
      '아가씨, 간절기 옷차림이 알맞겠습니다. 벗기 편한 얇은 아우터를 준비하시지요.',
    ('12_16', CharacterId.siwon) => '딱 간절기 날씨야. 얇은 자켓 하나 챙기면 하루 종일 편하겠어.',
    ('17_19', CharacterId.jiyoung) => '선선해서 가벼운 긴팔이면 충분해. 얇은 가디건 하나 챙겨도 좋아.',
    ('17_19', CharacterId.sohee) =>
      '가벼운 긴팔이면 충분하겠습니다. 아침저녁을 대비해 얇은 가디건을 챙겨 주세요.',
    ('17_19', CharacterId.jihoon) =>
      '아가씨, 선선한 날입니다. 가벼운 긴팔이나 얇은 가디건 한 벌이면 충분하겠습니다.',
    ('17_19', CharacterId.siwon) => '가볍게 긴팔 입기 좋은 날이야. 얇은 가디건 하나면 충분하겠어.',
    ('20_22', CharacterId.jiyoung) => '낮에는 포근해. 아침저녁에 쌀쌀할 수 있으니 얇은 셔츠 하나 챙겨봐.',
    ('20_22', CharacterId.sohee) =>
      '낮에는 포근하겠습니다. 아침저녁을 대비해 얇은 셔츠나 겉옷을 준비해 주세요.',
    ('20_22', CharacterId.jihoon) =>
      '아가씨, 낮에는 포근하지만 아침저녁은 선선합니다. 얇은 겉옷 하나 챙기시지요.',
    ('20_22', CharacterId.siwon) => '낮에는 포근하겠어. 얇은 셔츠 하나 챙기면 아침저녁에도 딱 좋아.',
    ('23_26', CharacterId.jiyoung) => '따뜻하니까 얇고 통풍 잘 되는 옷으로 가볍게 입어.',
    ('23_26', CharacterId.sohee) => '따뜻한 날씨가 예상됩니다. 얇고 통풍이 잘되는 옷차림이 적당하겠습니다.',
    ('23_26', CharacterId.jihoon) => '아가씨, 따뜻한 날입니다. 얇고 통풍이 잘되는 옷차림으로 준비하시지요.',
    ('23_26', CharacterId.siwon) => '가볍게 입기 좋은 날이야. 얇고 통풍 잘 되는 옷이면 딱이겠어.',
    ('27_plus', CharacterId.jiyoung) =>
      '통풍이 잘 되는 옷을 입고, 실내에선 에어컨을 대비해 겉옷을 챙겨봐.',
    ('27_plus', CharacterId.sohee) =>
      '더운 날씨가 이어지겠습니다. 통풍이 잘되는 옷을 입고 얇은 겉옷도 준비해 주세요.',
    ('27_plus', CharacterId.jihoon) =>
      '아가씨, 통풍이 잘되는 옷이 알맞겠습니다. 실내 냉방에 대비해 얇은 겉옷도 챙기십시오.',
    ('27_plus', CharacterId.siwon) =>
      '오늘은 시원한 옷이 딱이야. 얇은 겉옷 하나 챙기면 실내에서도 편하겠어.',
    _ => guide.message,
  };
}

const _c = 'assets/clothes';

const outfitGuides = <OutfitGuide>[
  OutfitGuide(
    key: 'minus5',
    minTemp: null,
    maxTemp: -5,
    title: '한파급 추위',
    items: ['롱패딩', '발열내의', '기모바지', '목도리', '장갑'],
    message: '보온이 최우선이에요. 목과 손까지 따뜻하게 챙겨주세요.',
    wear: [
      OutfitItem('롱패딩', '$_c/padding_jacket.png'),
      OutfitItem('기모바지', '$_c/pants.png'),
      OutfitItem('목도리', '$_c/scarf.png'),
      OutfitItem('장갑', '$_c/gloves.png'),
    ],
  ),
  OutfitGuide(
    key: 'minus4_0',
    minTemp: -4,
    maxTemp: 0,
    title: '두꺼운 아우터 필수',
    items: ['패딩', '두꺼운 코트', '목폴라', '기모 하의'],
    message: '두꺼운 아우터에 니트나 기모 소재를 함께 입는 게 좋아요.',
    wear: [
      OutfitItem('패딩', '$_c/padding_jacket2.png'),
      OutfitItem('무스탕', '$_c/mustang2.png'),
      OutfitItem('니트', '$_c/pullover_knit.png'),
      OutfitItem('청바지', '$_c/jeans.png'),
    ],
  ),
  OutfitGuide(
    key: '1_4',
    minTemp: 1,
    maxTemp: 4,
    title: '초겨울 옷차림',
    items: ['숏패딩', '울코트', '니트', '머플러'],
    message: '아직 꽤 추워요. 도톰한 아우터와 니트를 추천해요.',
    wear: [
      OutfitItem('숏패딩', '$_c/short_padding.png'),
      OutfitItem('코트', '$_c/coat.png'),
      OutfitItem('니트', '$_c/pullover_knit.png'),
      OutfitItem('목도리', '$_c/scarf.png'),
    ],
  ),
  OutfitGuide(
    key: '5_8',
    minTemp: 5,
    maxTemp: 8,
    title: '쌀쌀한 날씨',
    items: ['코트', '경량패딩', '무스탕', '두꺼운 니트'],
    message: '가벼운 겉옷보다는 코트나 경량패딩이 안정적이에요.',
    wear: [
      OutfitItem('코트', '$_c/coat.png'),
      OutfitItem('패딩조끼', '$_c/vest.png'),
      OutfitItem('무스탕', '$_c/mustang.png'),
      OutfitItem('니트', '$_c/pullover_knit.png'),
    ],
  ),
  OutfitGuide(
    key: '9_11',
    minTemp: 9,
    maxTemp: 11,
    title: '자켓이 필요한 날',
    items: ['트렌치코트', '야상', '울자켓', '맨투맨'],
    message: '가디건만 입기엔 쌀쌀할 수 있어 자켓을 걸치는 게 좋아요.',
    wear: [
      OutfitItem('트렌치', '$_c/trench-coat.png'),
      OutfitItem('야상', '$_c/jumper.png'),
      OutfitItem('자켓', '$_c/jacket-2.png'),
      OutfitItem('맨투맨', '$_c/sweater.png'),
    ],
  ),
  OutfitGuide(
    key: '12_16',
    minTemp: 12,
    maxTemp: 16,
    title: '간절기 날씨',
    items: ['얇은 자켓', '가디건', '니트', '맨투맨'],
    message: '낮에는 벗기 쉽도록 얇은 아우터를 챙겨보세요.',
    wear: [
      OutfitItem('데님자켓', '$_c/blue_jacket.png'),
      OutfitItem('가디건', '$_c/cardigan.png'),
      OutfitItem('니트', '$_c/pullover_knit.png'),
      OutfitItem('맨투맨', '$_c/sweater.png'),
    ],
  ),
  OutfitGuide(
    key: '17_19',
    minTemp: 17,
    maxTemp: 19,
    title: '선선한 날씨',
    items: ['얇은 니트', '셔츠', '맨투맨', '가디건'],
    message: '두꺼운 아우터 없이 가벼운 긴팔이면 충분해요.',
    wear: [
      OutfitItem('니트', '$_c/pullover_knit.png'),
      OutfitItem('셔츠', '$_c/shirt-1.png'),
      OutfitItem('후드티', '$_c/hoodie.png'),
      OutfitItem('가디건', '$_c/cardigan2.png'),
      OutfitItem('원피스', '$_c/long_arm_dress.png'),
    ],
  ),
  OutfitGuide(
    key: '20_22',
    minTemp: 20,
    maxTemp: 22,
    title: '포근한 날씨',
    items: ['긴팔티', '블라우스', '얇은 셔츠', '면바지'],
    message: '낮에는 포근하지만 아침저녁엔 얇은 겉옷이 유용해요.',
    wear: [
      OutfitItem('긴팔티', '$_c/long_arm_t_shirt.png'),
      OutfitItem('블라우스', '$_c/tanktop_blouse.png'),
      OutfitItem('셔츠', '$_c/shirt-1.png'),
      OutfitItem('면바지', '$_c/pants2.png'),
      OutfitItem('원피스', '$_c/long_arm_dress2.png'),
    ],
  ),
  OutfitGuide(
    key: '23_26',
    minTemp: 23,
    maxTemp: 26,
    title: '따뜻한 날씨',
    items: ['반팔', '얇은 셔츠', '린넨팬츠', '가벼운 원피스'],
    message: '얇고 통풍이 잘 되는 옷차림이 좋아요.',
    wear: [
      OutfitItem('반팔', '$_c/polo.png'),
      OutfitItem('셔츠', '$_c/half_arm_shirt-3.png'),
      OutfitItem('린넨팬츠', '$_c/pants2.png'),
      OutfitItem('원피스', '$_c/tanktop_dress3.png'),
    ],
  ),
  OutfitGuide(
    key: '27_plus',
    minTemp: 27,
    maxTemp: null,
    title: '더운 날씨',
    items: ['반팔', '민소매', '반바지', '린넨'],
    message: '통풍이 잘 되는 옷을 입고, 실내 냉방용 겉옷을 챙겨주세요.',
    wear: [
      OutfitItem('반팔', '$_c/t_shirt.png'),
      OutfitItem('민소매', '$_c/tanktop.png'),
      OutfitItem('반바지', '$_c/shorts.png'),
      OutfitItem('원피스', '$_c/tanktop_dress.png'),
    ],
  ),
];
