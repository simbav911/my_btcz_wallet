import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:my_btcz_wallet/core/utils/logger.dart';

enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
}

class ElectrumService {
  final List<Map<String, dynamic>> _servers = [
    {'host': 'electrum1.btcz.rocks', 'port': 50002, 'status': 'unknown'},
    {'host': 'electrum2.btcz.rocks', 'port': 50002, 'status': 'unknown'},
    {'host': 'electrum3.btcz.rocks', 'port': 50002, 'status': 'unknown'},
    {'host': 'electrum4.btcz.rocks', 'port': 50002, 'status': 'unknown'},
    {'host': 'electrum5.btcz.rocks', 'port': 50002, 'status': 'unknown'},
  ];

  SecureSocket? _socket;
  StreamSubscription? _subscription;
  StreamSubscription? _connectivitySubscription;
  Timer? _pingTimer;
  Timer? _healthCheckTimer;
  Timer? _reconnectTimer;
  DateTime? _lastSuccessfulPing;
  
  final _statusController = StreamController<ConnectionStatus>.broadcast();
  var _currentStatus = ConnectionStatus.disconnected;
  int _currentServerIndex = 0;
  int _messageId = 0;
  final _responseCompleters = <int, Completer<dynamic>>{};
  bool _hasInternet = true;
  bool _isReconnecting = false;
  StringBuffer _buffer = StringBuffer();

  Stream<ConnectionStatus> get statusStream => _statusController.stream;
  ConnectionStatus get status => _currentStatus;
  String? get currentServer => _servers[_currentServerIndex]['host'];

  ElectrumService() {
    _initConnectivity();
    // Start connection after a short delay
    Future.delayed(const Duration(seconds: 1), () {
      connect();
    });
  }

  Future<void> _initConnectivity() async {
    try {
      final result = await Connectivity().checkConnectivity();
      _updateConnectionStatus(result);

      _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
        _updateConnectionStatus(result);
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

  void _scheduleReconnect({Duration delay = const Duration(seconds: 5)}) {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
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
        WalletLogger.info('Connecting to ${currentServer['host']}:${currentServer['port']}');

        _socket = await SecureSocket.connect(
          currentServer['host'],
          currentServer['port'],
          timeout: const Duration(seconds: 30),
          onBadCertificate: (cert) => true,
        );

        _updateStatus(ConnectionStatus.connected);
        currentServer['status'] = 'online';
        _lastSuccessfulPing = DateTime.now();

        _setupSocketListeners();
        await _initializeConnection();
        _startHealthChecks();
        break;

      } catch (e) {
        WalletLogger.error('Connection failed', e);
        _updateStatus(ConnectionStatus.disconnected);
        
        _servers[_currentServerIndex]['status'] = 'offline';
        _currentServerIndex = (_currentServerIndex + 1) % _servers.length;
        
        if (_hasInternet) {
          await Future.delayed(const Duration(seconds: 5));
        } else {
          break;
        }
      }
    }
  }

  void _setupSocketListeners() {
    _subscription?.cancel();
    _subscription = _socket!.listen(
      (data) {
        final message = utf8.decode(data);
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
      final response = await _sendRequest('server.version', ['BitcoinZ-Wallet', '1.4']);
      WalletLogger.info('Server version: $response');
      _startPingTimer();
    } catch (e) {
      WalletLogger.error('Failed to initialize connection', e);
      throw e;
    }
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
      await _sendRequest('server.ping', []);
      _lastSuccessfulPing = DateTime.now();
    } catch (e) {
      WalletLogger.error('Ping failed', e);
    }
  }

  Future<dynamic> _sendRequest(String method, List<dynamic> params) async {
    if (status != ConnectionStatus.connected && method != 'server.version') {
      throw const SocketException('Not connected to Electrum server');
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
      _socket!.add(utf8.encode(requestStr));
      await _socket!.flush();

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
        if (data['error']['code'] == -101) {
          _handleReconnection();
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
    } catch (e) {
      WalletLogger.error('Failed to parse message', e);
    }
  }

  void _handleReconnection() {
    if (_isReconnecting || !_hasInternet) return;
    _isReconnecting = true;

    disconnect().then((_) {
      _currentServerIndex = (_currentServerIndex + 1) % _servers.length;
      
      Future.delayed(const Duration(seconds: 5), () {
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
    await _subscription?.cancel();
    await _socket?.close();
    _socket = null;
    
    _updateStatus(ConnectionStatus.disconnected);
    WalletLogger.info('Disconnected from server');

    for (final completer in _responseCompleters.values) {
      completer.completeError('Connection closed');
    }
    _responseCompleters.clear();
    _buffer.clear();
  }

  void _updateStatus(ConnectionStatus newStatus) {
    _currentStatus = newStatus;
    _statusController.add(newStatus);
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _pingTimer?.cancel();
    _healthCheckTimer?.cancel();
    _reconnectTimer?.cancel();
    disconnect();
    _statusController.close();
  }

  // Required methods for wallet functionality
  Future<List<Map<String, dynamic>>> getUnspentOutputs(String address) async {
    final response = await _sendRequest('blockchain.address.listunspent', [address]);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> getTransaction(String txId) async {
    final response = await _sendRequest('blockchain.transaction.get', [txId, true]);
    return Map<String, dynamic>.from(response);
  }

  Future<double> getBalance(String address) async {
    final response = await _sendRequest('blockchain.address.get_balance', [address]);
    final confirmed = (response['confirmed'] as num?) ?? 0;
    final unconfirmed = (response['unconfirmed'] as num?) ?? 0;
    return (confirmed + unconfirmed) / 100000000;
  }

  Future<List<Map<String, dynamic>>> getHistory(String address) async {
    final response = await _sendRequest('blockchain.address.get_history', [address]);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<String> broadcastTransaction(String rawTx) async {
    final response = await _sendRequest('blockchain.transaction.broadcast', [rawTx]);
    return response as String;
  }

  Future<Map<String, dynamic>> getFeeEstimate(int targetBlocks) async {
    final response = await _sendRequest('blockchain.estimatefee', [targetBlocks]);
    return Map<String, dynamic>.from(response);
  }
}
