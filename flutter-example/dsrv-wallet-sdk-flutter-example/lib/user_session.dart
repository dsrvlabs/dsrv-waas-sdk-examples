import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _keyUserId = 'user_id';

Future<String> loadUserId() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_keyUserId) ?? '';
}

Future<void> saveUserId(String userId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_keyUserId, userId);
}

Future<void> clearUserId() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_keyUserId);
}

/// example 전용: 사용자 입력 [userId] 를 결정적 UUID 로 변환.
///
/// 알고리즘: MD5("dsrv-wallet-example:" + userId.trim()) → version-3 UUID 비트 설정.
/// Android 의 `Wallet.userIdToUuid` (Java `UUID.nameUUIDFromBytes`) 및 iOS 의
/// `Wallet.userIdToUuid` 와 byte-identical 한 결과를 만든다 — 같은 userId 면 어느 플랫폼에서든
/// 동일한 UUID 가 도출되어 cross-platform 테스트가 가능하다.
String userIdToUuid(String userId) {
  if (userId.trim().isEmpty) return '';
  final seed = utf8.encode('dsrv-wallet-example:${userId.trim()}');
  final h = md5.convert(seed).bytes.toList();
  // RFC 4122 v3: version=0011 in byte 6, variant=10xx in byte 8
  h[6] = (h[6] & 0x0F) | 0x30;
  h[8] = (h[8] & 0x3F) | 0x80;
  String hex2(int b) => b.toRadixString(16).padLeft(2, '0');
  final hex = h.map(hex2).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-${hex.substring(20, 32)}';
}
