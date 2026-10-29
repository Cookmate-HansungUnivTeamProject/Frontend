import 'dart:async';

import 'package:flutter/material.dart';

class KitchenDevice {
  KitchenDevice(this.id, this.name, this.icon, {this.power = false});
  final String id;
  final String name;
  final IconData icon;
  bool power;
  int level = 2;
  int seconds = 180;
  int duration = 180;
  bool running = false;
  DateTime? deadline;
}

String clockText(int seconds) =>
    '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';

class KitchenOrder {
  KitchenOrder(this.number, this.items, this.time, {this.status = 0});
  final int number;
  final String items;
  final String time;
  int status;
}

class KitchenStore extends ChangeNotifier {
  KitchenStore({bool tick = true}) {
    if (tick) {
      ticker = Timer.periodic(const Duration(seconds: 1), (_) => refresh());
    }
  }
  Timer? ticker;
  final devices = [
    KitchenDevice('gas-1', '가스레인지 1', Icons.local_fire_department_outlined),
    KitchenDevice('gas-2', '가스레인지 2', Icons.local_fire_department, power: true),
    KitchenDevice('microwave-1', '전자레인지 1', Icons.microwave, power: true),
    KitchenDevice('microwave-2', '전자레인지 2', Icons.microwave_outlined),
    KitchenDevice('hood', '후드', Icons.air),
    KitchenDevice('fan', '환기팬', Icons.wind_power_outlined),
    KitchenDevice('fridge', '냉장고', Icons.kitchen_outlined, power: true),
    KitchenDevice('freezer', '냉동고', Icons.ac_unit, power: true),
    KitchenDevice('timer-1', '공용 타이머 1', Icons.timer_outlined),
  ];
  final orders = [
    KitchenOrder(152, '두툼한 삼겹 김치찜 × 1\n콜라 × 1', '방금 전'),
    KitchenOrder(151, '두툼한 삼겹 김치찜 × 2\n공깃밥 × 2', '3분 전', status: 1),
    KitchenOrder(150, '차돌 된장찌개 × 1', '5분 전', status: 1),
    KitchenOrder(149, '두툼한 삼겹 김치찜 × 1', '12분 전', status: 2),
  ];
  bool notifications = true;
  bool sound = true;
  bool vibration = true;
  void changed() => notifyListeners();
  void power(KitchenDevice d, bool value) {
    d.power = value;
    if (!value) pause(d);
    notifyListeners();
  }

  void adjust(KitchenDevice d, int delta) {
    if (d.running) return;
    d.duration = (d.duration + delta).clamp(30, 5999);
    d.seconds = d.duration;
    notifyListeners();
  }

  void start(KitchenDevice d) {
    d.power = true;
    if (d.seconds <= 0) d.seconds = d.duration;
    d.deadline = DateTime.now().add(Duration(seconds: d.seconds));
    d.running = true;
    notifyListeners();
  }

  void pause(KitchenDevice d) {
    if (d.running) refresh();
    d.running = false;
    d.deadline = null;
    notifyListeners();
  }

  void reset(KitchenDevice d) {
    d.running = false;
    d.deadline = null;
    d.seconds = d.duration;
    notifyListeners();
  }

  void refresh() {
    bool changed = false;
    for (final d in devices.where((d) => d.running)) {
      final remaining =
          (d.deadline!.difference(DateTime.now()).inMilliseconds / 1000)
              .ceil()
              .clamp(0, 5999);
      if (remaining != d.seconds) changed = true;
      d.seconds = remaining;
      if (remaining == 0) {
        d.running = false;
        d.deadline = null;
      }
    }
    if (changed) notifyListeners();
  }

  @override
  void dispose() {
    ticker?.cancel();
    super.dispose();
  }
}
