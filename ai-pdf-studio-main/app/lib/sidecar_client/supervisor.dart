import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'rpc_client.dart';

class SidecarSupervisor {
  SidecarSupervisor({this.onNotification});

  final RpcNotificationHandler? onNotification;
  RpcClient? _client;
  Process? _process;
  Timer? _healthTimer;
  var _stopping = false;

  bool get isRunning => _client != null;

  Future<void> start() async {
    if (isRunning) return;
    _stopping = false;
    final token = _token();
    final configuredPath = Platform.environment['AIPS_SIDECAR_PATH'];
    final bundledPath = File(
      '${File(Platform.resolvedExecutable).parent.path}${Platform.pathSeparator}sidecar'
      '${Platform.pathSeparator}aips-sidecar.exe',
    );
    final executable = configuredPath != null && configuredPath.isNotEmpty
        ? configuredPath
        : bundledPath.existsSync()
            ? bundledPath.path
            : null;
    final process = executable == null || executable.isEmpty
        ? await Process.start(
            Platform.environment['PYTHON'] ?? 'python',
            ['-m', 'ai_pdf_studio.rpc_server', '--token', token],
            runInShell: true,
            environment: {...Platform.environment, 'AIPS_SIDECAR_TOKEN': token},
          )
        : await Process.start(executable, ['--token', token]);
    _process = process;
    final client = RpcClient(process: process, token: token, onNotification: onNotification);
    _client = client;
    await client.request('system.handshake', {'clientContractVersion': '1.0.0'});
    _healthTimer = Timer.periodic(const Duration(seconds: 5), (_) => _checkHealth());
    unawaited(process.exitCode.then((_) {
      if (!_stopping) {
        _client = null;
        unawaited(start());
      }
    }));
  }

  Future<dynamic> request(String method, [Map<String, dynamic> params = const {}]) async {
    final client = _client;
    if (client == null) {
      throw const RpcException(-32000, 'Sidecar is not running.');
    }
    return client.request(method, params);
  }

  Future<void> cancel(String jobId) async {
    await request('job.cancel', {'jobId': jobId});
  }

  Future<void> restart() async {
    await stop();
    await start();
  }

  Future<void> stop() async {
    _stopping = true;
    _healthTimer?.cancel();
    _healthTimer = null;
    final client = _client;
    _client = null;
    if (client != null) {
      try {
        await client.request('system.shutdown').timeout(const Duration(seconds: 2));
      } catch (_) {
        // The process is still terminated below.
      }
      await client.close();
    }
    _process?.kill();
    _process = null;
  }

  Future<void> _checkHealth() async {
    try {
      await request('system.health').timeout(const Duration(seconds: 2));
    } catch (_) {
      await restart();
    }
  }

  String _token() {
    final random = Random.secure();
    return List<int>.generate(32, (_) => random.nextInt(256))
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}
