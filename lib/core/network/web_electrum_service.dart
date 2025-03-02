import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:hex/hex.dart';
import 'package:bs58check/bs58check.dart' as bs58check;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:my_btcz_wallet/core/utils/logger.dart';
import 'package:my_btcz_wallet/core/network/connection_status.dart';

class WebElectrumService {
  final List<Map<String, dynamic>> _servers = [
    {'host': 'electrum1.btcz.rocks', 'port': 50002, 'status': 'unknown'},
    {'host': 'electrum2.btcz.rocks', 'port': 50002, 'status': 'unknown'},
    {'host': 'electrum3.btcz.rocks', 'port': 50002, 'status': 'unknown'},
    {'host': 'electrum4.btcz.rocks', 'port': 50002, 'status': 'unknown'},
    {'host': 'electrum5.btcz.rocks', 'port': 50002, 'status': 'unknown'},
  ];

  html.WebSocket? _socket;
  StreamSubscription? _subscription;
  StreamSubscription? _connectivitySubscription;
  Timer? _pingTimer;
  Timer? _healthCheckTimer;
  Timer? _reconnectTimer;
  DateTime? _lastSuccessfulPing;
  DateTime? _lastRequest;
  int _reconnectAttempts = 0;
  static const _minRequestInterval = Duration(milliseconds: 500);
  static const _maxReconnectAttempts = 5;

  final _statusController = StreamController<ConnectionStatus>.broadcast();
  var _currentStatus = ConnectionStatus.disconnected;
  int _currentServerIndex = 0;
  int _messageId = 0;
  final _responseCompleters = <int, Completer<dynamic>>{};
  bool _hasInternet = true;
  bool _isReconnecting = false;
  StringBuffer _buffer = StringBuffer();
  final _requestQueue = <_QueuedRequest>[];
  Timer? _queueProcessorTimer;
  final Map<String, String> _scriptHashCache = {};

  Stream<ConnectionStatus> get statusStream => _statusController.stream;
  ConnectionStatus get status => _currentStatus;
  String? get currentServer => _servers[_currentServerIndex]['host'];

  WebElectrumService() {
    _initConnectivity();
    _startQueueProcessor();
    Future.delayed(const Duration(seconds: 1), () {
      connect();
    });
  }

  void _startQueueProcessor() {
    _queueProcessorTimer?.cancel();
    _queueProcessorTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _processNextRequest();
    });
  }

  Future<void> _processNextRequest() async {
    if (_requestQueue.isEmpty || status != ConnectionStatus.connected) return;

    final now = DateTime.now();
    if (_lastRequest != null && now.difference(_lastRequest!) < _minRequestInterval) {
      return;
    }

    final request = _requestQueue.removeAt(0);
    try {
      _lastRequest = now;
      final result = await _sendRequest(request.method, request.params);
      request.completer.complete(result);
    } catch (e) {
      request.completer.completeError(e);
    }
  }

  Future<void> _initConnectivity() async {
    try {
      final result = await Connectivity().checkConnectivity();
      _updateConnectionStatus(result.first);

      _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
        _updateConnectionStatus(result.first);
      });
    } catch (e) {
      WalletLogger.error('Failed to initialize connectivity', e);
    }
  }

  void _updateConnectionStatus(ConnectivityResult result) {
    final hadInternet = _hasInternet;
    _hasInternet = result != ConnectivityResult.none;

    WalletLogger.info('Network connectivity changed: ${result.toString()}');

    if (!hadInternet && _hasInternet) {
      WalletLogger.info('Internet connection restored, reconnecting...');
      _scheduleReconnect(delay: const Duration(seconds: 2));
    } else if (!_hasInternet) {
      WalletLogger.info('Internet connection lost');
      _updateStatus(ConnectionStatus.disconnected);
    }
  }

  Duration _getBackoffDuration() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _reconnectAttempts = 0;
      _currentServerIndex = (_currentServerIndex + 1) % _servers.length;
    }
    final seconds = math.min(math.pow(2, _reconnectAttempts).toInt(), 30);
    return Duration(seconds: seconds);
  }

  void _scheduleReconnect({Duration? delay}) {
    if (_isReconnecting) return;

    _reconnectTimer?.cancel();
    final reconnectDelay = delay ?? _getBackoffDuration();

    _reconnectTimer = Timer(reconnectDelay, () {
      if (_hasInternet && status != ConnectionStatus.connected) {
        connect();
      }
    });
  }

  void connect() async {
    if (!_hasInternet) {
      WalletLogger.info('No internet connection available');
      return;
    }

    if (status == ConnectionStatus.connected || _socket != null) {
      WalletLogger.info('Already connected or connecting');
      return;
    }

    _updateStatus(ConnectionStatus.connecting);

    while (status != ConnectionStatus.connected && _hasInternet) {
      try {
        final currentServer = _servers[_currentServerIndex];
        final wsUrl = 'wss://${currentServer['host']}:${currentServer['port']}';
        WalletLogger.info('Connecting to $wsUrl');

        _socket = html.WebSocket(wsUrl);
        await _waitForConnection(_socket!);

        _updateStatus(ConnectionStatus.connected);
        currentServer['status'] = 'online';
        _lastSuccessfulPing = DateTime.now();
        _reconnectAttempts = 0;
        _isReconnecting = false;

        _setupSocketListeners();
        await _initializeConnection();
        _startHealthChecks();
        break;
      } catch (e) {
        WalletLogger.error('Connection failed', e);
        _updateStatus(ConnectionStatus.disconnected);

        _servers[_currentServerIndex]['status'] = 'offline';
        _reconnectAttempts++;

        if (_reconnectAttempts >= _maxReconnectAttempts) {
          _currentServerIndex = (_currentServerIndex + 1) % _servers.length;
          _reconnectAttempts = 0;
        }

        if (_hasInternet) {
          final backoff = _getBackoffDuration();
          WalletLogger.info('Waiting ${backoff.inSeconds} seconds before next attempt');
          await Future.delayed(backoff);
        } else {
          break;
        }
      }
    }
  }

  Future<void> _waitForConnection(html.WebSocket socket) {
    final completer = Completer<void>();
    
    void onOpen(html.Event event) {
      socket.removeEventListener('open', onOpen);
      socket.removeEventListener('error', onError);
      completer.complete();
    }

    void onError(html.Event event) {
      socket.removeEventListener('open', onOpen);
      socket.removeEventListener('error', onError);
      completer.completeError('WebSocket connection failed');
    }

    socket.addEventListener('open', onOpen);
    socket.addEventListener('error', onError);

    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        socket.removeEventListener('open', onOpen);
        socket.removeEventListener('error', onError);
        throw TimeoutException('Connection timed out');
      },
    );
  }

  void _setupSocketListeners() {
    _socket!.onMessage.listen(
      (event) {
        final message = event.data as String;
        _processIncomingData(message);
      },
      onError: (error) {
        WalletLogger.error('Socket error', error);
        _handleReconnection();
      },
      onDone: () {
        WalletLogger.info('Socket connection closed');
        _handleReconnection();
      },
    );
  }

  Future<void> _initializeConnection() async {
    try {
      final response = await _sendRequest('server.version', ['1.4', '1.4']);
      WalletLogger.info('Server version: $response');
      _startPingTimer();
    } catch (e) {
      WalletLogger.error('Failed to initialize connection', e);
      throw e;
    }
  }

  Future<dynamic> _enqueueRequest(String method, List<dynamic> params) {
    final completer = Completer<dynamic>();
    _requestQueue.add(_QueuedRequest(method, params, completer));
    return completer.future;
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      if (status == ConnectionStatus.connected) {
        _ping();
      }
    });
  }

  void _startHealthChecks() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_hasInternet) {
        _checkConnectionHealth();
      }
    });
  }

  void _checkConnectionHealth() {
    if (status != ConnectionStatus.connected) {
      _handleReconnection();
      return;
    }

    if (_lastSuccessfulPing != null) {
      final difference = DateTime.now().difference(_lastSuccessfulPing!);
      if (difference.inSeconds > 120) {
        WalletLogger.info('No ping response in 120 seconds, reconnecting...');
        _handleReconnection();
      }
    }
  }

  Future<void> _ping() async {
    try {
      await _enqueueRequest('server.ping', []);
      _lastSuccessfulPing = DateTime.now();
    } catch (e) {
      WalletLogger.error('Ping failed', e);
    }
  }

  Future<dynamic> _sendRequest(String method, List<dynamic> params) async {
    if (status != ConnectionStatus.connected && method != 'server.version') {
      throw Exception('Not connected to Electrum server');
    }

    final id = _messageId++;
    final request = {
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      'params': params,
    };

    final completer = Completer<dynamic>();
    _responseCompleters[id] = completer;

    try {
      final requestStr = json.encode(request) + '\n';
      WalletLogger.debug('Sending request: ${requestStr.trim()}');
      _socket!.send(requestStr);

      return await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          _responseCompleters.remove(id);
          throw TimeoutException('Request timed out');
        },
      );
    } catch (e) {
      _responseCompleters.remove(id);
      rethrow;
    }
  }

  void _processIncomingData(String data) {
    _buffer.write(data);

    while (true) {
      final String bufferContent = _buffer.toString();
      final int newlineIndex = bufferContent.indexOf('\n');

      if (newlineIndex == -1) break;

      final String message = bufferContent.substring(0, newlineIndex);
      _buffer = StringBuffer(bufferContent.substring(newlineIndex + 1));

      _handleMessage(message);
    }
  }

  void _handleMessage(String message) {
    try {
      final data = json.decode(message);
      WalletLogger.debug('Received message: $data');

      if (data['error'] != null) {
        WalletLogger.error('Server returned error: ${data['error']}');
        if (data['error']['code'] == -101) {
          _handleResourceError();
          return;
        }
      }

      final id = data['id'] as int?;
      if (id != null && _responseCompleters.containsKey(id)) {
        final completer = _responseCompleters.remove(id)!;
        if (data['error'] != null) {
          completer.completeError(data['error']);
        } else {
          completer.complete(data['result']);
        }
      }
    } catch (e, stackTrace) {
      WalletLogger.error('Failed to parse message', e, stackTrace);
    }
  }

  void _handleResourceError() {
    WalletLogger.info('Received resource usage error, implementing backoff...');
    _reconnectAttempts++;
    _handleReconnection();
  }

  void _handleReconnection() {
    if (_isReconnecting || !_hasInternet) return;
    _isReconnecting = true;

    disconnect().then((_) {
      final backoff = _getBackoffDuration();
      WalletLogger.info('Reconnecting in ${backoff.inSeconds} seconds...');

      Future.delayed(backoff, () {
        _isReconnecting = false;
        if (_hasInternet) {
          connect();
        }
      });
    });
  }

  Future<void> disconnect() async {
    _pingTimer?.cancel();
    _healthCheckTimer?.cancel();
    _socket?.close();
    _socket = null;

    _updateStatus(ConnectionStatus.disconnected);
    WalletLogger.info('Disconnected from server');

    for (final completer in _responseCompleters.values)