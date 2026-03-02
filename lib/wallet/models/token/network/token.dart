import 'package:on_chain_wallet/app/live_listener/live.dart';
import 'package:on_chain_wallet/wallet/chain/account.dart';
import 'package:on_chain_wallet/wallet/models/token/token/token.dart';

enum NetworkTokenFetchingStatus {
  success,
  failed,
  pending,
  idle,
  close;

  bool get isSuccess => this == success;
  bool get isFailed => this == failed;
  bool get isPending => this == pending;
  bool get isIdle => this == idle;
  bool get isClose => this == close;
  bool get allowRetry => this == failed || this == idle;
}

abstract class BaseNetworkToken with DisposableMixin, StreamStateController {
  TokenCore get token;
  NetworkTokenFetchingStatus _status = NetworkTokenFetchingStatus.idle;
  NetworkTokenFetchingStatus get status => _status;
  BaseNetworkToken(
      {NetworkTokenFetchingStatus status = NetworkTokenFetchingStatus.idle})
      : _status = status;
  void updaetTokenMetadata(Token token);
  void setPending() {
    if (_status.isClose) return;
    _status = NetworkTokenFetchingStatus.pending;
    notify();
  }

  void setError() {
    if (_status.isClose) return;
    _status = NetworkTokenFetchingStatus.failed;
    notify();
  }

  @override
  void dispose() {
    _status = NetworkTokenFetchingStatus.close;
    super.dispose();
    token.streamBalance.dispose();
  }

  @override
  void notify() {
    if (closed) return;
    super.notify();
  }
}
