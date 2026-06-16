/// 금액 단위 변환 유틸.
///
/// Android [`Amount.kt`](../../android/dsrv-wallet-sdk-android-example/app/src/main/java/com/dsrv/wallet/example/wallet/model/Amount.kt)
/// 대응. 기존 `token_config.dart` 에 있던 [fromBaseUnits] 를 분리해 옮긴 것 (RPC/TokenConfig 제거 후에도 보존).
library;

/// base units BigInt → 사람이 읽는 십진 표기. 뒤쪽 0 은 trim, 정수면 "." 도 제거.
///
/// fromBaseUnits(BigInt.parse("100000"), 6) == "0.1"
/// fromBaseUnits(BigInt.parse("1000000"), 6) == "1"
String fromBaseUnits(BigInt amount, int decimals) {
  if (decimals <= 0) return amount.toString();
  final s = amount.toString().padLeft(decimals + 1, '0');
  final whole = s.substring(0, s.length - decimals);
  final frac = s.substring(s.length - decimals).replaceFirst(RegExp(r'0+$'), '');
  return frac.isEmpty ? whole : '$whole.$frac';
}
