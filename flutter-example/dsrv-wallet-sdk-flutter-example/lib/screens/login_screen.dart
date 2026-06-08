import 'package:flutter/material.dart';

import '../config.dart';
import '../ui.dart';
import '../user_session.dart';
import '../wallet_state.dart';

/// Android `LoginScreen` (WalletScreen.kt 내부) / iOS `LoginScreen` (WalletScreen.swift 내부)
/// 와 동일 — userId 입력 → 결정적 UUID 미리보기 → SDK 초기화 → 성공 시 [onLogin].
class LoginScreen extends StatefulWidget {
  final WalletState wallet;
  final VoidCallback onLogin;
  const LoginScreen({super.key, required this.wallet, required this.onLogin});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final TextEditingController _ctrl;
  String _derived = '';
  bool _attempted = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.wallet.userId);
    _derived = userIdToUuid(_ctrl.text.trim());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String v) => setState(() => _derived = userIdToUuid(v.trim()));

  Future<void> _login() async {
    final input = _ctrl.text.trim();
    if (input.isEmpty) return;
    _attempted = true;
    if (input != widget.wallet.userId) {
      await widget.wallet.changeUserId(input);
    }
    if (widget.wallet.initialized) {
      widget.onLogin();
    } else {
      await widget.wallet.initialize();
      if (widget.wallet.initialized) widget.onLogin();
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = widget.wallet;
    final hint = Theme.of(context).hintColor;
    return Scaffold(
      appBar: AppBar(title: const Text('로그인')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('사용자 식별', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('임의의 userId 를 입력하면 결정적 UUID 가 생성됩니다.',
                style: TextStyle(fontSize: 13, color: hint)),
            const SizedBox(height: 16),

            // userId 입력 + 생성된 UUID
            SectionCard(
              'userId',
              children: [
                TextField(
                  controller: _ctrl,
                  onChanged: _onChanged,
                  onSubmitted: (_) => _login(),
                  decoration: InputDecoration(
                    hintText: '예: alice@example.com',
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('생성된 UUID',
                      style: TextStyle(fontSize: 11, color: hint)),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _derived.isEmpty ? 'userId 를 입력하세요' : _derived,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ],
            ),

            // SDK / 백엔드 정보
            SectionCard(
              'SDK / 백엔드',
              children: [
                KeyValueRow('SDK ID', AppConfig.sdkId),
                KeyValueRow('Backend', AppConfig.customerBackendUrl),
              ],
            ),

            AsyncButton(
              title: '로그인',
              isEnabled: _derived.isNotEmpty,
              isLoading: wallet.initializing,
              onPressed: _login,
            ),

            if (_attempted && wallet.initError != null) ...[
              const SizedBox(height: 8),
              ErrorLine(wallet.initError!),
            ],

            if (wallet.userId.isNotEmpty) ...[
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    wallet.resetWallet();
                    _ctrl.clear();
                    setState(() => _derived = '');
                  },
                  child: const Text('저장된 사용자 초기화'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
