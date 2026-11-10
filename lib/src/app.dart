import 'dart:async';

import 'package:flutter/material.dart';

import 'store.dart';
import 'voice.dart';
import 'figma_ui.dart';
import 'settings_page.dart';

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
  String expanded = 'gas-2';
  KitchenStore get store => widget.store;
  @override
  void initState() {
    super.initState();
    if (splash) {
      splashTimer = Timer(const Duration(milliseconds: 1800), () {
        if (mounted) setState(() => splash = false);
      });
    }
  }

  @override
  void dispose() {
    splashTimer?.cancel();
    super.dispose();
  }

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
                child: settings
                    ? SettingsPage(
                        store: store,
                        voice: widget.voice,
                        onBack: () => setState(() => settings = false),
                      )
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
                        2 => DesignDeviceGrid(store: store, detail: detail),
                        _ => DesignTimers(
                          store: store,
                          expanded: expanded,
                          toggle: (id) => setState(
                            () => expanded = expanded == id ? '' : id,
                          ),
                        ),
                      },
              ),
            ),
          ),
          bottomNavigationBar: DesignNavigation(selected: tab, onChanged: go),
        ),
      );
    },
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
      order.status = 3;
      store.changed();
    }
  }
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
