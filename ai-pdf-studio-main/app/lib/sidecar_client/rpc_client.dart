import 'dart:async';
import 'dart:convert';
import 'dart:io';

class RpcException implements Exception {
  const RpcException(this.code, this.message, [this.data = const {}]);

  final int code;
  final String message;
  final Map<String, dynamic> data;

  @override
  String toString() => 'RPC $code: $message';
}

typedef RpcNotificationHandler = void Function(String method, Map<String, dynamic> params);

class RpcClient {
  RpcClient({
    required this.process,
    required this.token,
    this.onNotification,
  }) {
    _subscription = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_handleLine, onDone: _handleExit);
  }

  final Process process;
  final String token;
  final RpcNotificationHandler? onNotification;
  final _pending = <int, Completer<dynamic>>{};
  late final StreamSubscription<String> _subscription;
  var _nextId = 1;
  var _closed = false;

  Future<dynamic> request(String method, [Map<String, dynamic> params = const {}]) async {
    if (_closed) return Future.error(const RpcException(-32000, 'Sidecar is not running.'));
    final id = _nextId++;
    final completer = Completer<dynamic>();
    _pending[id] = completer;
    process.stdin.writeln(jsonEncode({
      'jsonrpc': '2.0',
      'id': id,
      'auth': token,
      'method': method,
      'params': params,
    }));
    await process.stdin.flush();
    return completer.future;
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _subscription.cancel();
    for (final pending in _pending.values) {
      if (!pending.isCompleted) {
        pending.completeError(const RpcException(-32000, 'Sidecar stopped.'));
      }
    }
    _pending.clear();
    process.kill();
  }

  void _handleLine(String line) {
    final message = jsonDecode(line) as Map<String, dynamic>;
    if (message.containsKey('method')) {
      onNotification?.call(
        message['method'] as String,
        (message['params'] as Map<dynamic, dynamic>? ?? {}).cast<String, dynamic>(),
      );
      return;
    }
    final id = message['id'] as int?;
    final completer = id == null ? null : _pending.remove(id);
    if (completer == null) return;
    if (message['error'] != null) {
      final error = (message['error'] as Map<dynamic, dynamic>).cast<String, dynamic>();
      completer.completeError(RpcException(
        (error['code'] as num?)?.toInt() ?? -32603,
        error['message'] as String? ?? 'Unknown RPC error.',
        (error['data'] as Map<dynamic, dynamic>? ?? {}).cast<String, dynamic>(),
      ));
    } else {
      completer.complete(message['result']);
    }
  }

  void _handleExit() {
    if (_closed) return;
    _closed = true;
    for (final pending in _pending.values) {
      if (!pending.isCompleted) {
        pending.completeError(const RpcException(-32000, 'Sidecar exited.'));
      }
    }
    _pending.clear();
  }
}
