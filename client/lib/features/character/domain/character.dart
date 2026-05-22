enum CharacterId { jiyoung, sohee, jihoon, siwon }

enum Gender { female, male }

class Character {
  const Character({
    required this.id,
    required this.displayName,
    required this.gender,
    required this.overseasMessage,
  });

  final CharacterId id;
  final String displayName;
  final Gender gender;
  final String overseasMessage;

  static const all = <Character>[
    Character(
      id: CharacterId.jiyoung,
      displayName: '다정한 지영',
      gender: Gender.female,
      overseasMessage:
          '어? 지금 해외에 있는 것 같네! 여행 잘 다녀와~ '
          '거기 날씨는 잘 몰라서… 한번 검색해보고, 안전하게 다녀와 💕',
    ),
    Character(
      id: CharacterId.sohee,
      displayName: '시크한 소희',
      gender: Gender.female,
      overseasMessage: '해외야? 거긴 잘 몰라. 직접 검색해. 잘 다녀와.',
    ),
    Character(
      id: CharacterId.jihoon,
      displayName: '듬직한 지훈',
      gender: Gender.male,
      overseasMessage:
          '현재 위치가 해외로 감지됐어. 여행이라면 잘 다녀와. '
          '거기 날씨는 직접 확인하는 게 정확할 거야. 안전 우선이야.',
    ),
    Character(
      id: CharacterId.siwon,
      displayName: '발랄한 시원',
      gender: Gender.male,
      overseasMessage:
          '헐 해외 갔어??? 부럽다아ㅏㅏ '
          '거기 날씨는 진짜 모르겠어ㅋㅋ Google 한 번 ㄱㄱ '
          '즐거운 여행!! 사진 많이 찍어와ㅋㅋ',
    ),
  ];

  static Character byId(CharacterId id) =>
      all.firstWhere((c) => c.id == id);

  static CharacterId? parseId(String value) {
    for (final id in CharacterId.values) {
      if (id.name == value) return id;
    }
    return null;
  }
}
