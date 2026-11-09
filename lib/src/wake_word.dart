// "오르보" 호출어 판정. STT 글자의 앞부분을 자모로 쪼개 "ㅇㅗㄹㅡㅂㅗ"와 비교한다.
//
// "오르보"는 사전에 없는 말이라 STT가 "올보", "오르버", "어르보"처럼 적을 수 있다.
// 그래서 글자가 똑같지 않아도 자모 1개까지 다르면 인정한다. 마이크와 STT가 없어도 테스트할 수 있게
// 이 파일은 순수 Dart로만 쓴다.

/// 호출어 판정 결과.
class WakeMatch {
  const WakeMatch({
    required this.matched,
    required this.distance,
    required this.heard,
    required this.command,
  });

  /// 호출어로 인정했는지.
  final bool matched;

  /// 가장 가까운 앞부분과 "오르보"의 자모 거리(0이면 똑같음). 앞부분이 없으면 -1.
  final int distance;

  /// 호출어로 본 앞부분(예: "올보"). 인정하지 않았어도 가장 가까웠던 앞부분을 담는다.
  final String heard;

  /// 호출어 뒤의 명령 글자. 호출어만 말했으면 빈 문자열.
  final String command;
}

/// 호출어.
const wakeWord = '오르보';

/// 자모 몇 개까지 달라도 인정할지. 2로 올리면 "오보", "올봄"까지 받아서 잘못 깨어난다.
const wakeMaxDistance = 1;

const _choseong = 'ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ';
const _jungseong = 'ㅏㅐㅑㅒㅓㅔㅕㅖㅗㅘㅙㅚㅛㅜㅝㅞㅟㅠㅡㅢㅣ';
// 받침도 초성과 같은 글자로 본다(올보의 받침 ㄹ = 오르보의 초성 ㄹ). 겹받침은 한 글자로 본다.
const _jongseong = [
  '', 'ㄱ', 'ㄲ', 'ㄳ', 'ㄴ', 'ㄵ', 'ㄶ', 'ㄷ', 'ㄹ', 'ㄺ', 'ㄻ', 'ㄼ', 'ㄽ', 'ㄾ', //
  'ㄿ', 'ㅀ', 'ㅁ', 'ㅂ', 'ㅄ', 'ㅅ', 'ㅆ', 'ㅇ', 'ㅈ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ',
];

/// 한글 음절인지(가~힣).
bool isHangulSyllable(int rune) => rune >= 0xAC00 && rune <= 0xD7A3;

/// 음절들을 자모 목록으로 쪼갠다. 예: "올보" → [ㅇ, ㅗ, ㄹ, ㅂ, ㅗ]
List<String> toJamo(String syllables) {
  final out = <String>[];
  for (final rune in syllables.runes) {
    if (!isHangulSyllable(rune)) {
      out.add(String.fromCharCode(rune));
      continue;
    }
    final index = rune - 0xAC00;
    out.add(_choseong[index ~/ 588]);
    out.add(_jungseong[(index % 588) ~/ 28]);
    final jong = index % 28;
    if (jong > 0) {
      out.add(_jongseong[jong]);
    }
  }
  return out;
}

/// 두 자모 목록의 편집 거리(바꾸기·넣기·빼기 한 번 = 1).
int editDistance(List<String> a, List<String> b) {
  var previous = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final current = List<int>.filled(b.length + 1, 0);
    current[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      final replace = previous[j - 1] + cost;
      final remove = previous[j] + 1;
      final insert = current[j - 1] + 1;
      current[j] = [replace, remove, insert].reduce((x, y) => x < y ? x : y);
    }
    previous = current;
  }
  return previous[b.length];
}

final _wakeJamo = toJamo(wakeWord);
const _leadingSkip = ' \t\n,.!?~·…"\'“”‘’-';
const _trailingPunctuation = '.!?。~…';

/// [text]가 "오르보"로 시작하는지 보고, 뒤에 붙은 명령 글자를 떼어 준다.
///
/// - 문장 맨 앞의 한글 2~4글자(사이 띄어쓰기는 무시)만 본다. 중간에 나온 "오르보"는 호출로 보지 않는다.
/// - 호출어 바로 뒤에 붙은 "야"·"아"(오르보야)는 뗀다.
/// - 명령 앞의 쉼표·띄어쓰기와 끝의 마침표·물음표는 뗀다.
WakeMatch matchWake(String text, {int maxDistance = wakeMaxDistance}) {
  final runes = text.runes.toList();
  var i = 0;
  while (i < runes.length && _leadingSkip.runes.contains(runes[i])) {
    i++;
  }
  // 앞부분 한글 음절을 4개까지 모은다. ends[k]는 k+1번째 음절 바로 뒤의 위치.
  final syllables = <int>[];
  final ends = <int>[];
  while (i < runes.length && syllables.length < 4) {
    final rune = runes[i];
    if (isHangulSyllable(rune)) {
      syllables.add(rune);
      ends.add(i + 1);
      i++;
    } else if (rune == 0x20 && syllables.isNotEmpty) {
      i++; // "오르 보"처럼 STT가 띄어 쓴 경우
    } else {
      break;
    }
  }
  if (syllables.length < 2) {
    return const WakeMatch(matched: false, distance: -1, heard: '', command: '');
  }

  var bestLength = 0;
  var bestDistance = 1 << 30;
  for (var n = 2; n <= syllables.length; n++) {
    final candidate = String.fromCharCodes(syllables.sublist(0, n));
    final distance = editDistance(toJamo(candidate), _wakeJamo);
    // 거리가 같으면 "오르보"와 글자 수가 가까운 쪽(3글자)을 고른다.
    final closer = (n - 3).abs() < (bestLength - 3).abs();
    if (distance < bestDistance || (distance == bestDistance && closer)) {
      bestDistance = distance;
      bestLength = n;
    }
  }
  final heard = String.fromCharCodes(syllables.sublist(0, bestLength));
  if (bestDistance > maxDistance) {
    return WakeMatch(matched: false, distance: bestDistance, heard: heard, command: '');
  }

  var rest = runes.sublist(ends[bestLength - 1]);
  // "오르보야, …" / "오르보아 …": 바로 붙은 '야'·'아' 다음이 끝이거나 띄어쓰기·문장부호일 때만 뗀다.
  if (rest.isNotEmpty && (rest.first == 0xC57C || rest.first == 0xC544)) {
    final next = rest.length > 1 ? rest[1] : null;
    if (next == null || _leadingSkip.runes.contains(next)) {
      rest = rest.sublist(1);
    }
  }
  final command = stripSentenceEnd(_trimLeft(String.fromCharCodes(rest)));
  return WakeMatch(matched: true, distance: bestDistance, heard: heard, command: command);
}

/// 끝의 마침표·물음표·느낌표를 뗀다(STT가 붙이는 문장부호. AI 학습 문장에는 없음).
String stripSentenceEnd(String text) {
  var t = text.trim();
  while (t.isNotEmpty && _trailingPunctuation.contains(t[t.length - 1])) {
    t = t.substring(0, t.length - 1).trimRight();
  }
  return t;
}

/// 확인 질문("모든 기기를 켤까요?")에 대한 대답. 예면 true, 아니요면 false, 모르겠으면 null.
bool? yesOrNo(String text) {
  final t = text.replaceAll(RegExp(r'[\s.,!?~]'), '');
  const no = ['아니', '아냐', '안돼', '안해', '하지마', '취소', '됐어', '그만'];
  const yes = ['응', '네', '예', '어', '그래', '좋아', '켜', '해줘', '맞아', '부탁'];
  if (no.any(t.startsWith)) return false;
  if (yes.any(t.startsWith)) return true;
  return null;
}

String _trimLeft(String value) {
  var start = 0;
  final runes = value.runes.toList();
  while (start < runes.length && _leadingSkip.runes.contains(runes[start])) {
    start++;
  }
  return String.fromCharCodes(runes.sublist(start)).trim();
}
