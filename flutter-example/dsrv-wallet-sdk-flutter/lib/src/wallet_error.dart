/// 에러 타입 — native WalletError 의 코드 체계와 1:1.
///
/// 브릿지(MethodChannel)는 native 실패 시 `PlatformException(code, message)`
/// 로 전달하며, [WalletError.fromPlatform] 가 이를 복원한다.
class WalletError implements Exception {
  final int code;
  final String message;
  final Object? cause;

  const WalletError(this.code, this.message, [this.cause]);

  factory WalletError.notInitialized() =>
      const WalletError(1001, 'SDK not initialized');
  factory WalletError.authFailed(String detail) =>
      WalletError(2001, 'Auth failed: $detail');
  factory WalletError.tokenExpired() =>
      const WalletError(2002, 'Token expired');
  factory WalletError.deviceIntegrityFailed(String detail) =>
      WalletError(2003, 'Device integrity failed: $detail');
  factory WalletError.challengeFailed(String detail) =>
      WalletError(2004, 'Challenge request failed: $detail');
  factory WalletError.walletNotFound() =>
      const WalletError(3001, 'Wallet not found');
  factory WalletError.keygenFailed(String detail, [Object? cause]) =>
      WalletError(3002, 'Keygen failed: $detail', cause);
  factory WalletError.keyShareNotFound() =>
      const WalletError(3003, 'Key share not found');
  factory WalletError.invalidPublicKey(String detail) =>
      WalletError(3004, 'Invalid public key: $detail');
  factory WalletError.walletAlreadyExists() =>
      const WalletError(3005, 'Wallet already exists');
  factory WalletError.signingFailed(String detail, [Object? cause]) =>
      WalletError(4001, 'Signing failed: $detail', cause);
  factory WalletError.txBuildFailed(String detail, [Object? cause]) =>
      WalletError(4101, 'Tx build failed: $detail', cause);
  factory WalletError.txBroadcastFailed(String detail, [Object? cause]) =>
      WalletError(4102, 'Tx broadcast failed: $detail', cause);
  factory WalletError.backupFailed(String detail, [Object? cause]) =>
      WalletError(4201, 'Backup failed: $detail', cause);
  factory WalletError.restoreFailed(String detail, [Object? cause]) =>
      WalletError(4202, 'Restore failed: $detail', cause);
  factory WalletError.delegationFailed(String detail, [Object? cause]) =>
      WalletError(4301, 'Delegation failed: $detail', cause);
  factory WalletError.approvalFailed(String detail, [Object? cause]) =>
      WalletError(4302, 'Approval failed: $detail', cause);
  factory WalletError.networkError(String detail, [Object? cause]) =>
      WalletError(5001, 'Network error: $detail', cause);
  factory WalletError.mpcError(String detail) =>
      WalletError(6001, 'MPC error: $detail');
  factory WalletError.unknown(String detail, [Object? cause]) =>
      WalletError(9001, 'Unknown: $detail', cause);

  /// native PlatformException(code=숫자 문자열, message) → WalletError 복원.
  factory WalletError.fromPlatform(String? code, String? message,
      [Object? cause]) {
    final parsed = int.tryParse(code ?? '') ?? 9001;
    return WalletError(parsed, message ?? 'Unknown error', cause);
  }

  factory WalletError.from(Object e) {
    if (e is WalletError) return e;
    return WalletError.unknown(e.toString(), e);
  }

  @override
  String toString() => 'WalletError($code): $message';
}
