import 'wallet_error.dart';

sealed class WalletResult<T> {
  const WalletResult();

  bool get isSuccess => this is WalletSuccess<T>;
  bool get isFailure => this is WalletFailure<T>;

  T? getOrNull() => switch (this) {
        WalletSuccess<T> s => s.data,
        WalletFailure<T> _ => null,
      };

  WalletError? errorOrNull() => switch (this) {
        WalletSuccess<T> _ => null,
        WalletFailure<T> f => f.error,
      };

  T getOrThrow() => switch (this) {
        WalletSuccess<T> s => s.data,
        WalletFailure<T> f => throw f.error,
      };

  R fold<R>(
    R Function(T data) onSuccess,
    R Function(WalletError error) onFailure,
  ) =>
      switch (this) {
        WalletSuccess<T> s => onSuccess(s.data),
        WalletFailure<T> f => onFailure(f.error),
      };

  WalletResult<T> onSuccess(void Function(T data) action) {
    if (this is WalletSuccess<T>) action((this as WalletSuccess<T>).data);
    return this;
  }

  WalletResult<T> onFailure(void Function(WalletError error) action) {
    if (this is WalletFailure<T>) action((this as WalletFailure<T>).error);
    return this;
  }

  static WalletResult<T> success<T>(T data) => WalletSuccess(data);
  static WalletResult<T> failure<T>(WalletError error) => WalletFailure(error);
}

class WalletSuccess<T> extends WalletResult<T> {
  final T data;
  const WalletSuccess(this.data);
}

class WalletFailure<T> extends WalletResult<T> {
  final WalletError error;
  const WalletFailure(this.error);
}
