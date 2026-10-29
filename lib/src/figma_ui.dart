import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'store.dart';

// Figma: 프로젝트 이음, page 0:1. Values are logical pixels.
const designAmber = Color(0xFFFAA614);
const designBackground = Color(0xFF262626);
const designCard = Color(0xFF5F5F5F);
const designDarkCard = Color(0xFF313131);
const designRunning = Color(0xFFC07A00);
const designMuted = Color(0xFFAAAAAA);

TextStyle designText(
  double size, {
  Color color = Colors.white,
  bool body = false,
}) => TextStyle(
  fontFamily: body ? 'Pretendard' : 'GmarketSans',
  fontWeight: FontWeight.w500,
  fontSize: size,
  color: color,
  height: 1.2,
);

Widget designAsset(String file) => file.endsWith('.svg')
    ? SvgPicture.asset('assets/figma/$file', fit: BoxFit.contain)
    : Image.asset('assets/figma/$file', fit: BoxFit.contain);

Widget designChevron() =>
    RotatedBox(quarterTurns: 1, child: designAsset('33698.svg'));

class DesignCard extends StatelessWidget {
  const DesignCard({
    super.key,
    required this.child,
    this.color = designCard,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
  });
  final Widget child;
  final Color color;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: color,
    borderRadius: BorderRadius.circular(30),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(padding: padding, child: child),
    ),
  );
}

class DesignNavigation extends StatelessWidget {
  const DesignNavigation({
    super.key,
    required this.selected,
    required this.onChanged,
  });
  final int selected;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: Color(0xFF474747),
      boxShadow: [
        BoxShadow(color: Colors.black26, offset: Offset(0, -4), blurRadius: 4),
      ],
    ),
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: 94,
        child: Row(
          children: List.generate(4, (i) {
            const normal = ['305e5.svg', '78687.svg', 'f4a27.svg', '3bd3f.svg'];
            const active = ['8dca6.svg', '4437a.svg', 'c3b36.svg', '8a4fd.svg'];
            const labels = ['홈', '주문', '기기', '타이머'];
            return Expanded(
              child: Semantics(
                selected: selected == i,
                button: true,
                child: Material(
                  color: selected == i
                      ? const Color(0xFF434343)
                      : Colors.transparent,
                  child: InkWell(
                    key: Key('nav-$i'),
                    onTap: () => onChanged(i),
                    child: Column(
                      children: [
                        Container(
                          height: 4,
                          margin: const EdgeInsets.fromLTRB(2, 4, 2, 14),
                          decoration: BoxDecoration(
                            color: selected == i ? designAmber : designCard,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        SizedBox(
                          height: 33,
                          child: Center(
                            child: designAsset(
                              selected == i ? active[i] : normal[i],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          labels[i],
                          style: designText(
                            15,
                            color: selected == i ? designAmber : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    ),
  );
}

class DesignSummary extends StatelessWidget {
  const DesignSummary({super.key, required this.store});
  final KitchenStore store;
  Widget tile(String icon, String value, String label) => Expanded(
    child: SizedBox(
      height: 127,
      child: DesignCard(
        padding: const EdgeInsets.fromLTRB(19, 21, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            designAsset(icon),
            const SizedBox(height: 13),
            Text(value, style: designText(26)),
            const SizedBox(height: 6),
            Text(label, style: designText(13, color: const Color(0xFFB6B6B6))),
          ],
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Row(
    children: [
      tile(
        'a06f7.svg',
        '${store.devices.where((d) => d.power).length}개',
        '작동 중인 기기',
      ),
      const SizedBox(width: 9),
      tile(
        'b72fd.svg',
        '${store.devices.where((d) => d.running).length}개',
        '진행 중인 타이머',
      ),
    ],
  );
}

class DesignHome extends StatelessWidget {
  const DesignHome({
    super.key,
    required this.store,
    required this.go,
    required this.detail,
    required this.profile,
  });
  final KitchenStore store;
  final ValueChanged<int> go;
  final ValueChanged<KitchenDevice> detail;
  final VoidCallback profile;
  Widget section(String title, int tab) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 22, 4, 8),
    child: Row(
      children: [
        Expanded(child: Text(title, style: designText(20))),
        InkWell(
          onTap: () => go(tab),
          child: Text('전체 보기 >', style: designText(20, color: designMuted)),
        ),
      ],
    ),
  );
  Widget compactDevice(KitchenDevice d) => Expanded(
    child: SizedBox(
      height: 88,
      child: DesignCard(
        onTap: () => detail(d),
        padding: const EdgeInsets.fromLTRB(20, 14, 10, 7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(d.name, style: designText(18), maxLines: 1),
                ),
                designChevron(),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                designAsset(d.id == 'fan' ? '2d671.svg' : '003e6.svg'),
                const SizedBox(width: 3),
                Text(
                  d.power ? '작동 중' : '꺼짐',
                  style: designText(
                    14,
                    body: true,
                    color: d.power ? designAmber : designMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              d.id == 'fan'
                  ? '풍량 ${['약', '중', '강'][d.level.clamp(1, 3) - 1]}'
                  : '화력 ${d.level}',
              style: designText(10, body: true, color: const Color(0xFFCACACA)),
            ),
          ],
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final running = store.devices.where((d) => d.running).toList();
    final d = running.isEmpty ? store.devices[2] : running.first;
    final orders = store.orders.where((o) => o.status < 2).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(26, 26, 23, 36),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('반가워요! 춘식님!', style: designText(26)),
                    const SizedBox(height: 7),
                    Text(
                      '오늘은 조금 추워요!',
                      style: designText(16, color: const Color(0xFF8C8C8C)),
                    ),
                  ],
                ),
              ),
              InkWell(
                key: const Key('profile'),
                onTap: profile,
                customBorder: const CircleBorder(),
                child: SizedBox(
                  width: 65,
                  height: 65,
                  child: designAsset('1f6ab.png'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        DesignSummary(store: store),
        section('진행 중인 타이머', 3),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 107,
                child: DesignCard(
                  color: d.running ? designRunning : designCard,
                  onTap: () => go(3),
                  padding: const EdgeInsets.fromLTRB(20, 14, 18, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              d.name,
                              style: designText(18),
                              maxLines: 1,
                            ),
                          ),
                          designChevron(),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        clockText(d.seconds),
                        style: designText(25, body: true),
                      ),
                      const SizedBox(height: 3),
                      LinearProgressIndicator(
                        minHeight: 8,
                        value: (d.seconds / d.duration).clamp(0, 1),
                        color: designAmber,
                        backgroundColor: const Color(0xFF747474),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      Text(
                        '${clockText(d.duration)} 타이머 ${d.running ? '설정됨' : '대기'}',
                        style: designText(10, body: true),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: InkWell(
                onTap: () => go(3),
                borderRadius: BorderRadius.circular(30),
                child: SizedBox(
                  height: 107,
                  child: FittedBox(
                    fit: BoxFit.fill,
                    child: designAsset('f6c9c.svg'),
                  ),
                ),
              ),
            ),
          ],
        ),
        section('기기 제어', 2),
        Row(
          children: [
            compactDevice(store.devices[1]),
            const SizedBox(width: 9),
            compactDevice(store.devices[5]),
          ],
        ),
        section('주문 관리', 1),
        if (orders.isNotEmpty)
          SizedBox(
            height: 68,
            child: DesignCard(
              onTap: () => go(1),
              padding: const EdgeInsets.fromLTRB(23, 12, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    orders.first.items.split('\n').first,
                    style: designText(18),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    orders.first.status == 0 ? '접수 대기' : '조리 중',
                    style: designText(14, body: true, color: designAmber),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

String deviceAsset(KitchenDevice d, {bool large = false}) =>
    d.id.startsWith('gas')
    ? (large ? '1f97d.svg' : '79e5a.svg')
    : d.id.startsWith('microwave')
    ? (large ? 'aa760.svg' : '970f7.svg')
    : d.id == 'hood' || d.id == 'fan'
    ? '12602.svg'
    : '61ff5.svg';

class DesignDeviceGrid extends StatelessWidget {
  const DesignDeviceGrid({
    super.key,
    required this.store,
    required this.detail,
  });
  final KitchenStore store;
  final ValueChanged<KitchenDevice> detail;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(26, 21, 23, 26),
    children: [
      DesignSummary(store: store),
      const SizedBox(height: 48),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: store.devices.length - 1,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisExtent: 127,
          crossAxisSpacing: 9,
          mainAxisSpacing: 9,
        ),
        itemBuilder: (context, i) {
          final d = store.devices[i];
          return DesignCard(
            onTap: () => detail(d),
            color: d.running
                ? designRunning
                : d.power
                ? designCard
                : const Color(0xFF3D3D3D),
            padding: const EdgeInsets.fromLTRB(19, 25, 18, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.name, style: designText(20), maxLines: 1),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      width: 35,
                      height: 36,
                      decoration: BoxDecoration(
                        color: d.power ? designAmber : designMuted,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(child: deviceGlyph(d)),
                    ),
                    if (d.running)
                      Expanded(
                        child: Container(
                          height: 36,
                          color: const Color(0xFF303030),
                          alignment: Alignment.center,
                          child: Text(
                            clockText(d.seconds),
                            style: designText(20, body: true),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        d.power ? '켜짐' : '꺼짐',
                        style: designText(
                          14,
                          body: true,
                          color: d.power ? designAmber : designMuted,
                        ),
                      ),
                    ),
                    designChevron(),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    ],
  );
}

class DesignTimer extends StatelessWidget {
  const DesignTimer({
    super.key,
    required this.device,
    required this.store,
    this.header = true,
    this.expanded = true,
    this.toggle,
  });
  final KitchenDevice device;
  final KitchenStore store;
  final bool header, expanded;
  final VoidCallback? toggle;
  @override
  Widget build(BuildContext context) {
    final d = device;
    return DesignCard(
      color: d.running ? designRunning : designDarkCard,
      padding: const EdgeInsets.fromLTRB(10, 13, 10, 13),
      child: Column(
        children: [
          if (header)
            InkWell(
              onTap: toggle,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 7),
                child: Row(
                  children: [
                    Container(
                      width: 63,
                      height: 65,
                      decoration: BoxDecoration(
                        color: d.power ? designAmber : designMuted,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(child: deviceGlyph(d, large: true)),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d.name, style: designText(25)),
                          const SizedBox(height: 3),
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '상태  ',
                                  style: designText(
                                    20,
                                    body: true,
                                    color: const Color(0xFF989898),
                                  ),
                                ),
                                TextSpan(
                                  text: d.power ? '켜짐' : '꺼짐',
                                  style: designText(
                                    20,
                                    body: true,
                                    color: d.power ? designAmber : designMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (toggle != null)
                      RotatedBox(
                        quarterTurns: expanded ? 0 : 2,
                        child: designAsset(
                          expanded ? '228b7.svg' : '64fa8.svg',
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (expanded) ...[
            SizedBox(height: header ? 24 : 0),
            Padding(
              padding: const EdgeInsets.only(left: 5),
              child: Row(
                children: [
                  designAsset('79b5f.svg'),
                  const SizedBox(width: 20),
                  Text('타이머', style: designText(25, body: true)),
                ],
              ),
            ),
            if (d.running) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(48, 7, 0, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '남은 시간',
                    style: designText(
                      20,
                      body: true,
                      color: const Color(0xFFAEAEAE),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(48, 10, 0, 20),
                child: Row(
                  children: [
                    Text(
                      clockText(d.seconds),
                      style: designText(30, body: true),
                    ),
                    Text(
                      ' / ${clockText(d.duration)}',
                      style: designText(
                        20,
                        body: true,
                        color: const Color(0xFF767676),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: LinearProgressIndicator(
                  value: (d.seconds / d.duration).clamp(0, 1),
                  minHeight: 16,
                  color: designAmber,
                  backgroundColor: const Color(0xFF5C5C5C),
                  borderRadius: BorderRadius.circular(40),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => store.pause(d),
                    child: const Text(
                      '일시정지',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  TextButton(
                    onPressed: () => store.reset(d),
                    child: const Text(
                      '초기화',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 15),
              Container(
                height: 76,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF707070),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    _step('c29cc.svg', () => store.adjust(d, -30), '30초 줄이기'),
                    Expanded(
                      child: Center(
                        child: Text(
                          clockText(d.seconds),
                          style: designText(40, body: true),
                        ),
                      ),
                    ),
                    _step('8be44.svg', () => store.adjust(d, 30), '30초 늘리기'),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              Semantics(
                button: true,
                label: '타이머 시작',
                child: InkWell(
                  onTap: () => store.start(d),
                  customBorder: const CircleBorder(),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      designAsset('2c7d5.svg'),
                      Text('시작', style: designText(25, body: true)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _step(String asset, VoidCallback tap, String label) => Semantics(
    button: true,
    label: label,
    child: Material(
      color: const Color(0xFF505050),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: tap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: 80,
          height: 68,
          child: Center(child: designAsset(asset)),
        ),
      ),
    ),
  );
}

class DesignTimers extends StatelessWidget {
  const DesignTimers({
    super.key,
    required this.store,
    required this.expanded,
    required this.toggle,
  });
  final KitchenStore store;
  final String expanded;
  final ValueChanged<String> toggle;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(13, 19, 13, 26),
    children: store.devices
        .where(
          (d) =>
              d.id.startsWith('gas') ||
              d.id.startsWith('microwave') ||
              d.id.startsWith('timer'),
        )
        .map(
          (d) => Padding(
            padding: const EdgeInsets.only(bottom: 13),
            child: DesignTimer(
              device: d,
              store: store,
              expanded: expanded == d.id || d.running,
              toggle: () => toggle(d.id),
            ),
          ),
        )
        .toList(),
  );
}

class DesignDeviceDetail extends StatelessWidget {
  const DesignDeviceDetail({
    super.key,
    required this.device,
    required this.store,
    required this.back,
  });
  final KitchenDevice device;
  final KitchenStore store;
  final VoidCallback back;
  @override
  Widget build(BuildContext context) {
    final d = device;
    return ListView(
      padding: const EdgeInsets.fromLTRB(13, 14, 13, 26),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            onPressed: back,
            tooltip: '뒤로',
            icon: RotatedBox(quarterTurns: 3, child: designAsset('783a8.svg')),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 42, top: 4),
          child: Row(
            children: [
              Container(
                width: 63,
                height: 65,
                decoration: BoxDecoration(
                  color: d.power ? designAmber : designMuted,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(child: deviceGlyph(d, large: true)),
              ),
              const SizedBox(width: 13),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.name, style: designText(25)),
                  Text(
                    '상태  ${d.power ? '켜짐' : '꺼짐'}',
                    style: designText(
                      20,
                      body: true,
                      color: d.power ? designAmber : designMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 77),
        DesignCard(
          color: designDarkCard,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
          child: Row(
            children: [
              designAsset('97b55.svg'),
              const SizedBox(width: 21),
              Expanded(child: Text('전원', style: designText(25, body: true))),
              Switch(
                value: d.power,
                activeThumbColor: Colors.white,
                activeTrackColor: const Color(0xFF68D12D),
                onChanged: (v) => store.power(d, v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 9),
        if (d.id.startsWith('gas') || d.id == 'fan' || d.id == 'hood') ...[
          DesignCard(
            color: designDarkCard,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        d.id.startsWith('gas') ? '화력' : '풍량',
                        style: designText(25, body: true),
                      ),
                    ),
                    Text(
                      '${d.level}',
                      style: designText(25, body: true, color: designAmber),
                    ),
                  ],
                ),
                Slider(
                  value: d.level.toDouble(),
                  min: 1,
                  max: 3,
                  divisions: 2,
                  onChanged: d.power
                      ? (v) {
                          d.level = v.round();
                          store.changed();
                        }
                      : null,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: ['약', '중', '강']
                      .map(
                        (s) => Text(
                          s,
                          style: designText(18, body: true, color: designMuted),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
        ],
        DesignTimer(device: d, store: store, header: false),
      ],
    );
  }
}

class DesignOrders extends StatelessWidget {
  const DesignOrders({
    super.key,
    required this.store,
    required this.selected,
    required this.select,
    required this.reject,
  });
  final KitchenStore store;
  final int selected;
  final ValueChanged<int> select;
  final ValueChanged<KitchenOrder> reject;
  @override
  Widget build(BuildContext context) {
    final orders = store.orders
        .where((o) => selected == 2 ? o.status >= 2 : o.status == selected)
        .toList();
    return ListView(
      padding: const EdgeInsets.only(top: 32, bottom: 26),
      children: [
        Row(
          children: List.generate(3, (i) {
            final count = store.orders
                .where((o) => i == 2 ? o.status >= 2 : o.status == i)
                .length;
            return Expanded(
              child: InkWell(
                onTap: () => select(i),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          ['접수 대기', '진행 중', '완료'][i],
                          style: designText(
                            15,
                            body: true,
                            color: i == selected ? designAmber : designCard,
                          ),
                        ),
                        if (i < 2) ...[
                          const SizedBox(width: 5),
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              designAsset(
                                i == selected ? '36c25.svg' : 'b6090.svg',
                              ),
                              Text('$count', style: designText(15, body: true)),
                            ],
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 7,
                      decoration: BoxDecoration(
                        color: i == selected
                            ? designAmber
                            : const Color(0xFF616161),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 27),
        if (orders.isEmpty)
          Padding(
            padding: const EdgeInsets.all(26),
            child: Text(
              '해당하는 주문이 없습니다',
              style: designText(16, body: true, color: designMuted),
            ),
          ),
        ...orders.map(
          (o) => Padding(
            padding: const EdgeInsets.fromLTRB(23, 0, 23, 14),
            child: DesignCard(
              color: const Color(0xFF4C4C4C),
              padding: const EdgeInsets.fromLTRB(13, 12, 16, 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 7),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '주문 #${o.number}',
                            style: designText(
                              14,
                              body: true,
                              color: const Color(0xFF969696),
                            ),
                          ),
                        ),
                        Text(
                          o.time,
                          style: designText(
                            14,
                            body: true,
                            color: const Color(0xFF969696),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 3),
                  Padding(
                    padding: const EdgeInsets.only(left: 7),
                    child: Text(o.items, style: designText(23, body: true)),
                  ),
                  const SizedBox(height: 30),
                  if (o.status == 0)
                    Row(
                      children: [
                        Expanded(
                          flex: 128,
                          child: _button(
                            '거절',
                            const Color(0xFFA7A7A7),
                            () => reject(o),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          flex: 186,
                          child: _button('주문 수락', designAmber, () {
                            o.status = 1;
                            store.changed();
                          }),
                        ),
                      ],
                    )
                  else if (o.status == 1)
                    _button('조리 완료', designAmber, () {
                      o.status = 2;
                      store.changed();
                    })
                  else
                    Text(
                      o.status == 3 ? '취소된 주문' : '조리가 완료되었습니다',
                      style: designText(18, body: true, color: designAmber),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _button(String label, Color color, VoidCallback tap) => SizedBox(
    height: 48,
    width: double.infinity,
    child: FilledButton(
      onPressed: tap,
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: Text(label, style: designText(24, body: true)),
    ),
  );
}

class DesignSplash extends StatelessWidget {
  const DesignSplash({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: designBackground,
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, c) => Column(
          children: [
            SizedBox(height: c.maxHeight * .27),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 11),
              child: Image.asset(
                'assets/figma/dcfaa.png',
                height: 189,
                fit: BoxFit.contain,
              ),
            ),
            SizedBox(height: c.maxHeight * .11),
            SizedBox(width: 81, height: 81, child: designAsset('8c099.png')),
            Text(
              '말로 관리하고,\n더욱 빠른 주방을',
              textAlign: TextAlign.center,
              style: designText(25),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget deviceGlyph(KitchenDevice d, {bool large = false}) {
  if (d.id.startsWith('gas') ||
      d.id.startsWith('microwave') ||
      d.id == 'hood' ||
      d.id == 'fan') {
    return designAsset(deviceAsset(d, large: large));
  }
  return Icon(d.icon, size: large ? 32 : 22, color: Colors.white);
}
