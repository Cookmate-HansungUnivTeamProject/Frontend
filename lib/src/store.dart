import 'dart:async';

import 'package:flutter/material.dart';

import 'api.dart';

/// 타이머로 고를 수 있는 시간(백엔드 규칙: 30초~5분, 30초 단위).
const minTimerSec = 30;
const maxTimerSec = 300;
const timerStepSec = 30;

/// 화면의 기기 한 칸. 서버의 기기(devices)와 타이머(timers)를 같은 ID로 묶었다.
/// 공용 타이머는 기기가 없어서 [isDevice]가 false이고, 후드·환풍기는 타이머가 없다.
class KitchenDevice {
  KitchenDevice(
    this.id,
    this.name,
    this.icon, {
    this.isDevice = true,
    this.timerId,
  });

  final String id;
  String name;
  final IconData icon;
  final bool isDevice;
  final String? timerId;

  bool power = false;
  int level = 0;

  String timerState = 'idle'; // idle · running · ringing (서버 값)
  int setSec = 0; // 서버에서 시작한 시간(초)
  DateTime? deadline; // 진행 중일 때 끝나는 시각(화면에서 1초씩 줄이는 데 씀)
  int pick = 180; // 시작 전에 고르는 시간(초)

  bool get hasTimer => timerId != null;
  bool get hasLevel => id.startsWith('gas');

  /// 전자레인지는 타이머가 곧 동작이다(돌리면 켜지고, 끝나거나 끄면 꺼짐).
  bool get timerDrivesPower => id == 'microwave';

  bool get running => timerState == 'running';
  bool get ringing => timerState == 'ringing';
  bool get timerActive => running || ringing;

  /// 강조 색을 쓸지(기기는 켜짐, 공용 타이머는 돌거나 울리는 중).
  bool get lit => isDevice ? power : timerActive;

  String get statusText {
    if (isDevice) return power ? '켜짐' : '꺼짐';
    if (ringing) return '알람';
    return running ? '진행 중' : '대기';
  }

  /// 화면에 보이는 남은 시간(초). 시작 전이면 고른 시간.
  int get seconds {
    if (ringing) return 0;
    if (!running) return pick;
    final end = deadline;
    if (end == null) return setSec;
    final upper = setSec > 0 ? setSec : maxTimerSec;
    final ms = end.difference(DateTime.now()).inMilliseconds;
    return (ms / 1000).ceil().clamp(0, upper);
  }

  /// 진행 막대의 전체 시간(초).
  int get duration => timerActive && setSec > 0 ? setSec : pick;
}

String clockText(int seconds) =>
    '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';

/// 26.0 → '26', 3.5 → '3.5'
String tempText(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(1);

/// 주문이 들어온 뒤 지난 시간(밀리초) → '방금 전', '3분 전', '1시간 전'
String agoText(int ms) {
  final minutes = ms ~/ 60000;
  if (minutes < 1) return '방금 전';
  if (minutes < 60) return '$minutes분 전';
  return '${minutes ~/ 60}시간 전';
}

class KitchenOrder {
  KitchenOrder({
    required this.id,
    required this.slot,
    required this.menu,
    required this.qty,
    required this.request,
    required this.serverStatus,
    required this.time,
  });

  factory KitchenOrder.fromJson(Map<String, dynamic> json, int serverTime) =>
      KitchenOrder(
        id: (json['id'] as num).toInt(),
        slot: (json['slot'] as num).toInt(),
        menu: json['menu'] as String,
        qty: (json['qty'] as num).toInt(),
        request: json['request'] as String,
        serverStatus: json['status'] as String,
        time: agoText(serverTime - (json['created_at'] as num).toInt()),
      );

  final int id; // 버튼 API에 쓰는 고유 번호
  final int slot; // 화면·음성에서 부르는 주문 번호(1~10)
  final String menu;
  final int qty;
  final String request;
  final String serverStatus; // new · accepted · done · rider_called · rejected
  final String time;

  int get number => slot;

  /// 화면 탭 기준: 0 접수 대기 · 1 진행 중 · 2 완료 · 3 취소
  int get status => switch (serverStatus) {
    'new' => 0,
    'accepted' => 1,
    'rejected' => 3,
    _ => 2, // done · rider_called
  };

  String get items {
    final line = '$menu × $qty';
    final req = request.trim();
    return req.isEmpty || req == '없음' ? line : '$line\n요청: $req';
  }
}

/// 화면 상태. 백엔드 GET /api/state를 1초마다 읽어 맞추고, 버튼은 백엔드 API로 보낸다.
class KitchenStore extends ChangeNotifier {
  KitchenStore({KitchenApi? api, bool poll = true})
    : api = api ?? KitchenApi() {
    if (poll) {
      unawaited(refresh());
      _poller = Timer.periodic(pollInterval, (_) => refresh());
      // 폴링이 늦어도 타이머 숫자는 1초마다 줄어들게
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!_disposed && devices.any((d) => d.running)) notifyListeners();
      });
    }
  }

  static const pollInterval = Duration(seconds: 1);

  final KitchenApi api;
  Timer? _poller;
  Timer? _ticker;
  bool _polling = false;
  bool _again = false;
  bool _disposed = false;
  final _levelHold = <String>{}; // 화력 슬라이더를 움직이는 중인 기기(폴링이 덮어쓰지 않게)

  final devices = [
    KitchenDevice(
      'gas_1',
      '1번 가스레인지',
      Icons.local_fire_department_outlined,
      timerId: 'gas_1',
    ),
    KitchenDevice(
      'gas_2',
      '2번 가스레인지',
      Icons.local_fire_department,
      timerId: 'gas_2',
    ),
    KitchenDevice('microwave', '전자레인지', Icons.microwave, timerId: 'microwave'),
    KitchenDevice('hood', '후드', Icons.air),
    KitchenDevice('fan', '환풍기', Icons.wind_power_outlined),
    KitchenDevice(
      'shared',
      '공용 타이머',
      Icons.timer_outlined,
      isDevice: false,
      timerId: 'shared',
    ),
  ];
  List<KitchenOrder> orders = [];
  double kitchenTemp = 0;
  double fridgeTemp = 0;
  bool fridgeWarning = false;

  bool connected = false;
  String? error; // 마지막 연결 오류(연결되면 null)
  String? notice; // 화면에 잠깐 띄울 안내(띄운 뒤 takeNotice로 비움)

  bool notifications = true;
  bool sound = true;
  bool vibration = true;

  String get apiBase => api.baseUrl;
  Iterable<KitchenDevice> get timers => devices.where((d) => d.hasTimer);
  KitchenDevice device(String id) => devices.firstWhere((d) => d.id == id);

  void changed() => notifyListeners();

  String? takeNotice() {
    final text = notice;
    notice = null;
    return text;
  }

  Future<void> setApiBase(String value) async {
    api.baseUrl = KitchenApi.normalizeBase(value);
    connected = false;
    error = null;
    _notify();
    await refresh();
  }

  /// 서버 상태를 다시 읽는다. 읽는 중에 또 부르면 끝난 뒤 한 번 더 읽는다.
  Future<void> refresh() async {
    if (_disposed) return;
    if (_polling) {
      _again = true;
      return;
    }
    _polling = true;
    try {
      apply(await api.state());
      connected = true;
      error = null;
    } on ApiException catch (e) {
      connected = false;
      error = e.message;
    } finally {
      _polling = false;
    }
    _notify();
    if (_again && !_disposed) {
      _again = false;
      await refresh();
    }
  }

  /// GET /api/state 응답을 화면 상태에 반영한다.
  void apply(Map<String, dynamic> state) {
    final now = DateTime.now();
    for (final d in state['devices'] as List) {
      _applyDevice(d as Map<String, dynamic>);
    }
    for (final t in state['timers'] as List) {
      _applyTimer(t as Map<String, dynamic>, now);
    }
    final serverTime = (state['server_time'] as num).toInt();
    orders = [
      for (final o in state['orders'] as List)
        KitchenOrder.fromJson(o as Map<String, dynamic>, serverTime),
    ];
    final env = state['env'] as Map<String, dynamic>;
    kitchenTemp = (env['kitchen_temp'] as num).toDouble();
    fridgeTemp = (env['fridge_temp'] as num).toDouble();
    fridgeWarning = (state['alerts'] as List).any(
      (a) => (a as Map<String, dynamic>)['kind'] == 'fridge_temp',
    );
  }

  KitchenDevice? _byId(String id) {
    for (final d in devices) {
      if (d.isDevice && d.id == id) return d;
    }
    return null;
  }

  KitchenDevice? _byTimer(String id) {
    for (final d in devices) {
      if (d.timerId == id) return d;
    }
    return null;
  }

  void _applyDevice(Map<String, dynamic> json, {bool force = false}) {
    final d = _byId(json['id'] as String);
    if (d == null) return;
    d.name = json['name'] as String;
    d.power = json['on'] as bool;
    if (force || !_levelHold.contains(d.id)) {
      d.level = (json['level'] as num).toInt();
    }
  }

  void _applyTimer(Map<String, dynamic> json, DateTime now) {
    final d = _byTimer(json['id'] as String);
    if (d == null) return;
    if (!d.isDevice) d.name = json['name'] as String;
    final state = json['state'] as String;
    final remaining = (json['remaining_sec'] as num).toInt();
    d.setSec = (json['set_sec'] as num).toInt();
    if (state == 'running') {
      // 서버는 남은 초를 올림해서 보낸다. 1초 안쪽 차이는 무시해야 숫자가 튀지 않는다.
      if (!d.running || d.deadline == null || (d.seconds - remaining).abs() > 1) {
        d.deadline = now.add(Duration(seconds: remaining));
      }
    } else {
      d.deadline = null;
    }
    d.timerState = state;
  }

  // ------------------------------------------------------------ 버튼

  Future<void> power(KitchenDevice d, bool value) async {
    if (!d.isDevice || d.power == value) return;
    if (d.timerDrivesPower && value) {
      _say('전자레인지는 타이머로 돌려요.');
      return;
    }
    await _run(() => api.devicePower(d.id, value));
  }

  /// 화력 슬라이더를 움직이는 동안 화면만 바꾼다(손을 떼면 [setLevel]로 보냄).
  void previewLevel(KitchenDevice d, int level) {
    if (!d.hasLevel) return;
    _levelHold.add(d.id);
    d.level = level;
    _notify();
  }

  Future<void> setLevel(KitchenDevice d, int level) async {
    if (!d.hasLevel) return;
    _levelHold.add(d.id);
    d.level = level;
    _notify();
    try {
      await _run(
        () => api.deviceLevel(d.id, level),
        whenNotOk: '꺼져 있으면 화력을 바꿀 수 없어요.',
      );
    } finally {
      _levelHold.remove(d.id);
    }
  }

  /// 시작 전 시간 고르기(30초~5분).
  void adjust(KitchenDevice d, int delta) {
    if (d.timerActive) return;
    d.pick = (d.pick + delta).clamp(minTimerSec, maxTimerSec);
    _notify();
  }

  Future<void> start(KitchenDevice d) async {
    final id = d.timerId;
    if (id == null || d.running) return;
    await _run(() => api.timerStart(id, d.pick));
  }

  /// 타이머 끄기(알람도 꺼지고 초기화). 전자레인지는 전원도 꺼진다.
  Future<void> stop(KitchenDevice d) async {
    final id = d.timerId;
    if (id == null) return;
    await _run(() => api.timerStop(id));
  }

  Future<void> accept(KitchenOrder o) =>
      _run(() => api.orderAction(o.id, 'accept'));

  Future<void> reject(KitchenOrder o) =>
      _run(() => api.orderAction(o.id, 'reject'));

  Future<void> complete(KitchenOrder o) =>
      _run(() => api.orderAction(o.id, 'complete'));

  /// 버튼 요청을 보내고 응답을 바로 화면에 반영한 뒤, 서버 상태를 다시 읽는다.
  /// 서버가 거절하면(409·422, ok=false) 안내를 띄운다. 화면은 다시 읽은 서버 상태로 맞춰진다.
  Future<void> _run(
    Future<Map<String, dynamic>> Function() call, {
    String? whenNotOk,
  }) async {
    try {
      final res = await call();
      final device = res['device'];
      if (device is Map<String, dynamic>) _applyDevice(device, force: true);
      final timer = res['timer'];
      if (timer is Map<String, dynamic>) _applyTimer(timer, DateTime.now());
      if (res['ok'] == false && whenNotOk != null) _say(whenNotOk);
    } on ApiException catch (e) {
      _say(e.message);
    }
    _notify();
    await refresh();
  }

  void _say(String text) {
    notice = text;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _poller?.cancel();
    _ticker?.cancel();
    api.close();
    super.dispose();
  }
}
