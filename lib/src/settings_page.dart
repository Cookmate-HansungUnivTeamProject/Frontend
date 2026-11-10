import 'package:flutter/material.dart';

import 'figma_ui.dart';
import 'store.dart';
import 'voice.dart';
import 'wake_engine.dart';

/// 설정 화면: 서버 주소, 알림, 음성 비서("오르보"), 계정, 앱 정보.
class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.store,
    required this.voice,
    required this.onBack,
    this.wake,
  });

  final KitchenStore store;
  final VoiceController voice;
  final VoidCallback onBack;

  /// "오르보" 호출어 엔진. 안드로이드 실제 앱에서만 있다(테스트·웹에서는 null).
  final WakeEngine? wake;

  Future<void> _editServer(BuildContext context) async {
    final value = await showDialog<String>(
      context: context,
      builder: (context) => ServerDialog(initial: store.apiBase),
    );
    if (value != null && value.trim().isNotEmpty) {
      await store.setApiBase(value);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
    children: [
      _Header(onBack: onBack),
      const SizedBox(height: 20),
      const _ProfileCard(),
      const SizedBox(height: 24),
      const _SectionTitle('서버'),
      const SizedBox(height: 8),
      DesignCard(
        key: const Key('server-setting'),
        color: designDarkCard,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              store.connected ? Icons.cloud_done_outlined : Icons.cloud_off,
              size: 20,
              color: store.connected ? designAmber : designMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(store.apiBase, style: designText(14, body: true)),
                  const SizedBox(height: 2),
                  Text(
                    store.connected ? '연결됨' : (store.error ?? '연결 확인 중'),
                    style: designText(12, body: true, color: designMuted),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => _editServer(context),
              child: const Text('바꾸기'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      const _SectionTitle('일반'),
      const SizedBox(height: 8),
      DesignCard(
        color: designDarkCard,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            _SettingSwitchTile(
              key: const Key('notification-setting'),
              icon: Icons.notifications_none,
              label: '알림',
              value: store.notifications,
              onChanged: (value) {
                store.notifications = value;
                store.changed();
              },
            ),
            _SettingSwitchTile(
              key: const Key('sound-setting'),
              icon: Icons.volume_up_outlined,
              label: '효과음',
              value: store.sound,
              onChanged: (value) {
                store.sound = value;
                store.changed();
              },
            ),
            _SettingSwitchTile(
              key: const Key('vibration-setting'),
              icon: Icons.vibration,
              label: '진동',
              value: store.vibration,
              onChanged: (value) {
                store.vibration = value;
                store.changed();
              },
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      const _SectionTitle('음성 비서'),
      const SizedBox(height: 8),
      ListenableBuilder(
        listenable: voice,
        builder: (context, _) => DesignCard(
          color: designDarkCard,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SettingSwitchTile(
                key: const Key('voice-setting'),
                icon: Icons.graphic_eq,
                label: '“오르보”로 부르기',
                value: voice.enabled,
                onChanged: voice.setEnabled,
              ),
              Text(
                voice.connected ? '온디바이스 엔진 연결됨' : '온디바이스 엔진 연결 대기',
                style: designText(12, body: true, color: designMuted),
              ),
              if (wake != null) _WakeStatus(wake: wake!),
              const SizedBox(height: 12),
              Text(
                '오르보를 부르면 어느 화면에서든 음성 패널이 나타납니다.',
                style: designText(
                  12,
                  body: true,
                  color: designMuted,
                ).copyWith(height: 1.6),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: voice.enabled ? voice.preview : null,
                icon: const Icon(Icons.mic_none),
                label: const Text('음성 UI 미리보기'),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 24),
      const _SectionTitle('계정'),
      const SizedBox(height: 8),
      DesignCard(
        color: designDarkCard,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            const _SettingRow(
              icon: Icons.person_outline,
              label: '사용자 정보',
              trailing: '데모 계정',
            ),
            const Divider(height: 1),
            _SettingRow(
              key: const Key('logout-setting'),
              icon: Icons.logout,
              label: '로그아웃',
              labelColor: designAmber,
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('로그인 기능 연결 후 사용할 수 있어요.')),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      const _SectionTitle('앱 정보'),
      const SizedBox(height: 8),
      DesignCard(
        color: designDarkCard,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const _SettingRow(
              icon: Icons.info_outline,
              label: '앱 버전',
              trailing: '1.0.0',
            ),
            const SizedBox(height: 14),
            Text(
              '기기·타이머·주문은 백엔드 서버에서 1초마다 받아옵니다. '
              '알림·효과음·진동 설정은 앱을 종료하면 초기화되고, 계정은 아직 데모입니다. '
              '음성은 휴대폰 안의 엔진이 글자로 바꾸고, 명령 해석은 서버가 처리합니다.',
              style: designText(
                12,
                body: true,
                color: designMuted,
              ).copyWith(height: 1.6),
            ),
          ],
        ),
      ),
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
          style: TextStyle(color: designMuted, fontSize: 12, height: 1.5),
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

/// 호출어 엔진 상태와 테스트 기록 버튼(안드로이드 실제 앱에서만 보임).
class _WakeStatus extends StatelessWidget {
  const _WakeStatus({required this.wake});

  final WakeEngine wake;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: wake,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        Text(
          wake.message.isEmpty ? '꺼짐' : wake.message,
          style: designText(
            12,
            body: true,
            color: wake.status == WakeStatus.error
                ? Colors.orangeAccent
                : designMuted,
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => WakeLogPage(engine: wake)),
          ),
          icon: const Icon(Icons.list_alt),
          label: Text('호출어 테스트 기록 (${wake.log.length})'),
        ),
      ],
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        onPressed: onBack,
        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
        tooltip: '뒤로',
      ),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('설정', style: designText(22)),
            Text(
              '나에게 맞는 주방으로',
              style: designText(12, body: true, color: designMuted),
            ),
          ],
        ),
      ),
    ],
  );
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard();

  @override
  Widget build(BuildContext context) => DesignCard(
    color: designDarkCard,
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        const CircleAvatar(
          backgroundColor: Color(0xFF66503B),
          child: Icon(Icons.person, color: Color(0xFFE5C6A3)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('준셰프', style: designText(14)),
              const SizedBox(height: 2),
              Text(
                'ORVO 데모 주방',
                style: designText(12, body: true, color: designMuted),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) =>
      Text(label, style: designText(12, body: true, color: designMuted));
}

class _SettingSwitchTile extends StatelessWidget {
  const _SettingSwitchTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 48),
    child: Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: designText(14, body: true))),
        Switch(value: value, onChanged: onChanged),
      ],
    ),
  );
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    super.key,
    required this.icon,
    required this.label,
    this.trailing,
    this.labelColor,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String? trailing;
  final Color? labelColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: SizedBox(
      height: 48,
      child: Row(
        children: [
          Icon(icon, size: 20, color: labelColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: designText(
                14,
                body: true,
                color: labelColor ?? Colors.white,
              ),
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: designText(12, body: true, color: designMuted),
            ),
        ],
      ),
    ),
  );
}
