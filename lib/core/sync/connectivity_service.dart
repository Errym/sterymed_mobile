import 'dart:async';
import 'network_info_import.dart';

class ConnectivityService {
  final NetworkInfo _networkInfo;
  final _controller = StreamController<bool>.broadcast();

  ConnectivityService(this._networkInfo) {
    _networkInfo.onStatusChange.listen((connected) {
      _controller.add(connected);
    });
  }

  Stream<bool> get onStatusChange => _controller.stream;

  Future<bool> get isConnected => _networkInfo.isConnected;

  void dispose() => _controller.close();
}