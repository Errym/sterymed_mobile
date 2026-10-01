import 'dart:async';

import '../network/network_info.dart';

class ConnectivityService {
  final NetworkInfo _networkInfo;
  final _controller = StreamController<bool>.broadcast();
  late final StreamSubscription<bool> _subscription;

  ConnectivityService(this._networkInfo) {
    _subscription = _networkInfo.onStatusChange.distinct().listen(
      _controller.add,
    );
  }

  Stream<bool> get onStatusChange => _controller.stream;
  Future<bool> get isConnected => _networkInfo.isConnected;
  Future<void> dispose() async {
    await _subscription.cancel();
    await _controller.close();
  }
}
