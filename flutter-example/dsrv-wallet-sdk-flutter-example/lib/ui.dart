import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 네이티브 example 의 SectionCard 에 대응 — 제목/부제 + 내용 카드.
class SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;

  const SectionCard(this.title, {super.key, this.subtitle, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
          ],
          const SizedBox(height: 12),
          ...children.expand((w) => [w, const SizedBox(height: 10)]),
        ],
      ),
    );
  }
}

/// 비동기 동작 버튼 — 로딩 시 스피너 (iOS AsyncButton 대응).
class AsyncButton extends StatelessWidget {
  final String title;
  final bool isEnabled;
  final bool isLoading;
  final VoidCallback onPressed;
  final Color? color;

  const AsyncButton({
    super.key,
    required this.title,
    this.isEnabled = true,
    this.isLoading = false,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton(
        style: color != null ? FilledButton.styleFrom(backgroundColor: color) : null,
        onPressed: (!isEnabled || isLoading) ? null : onPressed,
        child: isLoading
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class ErrorLine extends StatelessWidget {
  final String message;
  const ErrorLine(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text('⚠ $message',
          style: const TextStyle(fontSize: 12, color: Colors.red)),
    );
  }
}

/// 복사 가능한 모노스페이스 텍스트 박스 (네이티브 CopyableText 대응).
class CopyableText extends StatelessWidget {
  final String text;
  const CopyableText(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: text));
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Copied!'), duration: Duration(seconds: 1)));
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(text,
                  style: TextStyle(
                      fontSize: 12, fontFamily: 'monospace', color: Theme.of(context).hintColor)),
            ),
            const Icon(Icons.copy, size: 16),
          ],
        ),
      ),
    );
  }
}

/// 라벨/값 한 줄 (네이티브 KeyValueRow 대응).
class KeyValueRow extends StatelessWidget {
  final String label;
  final String value;
  const KeyValueRow(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 82,
            child: Text(label,
                style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
          ),
          Expanded(
            child: SelectableText(value.isEmpty ? '-' : value,
                style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

/// 입력 필드.
class Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboard;
  final int maxLines;
  const Field(this.controller, this.hint, {super.key, this.keyboard, this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}

/// chain 별 bulk operation 결과 list 의 summary 한 줄 (success/failed count).
class ChainResultSummary extends StatelessWidget {
  final List<dynamic> results;
  const ChainResultSummary({super.key, required this.results});

  @override
  Widget build(BuildContext context) {
    final successes = results.where((r) => r.isSuccess == true).length;
    final failures = results.length - successes;
    return Text(
      '결과: success=$successes / failed=$failures (총 ${results.length} chains)',
      style: const TextStyle(fontSize: 11),
    );
  }
}

/// chain 별 결과 한 entry — outcome 별로 분기:
/// - FAILED: chainId + errorMessage (빨강)
/// - NEW/BUILT/RESUMED (txHash 있음): chainId + outcome 라벨 + txHash
/// - ALREADY_DELEGATED/SKIPPED (txHash 없음): chainId + outcome 라벨만
class ChainResultLine extends StatelessWidget {
  final dynamic result;
  const ChainResultLine({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final String outcome = result.outcome as String;
    if (outcome == 'FAILED') {
      return Text(
        '✗ ${result.chainId} [FAILED]: ${result.errorMessage ?? "unknown"}',
        style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.error),
      );
    }
    final String? txHash = result.txHash as String?;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('✓ ${result.chainId} [$outcome]', style: const TextStyle(fontSize: 11)),
        if (txHash != null) CopyableText(txHash),
      ],
    );
  }
}
