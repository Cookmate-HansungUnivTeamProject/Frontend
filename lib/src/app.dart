import 'dart:async';

import 'package:flutter/material.dart';

import 'store.dart';
import 'voice.dart';
import 'figma_ui.dart';

const amber = Color(0xFFFAA614);
const background = Color(0xFF262626);
const panel = Color(0xFF383838);
const muted = Color(0xFFADADAD);

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.store, this.voice, this.showSplash = true});
  final KitchenStore? store;
  final VoiceController? voice;
  final bool showSplash;
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final KitchenStore store = widget.store ?? KitchenStore();
  late final VoiceController voice = widget.voice ?? VoiceController();
  @override
  void initState() {
    super.initState();
    if (widget.voice == null) voice.connect();
  }

  @override
  void dispose() {
    if (widget.store == null) store.dispose();
    if (widget.voice == null) voice.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'ORVO · 주방의 새로운 흐름',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      fontFamily: 'GmarketSans',
      textTheme: ThemeData.dark().textTheme.apply(
        fontFamily: 'GmarketSans',
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: amber,
        brightness: Brightness.dark,
        primary: amber,
        surface: panel,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
      ),
      dividerColor: Colors.white12,
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: panel,
        contentTextStyle: TextStyle(color: Colors.white),
      ),
    ),
    builder: (context, child) => ListenableBuilder(
      listenable: voice,
      builder: (context, _) => Stack(
        children: [
          child!,
          if (voice.visible)
            Positioned(
              left: 20,
              right: 20,
              bottom: MediaQuery.of(context).padding.bottom + 88,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: VoiceCard(voice: voice),
                ),
              ),
            ),
        ],
      ),
    ),
    home: KitchenShell(
      store: store,
      voice: voice,
      showSplash: widget.showSplash,
    ),
  );
}

class KitchenShell extends StatefulWidget {
  const KitchenShell({
    super.key,
    required this.store,
    required this.voice,
    required this.showSplash,
  });
  final KitchenStore store;
  final VoiceController voice;
  final bool showSplash;
  @override
  State<KitchenShell> createState() => _KitchenShellState();
}

class _KitchenShellState extends State<KitchenShell> {
  int tab = 0;
  int orderTab = 0;
  bool settings = false;
  KitchenDevice? selected;
  late bool splash = widget.showSplash;
  Timer? splashTimer;
  String expanded = 'gas_1';
  KitchenStore get store => widget.store;
  @override
  void initState() {
    super.initState();
    store.addListener(showNotice);
    if (splash) {
      splashTimer = Timer(const Duration(milliseconds: 1800), () {
        if (mounted) setState(() => splash = false);
      });
    }
  }

  @override
  void dispose() {
    store.removeListener(showNotice);
    splashTimer?.cancel();
    super.dispose();
  }

  /// 서버가 거절한 이유(이미 처리한 주문, 시간 규칙 등)를 아래에 잠깐 띄운다.
  void showNotice() {
    final text = store.takeNotice();
    if (text == null || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> editServer() async {
    final value = await showDialog<String>(
      context: context,
      builder: (context) => ServerDialog(initial: store.apiBase),
    );
    if (value != null && value.trim().isNotEmpty) {
      await store.setApiBase(value);
    }
  }

  Widget offlineBar() => Material(
    color: const Color(0xFF7A2E2E),
    child: InkWell(
      onTap: () => setState(() {
        settings = true;
        selected = null;
      }),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.cloud_off, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '서버 연결 안 됨 · ${store.apiBase} (눌러서 주소 바꾸기)',
                style: const TextStyle(fontSize: 12),
                maxLines: 2,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  void go(int value) => setState(() {
    tab = value;
    settings = false;
    selected = null;
  });
  void detail(KitchenDevice device) => setState(() {
    tab = 2;
    selected = device;
    settings = false;
  });
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      if (splash) return const DesignSplash();
      return PopScope(
        canPop: !settings && selected == null,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            setState(() {
              settings = false;
              selected = null;
            });
          }
        },
        child: Scaffold(
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  children: [
                    if (!store.connected && store.error != null) offlineBar(),
                    Expanded(
                      child: settings
                          ? settingsPage()
                          : selected != null
                          ? DesignDeviceDetail(
                              device: selected!,
                              store: store,
                              back: () => setState(() => selected = null),
                            )
                          : switch (tab) {
                              0 => DesignHome(
                                store: store,
                                go: go,
                                detail: detail,
                                profile: () => setState(() => settings = true),
                              ),
                              1 => DesignOrders(
                                store: store,
                                selected: orderTab,
                                select: (i) => setState(() => orderTab = i),
                                reject: rejectOrder,
                              ),
                              2 => DesignDeviceGrid(
                                store: store,
                                detail: detail,
                              ),
                              _ => DesignTimers(
                                store: store,
                                expanded: expanded,
                                toggle: (id) => setState(
                                  () => expanded = expanded == id ? '' : id,
                                ),
                              ),
                            },
                    ),
                  ],
                ),
              ),
            ),
          ),
          bottomNavigationBar: DesignNavigation(selected: tab, onChanged: go),
        ),
      );
    },
  );
  Widget page(List<Widget> children) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
    children: children,
  );
  Widget title(String text, {String? subtitle, VoidCallback? back}) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Row(
      children: [
        if (back != null)
          IconButton(
            onPressed: back,
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            tooltip: '뒤로',
          ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
            ],
          ),
        ),
      ],
    ),
  );
  Future<void> rejectOrder(KitchenOrder order) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('주문을 거절할까요?'),
        content: Text('#${order.number} 주문이 취소 목록으로 이동합니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('돌아가기'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('거절'),
          ),
        ],
      ),
    );
    if (result == true) {
      await store.reject(order);
    }
  }

  Widget settingsPage() => page([
    title(
      '설정',
      subtitle: '나에게 맞는 주방으로',
      back: () => setState(() => settings = false),
    ),
    const Box(
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Color(0xFF66503B),
            child: Icon(Icons.person, color: Color(0xFFE5C6A3)),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('준셰프', style: TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  'ORVO 데모 주방',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 24),
    const Text('서버', style: TextStyle(color: muted, fontSize: 12)),
    const SizedBox(height: 8),
    Box(
      child: Row(
        children: [
          Icon(
            store.connected ? Icons.cloud_done_outlined : Icons.cloud_off,
            size: 20,
            color: store.connected ? amber : muted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(store.apiBase, style: const TextStyle(fontSize: 14)),
                Text(
                  store.connected ? '연결됨' : (store.error ?? '연결 확인 중'),
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(onPressed: editServer, child: const Text('바꾸기')),
        ],
      ),
    ),
    const SizedBox(height: 24),
    const Text('일반', style: TextStyle(color: muted, fontSize: 12)),
    const SizedBox(height: 8),
    Box(
      child: Column(
        children: [
          settingSwitch(Icons.notifications_none, '알림', store.notifications, (
            v,
          ) {
            store.notifications = v;
            store.changed();
          }),
          settingSwitch(Icons.volume_up_outlined, '효과음', store.sound, (v) {
            store.sound = v;
            store.changed();
          }),
          settingSwitch(Icons.vibration, '진동', store.vibration, (v) {
            store.vibration = v;
            store.changed();
          }),
        ],
      ),
    ),
    const SizedBox(height: 24),
    const Text('음성 비서', style: TextStyle(color: muted, fontSize: 12)),
    const SizedBox(height: 8),
    ListenableBuilder(
      listenable: widget.voice,
      builder: (context, _) => Box(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            settingSwitch(
              Icons.graphic_eq,
              '“오르보”로 부르기',
              widget.voice.enabled,
              (v) => widget.voice.setEnabled(v),
            ),
            Text(
              widget.voice.connected ? '온디바이스 엔진 연결됨' : '온디바이스 엔진 연결 대기',
              style: const TextStyle(color: muted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            const Text(
              '오르보를 부르면 어느 화면에서든 음성 패널이 나타납니다.',
              style: TextStyle(fontSize: 12, color: muted, height: 1.6),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: widget.voice.enabled ? widget.voice.preview : null,
              icon: const Icon(Icons.mic_none),
              label: const Text('음성 UI 미리보기'),
            ),
          ],
        ),
      ),
    ),
    const SizedBox(height: 24),
    const Text('앱 정보', style: TextStyle(color: muted, fontSize: 12)),
    const SizedBox(height: 8),
    const Box(
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 20),
              SizedBox(width: 10),
              Expanded(child: Text('앱 버전')),
              Text('1.0.0', style: TextStyle(color: muted)),
            ],
          ),
          SizedBox(height: 14),
          Text(
            '기기·타이머·주문은 백엔드 서버에서 1초마다 받아옵니다. 알림·효과음·진동 설정은 앱을 종료하면 초기화됩니다. 실제 마이크 수집은 연결된 엔진에서 처리합니다.',
            style: TextStyle(fontSize: 12, color: muted, height: 1.6),
          ),
        ],
      ),
    ),
  ]);
  Widget settingSwitch(
    IconData icon,
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) => Row(
    children: [
      Icon(icon, size: 20),
      const SizedBox(width: 10),
      Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
      Switch(value: value, onChanged: onChanged),
    ],
  );
}

/// 설정의 서버 주소 바꾸기. 저장하면 주소 문자열을 돌려준다.
class ServerDialog extends StatefulWidget {
  const ServerDialog({super.key, required this.initial});
  final String initial;
  @override
  State<ServerDialog> createState() => _ServerDialogState();
}

class _ServerDialogState extends State<ServerDialog> {
  late final controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('서버 주소'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            hintText: 'http://192.168.0.10:8000',
          ),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        const SizedBox(height: 10),
        const Text(
          '같은 PC: http://127.0.0.1:8000 · 에뮬레이터: http://10.0.2.2:8000 · 실제 폰: 백엔드 PC의 IP',
          style: TextStyle(color: muted, fontSize: 12, height: 1.5),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('취소'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, controller.text),
        child: const Text('저장'),
      ),
    ],
  );
}

class Box extends StatelessWidget {
  const Box({super.key, required this.child, this.color = panel});
  final Widget child;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(18),
    ),
    child: child,
  );
}

class VoiceCard extends StatelessWidget {
  const VoiceCard({super.key, required this.voice});
  final VoiceController voice;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 10, 18),
      decoration: BoxDecoration(
        color: const Color(0xFF424242),
        border: Border.all(color: amber.withValues(alpha: .65)),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Semantics(
        liveRegion: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.graphic_eq, color: amber, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    voice.phase == 'processing'
                        ? '생각하고 있어요'
                        : voice.phase == 'error'
                        ? '다시 말씀해 주세요'
                        : voice.phase == 'response'
                        ? '응답'
                        : '듣고 있어요',
                    style: const TextStyle(color: muted, fontSize: 11),
                  ),
                ),
                const Text(
                  'ORVO',
                  style: TextStyle(
                    color: amber,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                IconButton(
                  onPressed: voice.hide,

                  icon: const Icon(
                    Icons.close,
                    size: 18,
                    semanticLabel: '음성 패널 닫기',
                  ),
                ),
              ],
            ),
            Text(
              voice.response.isNotEmpty
                  ? voice.response
                  : voice.transcript.isNotEmpty
                  ? voice.transcript
                  : '네, 말씀해 주세요.',
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
          ],
        ),
      ),
    ),
  );
}
