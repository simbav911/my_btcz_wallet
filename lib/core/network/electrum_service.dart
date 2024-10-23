import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:my_btcz_wallet/core/utils/logger.dart';

enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
}

class ElectrumService {
  static const List<Map<String, dynamic>> _servers = [
    {'host': 'electrum1.btcz.rocks', 'port': 50002, 'ssl': true},
    {'host': 'electrum2.btcz.rocks', 'port': 50002, 'ssl': true},
    {'host': 'electrum3.btcz.rocks', 'port': 50002, 'ssl': true},
    {'host': 'electrum4.btcz.rocks', 'port': 50002, 'ssl': true},
    {'host': 'electrum5.btcz.rocks', 'port': 50002, 'ssl': true},
  ];

  SecureSocket? _secureSocket;
  Map<String, dynamic>? _currentServer;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  final _statusController = StreamController<ConnectionStatus>.broadcast();
  var _currentStatus = ConnectionStatus.disconnected;
  int _currentServerIndex = 0;
  int _messageId = 0;
  StringBuffer _buffer = StringBuffer();
  bool _isConnecting = false;
  final _responseCompleters = <int, Completer<dynamic>>{};
  Completer<void>? _connectionCompleter;
  int _retryCount = 0;
  static const int maxRetries = 3;

  Stream<ConnectionStatus> get statusStream => _statusController.stream;
  ConnectionStatus get status => _currentStatus;
  String? get currentServer => _currentServer != null 
      ? '${_currentServer!['host']}:${_currentServer!['port']}'
      : null;

  ElectrumService() {
    // Start connection when service is initialized
    Future.delayed(const Duration(seconds: 1), () {
      connect();
    });
  }

  void connect() {
    if (_isConnecting) return;
    _isConnecting = true;
    _updateStatus(ConnectionStatus.connecting);
    _connectToNextServer();
  }

  Future<void> _connectToNextServer() async {
    if (_currentStatus == ConnectionStatus.connected) {
      _isConnecting = false;
      return;
    }

    _currentServer = _servers[_currentServerIndex];
    WalletLogger.info('Connecting to Electrum server: ${_currentServer!['host']}:${_currentServer!['port']}');

    try {
      SecurityContext context = SecurityContext(withTrustedRoots: true);
      
      _secureSocket = await SecureSocket.connect(
        _currentServer!['host'],
        _currentServer!['port'],
        context: context,
        onBadCertificate: (_) => true,
        timeout: const Duration(seconds: 30),
      );

      WalletLogger.info('SSL connection established');
      _setupSocketListeners(_secureSocket!);
      await _initializeConnection();
      _retryCount = 0; // Reset retry count on successful connection
    } catch (e) {
      WalletLogger.error('Failed to connect to ${_currentServer!['host']}', e);
      _handleError(e);
    }
  }

  Future<void> _initializeConnection() async {
    try {
      final response = await _sendRequest('server.version', ['BitcoinZ-Wallet', '1.4']);
      WalletLogger.info('Server version response: $response');
      
      if (response != null) {
        _updateStatus(ConnectionStatus.connected);
        _isConnecting = false;
        _startPingTimer();
        _connectionCompleter?.complete();
        _connectionCompleter = null;
      }
    } catch (e) {
      WalletLogger.error('Failed to initialize connection', e);
      _handleError(e);
    }
  }

  Future<dynamic> _sendRequest(String method, List<dynamic> params) async {
    if (_currentStatus != ConnectionStatus.connected && method != 'server.version') {
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
      await _sendMessage(request);
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

  void _handleError(dynamic error) {
    WalletLogger.error('Electrum connection error', error);
    _updateStatus(ConnectionStatus.disconnected);
    
    if (_retryCount < maxRetries) {
      _retryCount++;
      WalletLogger.info('Retrying connection (attempt $_retryCount of $maxRetries)');
      _tryReconnect();
    } else {
      _retryCount = 0;
      _currentServerIndex = (_currentServerIndex + 1) % _servers.length;
      WalletLogger.info('Max retries reached, switching to next server');
      _tryReconnect();
    }
  }

  void _tryReconnect() {
    _stopPingTimer();
    _closeConnections();
    
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 2), () {
      _isConnecting = false;
      connect();
    });
  }

  // ... rest of the methods remain the same ...
  void _setupSocketListeners(Stream<List<int>> socket) {
    socket.listen(
      (data) {
        final message = utf8.decode(data);
        _processIncomingData(message);
      },
      onError: _handleError,
      onDone: _handleDisconnect,
    );
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
          _handleError('Server busy, trying next one');
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
      WalletLogger.error('Failed to parse message: $message', e);
    }
  }

  void _handleDisconnect() {
    WalletLogger.info('Disconnected from Electrum server');
    _updateStatus(ConnectionStatus.disconnected);
    _tryReconnect();
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _ping();
    });
  }

  void _stopPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  Future<void> _ping() async {
    try {
      await _sendRequest('server.ping', []);
    } catch (e) {
      WalletLogger.error('Failed to ping server', e);
      _handleError(e);
    }
  }

  Future<void> _sendMessage(Map<String, dynamic> message) async {
    final data = json.encode(message) + '\n';
    try {
      if (_secureSocket != null) {
        _secureSocket!.write(data);
        await _secureSocket!.flush();
      }
    } catch (e) {
      WalletLogger.error('Failed to send message', e);
      throw e;
    }
  }

  void _updateStatus(ConnectionStatus newStatus) {
    _currentStatus = newStatus;
    _statusController.add(newStatus);
  }

  void _closeConnections() {
    for (final completer in _responseCompleters.values) {
      completer.completeError('Connection closed');
    }
    _responseCompleters.clear();
    _secureSocket?.destroy();
    _secureSocket = null;
    _buffer.clear();
    _connectionCompleter?.completeError('Connection closed');
    _connectionCompleter = null;
  }

  void dispose() {
    _closeConnections();
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _statusController.close();
  }

  // Add getters for testing and debugging
  bool get isConnecting => _isConnecting;
  int get retryCount => _retryCount;
  int get currentServerIndex => _currentServerIndex;
}
