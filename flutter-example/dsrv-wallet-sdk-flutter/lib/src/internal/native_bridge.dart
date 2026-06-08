import 'package:flutter/services.dart';

import '../handlers.dart';
import '../wallet_error.dart';

/// native DSRVWallet SDK 로의 MethodChannel 브릿지.
///
/// - 정방향: Dart → native (`invoke`)
/// - 역방향: native → Dart (`onRequestChallenge`) — AuthHandler challenge 요청
class NativeBridge {
  NativeBridge._();

  static const MethodChannel _channel =
      MethodChannel('com.dsrv.wallet.sdk/api');

  static AuthHandler? _authHandler;
  static bool _callbackRegistered = false;

  /// initialize 시 현재 AuthHandler 등록 + 역방향 콜백 핸들러 1회 설치.
  static void setAuthHandler(AuthHandler handler) {
    _authHandler = handler;
    if (!_callbackRegistered) {
      _channel.setMethodCallHandler(_handleNativeCall);
      _callbackRegistered = true;
    }
  }

  /// native 가 Dart 로 역방향 호출하는 진입점.
  static Future<dynamic> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onRequestChallenge':
        final handler = _authHandler;
        if (handler == null) {
          return {'success': false, 'error': 'No AuthHandler registered'};
        }
        final req =
            ChallengeRequest.fromMap((call.arguments as Map?) ?? const {});
        final result = await handler.requestChallenge(req);
        return {
          'success': result.success,
          'challenge': result.challenge,
          'error': result.error,
        };
      default:
        throw MissingPluginException('Unknown native call: ${call.method}');
    }
  }

  /// 정방향 호출. native 실패는 PlatformException → WalletError 로 변환해 throw.
  static Future<T?> invoke<T>(String method,
      [Map<String, dynamic>? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on PlatformException catch (e) {
      throw WalletError.fromPlatform(e.code, e.message, e);
    }
  }

  /// Map 반환 호출.
  static Future<Map<dynamic, dynamic>?> invokeMap(String method,
      [Map<String, dynamic>? args]) async {
    try {
      return await _channel.invokeMapMethod<dynamic, dynamic>(method, args);
    } on PlatformException catch (e) {
      throw WalletError.fromPlatform(e.code, e.message, e);
    }
  }

  /// List 반환 호출.
  static Future<List<dynamic>?> invokeList(String method,
      [Map<String, dynamic>? args]) async {
    try {
      return await _channel.invokeListMethod<dynamic>(method, args);
    } on PlatformException catch (e) {
      throw WalletError.fromPlatform(e.code, e.message, e);
    }
  }
}
