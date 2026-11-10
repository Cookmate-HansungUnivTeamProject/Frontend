import 'package:flutter/material.dart';

import 'figma_ui.dart';
import 'store.dart';
import 'voice.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.store,
    required this.voice,
    required this.onBack,
  });

  final KitchenStore store;
  final VoiceController voice;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
    children: [
      _Header(onBack: onBack),
      const SizedBox(height: 20),
      const _ProfileCard(),
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
              '기기·주문 데이터와 설정은 데모이며 앱을 종료하면 초기화됩니다. '
              '실제 계정과 마이크 처리는 연결된 서버 및 온디바이스 엔진에서 처리합니다.',
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
