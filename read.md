Certainly! Below is the full updated code for the `ElectrumService` class, incorporating the necessary fixes to ensure that transactions are constructed and broadcasted correctly on the BitcoinZ network. This includes handling the correct transaction version, version group ID, and ensuring all transaction fields comply with the network's requirements.

Please make sure to replace placeholders like `'YourPrivateKeyInWIFFormat'`, `'t1YourFromAddress'`, and `'t1RecipientAddress'` with your actual private key and addresses.

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:bitcoin_flutter/bitcoin_flutter.dart' as bitcoin;
import 'package:bs58check/bs58check.dart' as bs58check;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:hex/hex.dart';

// Replace this with your actual logger implementation
class WalletLogger {
  static void debug(String message) {
    print('DEBUG: $message');
  }

  static void info(String message) {
    print('INFO: $message');
  }

  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    print('ERROR: $message');
    if (error != null) print('Error: $error');
    if (stackTrace != null) print('StackTrace: $stackTrace');
  }
}

enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
}

class _QueuedRequest {
  final String method;
  final List<dynamic> params;
  final Completer<dynamic> completer;

  _QueuedRequest(this.method, this.params, this.completer);
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

  String _getScriptHash(String address) {
    if (_scriptHashCache.containsKey(address)) {
      return _scriptHashCache[address]!;
    }

    try {
      WalletLogger.debug('Calculating script hash for address: $address');

      // Decode the base58check address
      final decoded = bs58check.decode(address);
      WalletLogger.debug('Decoded address bytes: ${HEX.encode(decoded)}');

      // Remove the version bytes (first 2 bytes for BitcoinZ)
      final pubKeyHash = decoded.sublist(2);
      WalletLogger.debug('PubKeyHash: ${HEX.encode(pubKeyHash)}');

      // Create P2PKH script: OP_DUP OP_HASH160 <pubKeyHash> OP_EQUALVERIFY OP_CHECKSIG
      final script = Uint8List(pubKeyHash.length + 5);
      script[0] = 0x76; // OP_DUP
      script[1] = 0xa9; // OP_HASH160
      script[2] = 0x14; // Push 20 bytes
      script.setRange(3, 3 + pubKeyHash.length, pubKeyHash);
      script[script.length - 2] = 0x88; // OP_EQUALVERIFY
      script[script.length - 1] = 0xac; // OP_CHECKSIG

      WalletLogger.debug('Script: ${HEX.encode(script)}');

      // Hash the scriptPubKey with SHA256
      final hash = sha256.convert(script).bytes;

      // Reverse the hash and encode as hex
      final reversedHash = hash.reversed.toList();
      final scriptHash = HEX.encode(reversedHash);

      WalletLogger.debug('Final script hash: $scriptHash');

      _scriptHashCache[address] = scriptHash;
      return scriptHash;
    } catch (e, stackTrace) {
      WalletLogger.error('Failed to calculate script hash', e, stackTrace);
      throw Exception('Invalid address format');
    }
  }

  ElectrumService() {
    _initConnectivity();
    _startQueueProcessor();
    Future.delayed(const Duration(seconds: 1), () {
      connect();
    });
  }

  void _startQueueProcessor() {
    _queueProcessorTimer?.cancel();
    _queueProcessorTimer =
        Timer.periodic(const Duration(milliseconds: 500), (_) {
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
      _updateConnectionStatus(result);

      _connectivitySubscription =
          Connectivity().onConnectivityChanged.listen((result) {
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
        WalletLogger.info(
            'Connecting to ${currentServer['host']}:${currentServer['port']}');

        _socket = await SecureSocket.connect(
          currentServer['host'],
          currentServer['port'],
          timeout: const Duration(seconds: 30),
          onBadCertificate: (cert) => true,
        );

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
    _requestQueue.clear();
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
    _queueProcessorTimer?.cancel();
    disconnect();
    _statusController.close();
  }

  // Required methods for wallet functionality
  Future<double> getBalance(String address) async {
    WalletLogger.debug('Getting balance for address: $address');
    try {
      final scriptHash = _getScriptHash(address);
      final response = await _enqueueRequest('blockchain.scripthash.get_balance', [scriptHash]);
      WalletLogger.debug('Balance response: $response');

      final confirmed = ((response['confirmed'] as num?) ?? 0) / 100000000;
      final unconfirmed = ((response['unconfirmed'] as num?) ?? 0) / 100000000;

      WalletLogger.debug('Confirmed: $confirmed, Unconfirmed: $unconfirmed');
      return confirmed + unconfirmed;
    } catch (e, stackTrace) {
      WalletLogger.error('Failed to get balance', e, stackTrace);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getHistory(String address) async {
    WalletLogger.debug('Getting history for address: $address');
    try {
      final scriptHash = _getScriptHash(address);
      final response = await _enqueueRequest('blockchain.scripthash.get_history', [scriptHash]);
      WalletLogger.debug('History response: $response');
      return List<Map<String, dynamic>>.from(response);
    } catch (e, stackTrace) {
      WalletLogger.error('Failed to get history', e, stackTrace);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getUnspentOutputs(String address) async {
    WalletLogger.debug('Getting unspent outputs for address: $address');
    try {
      final scriptHash = _getScriptHash(address);
      final response = await _enqueueRequest('blockchain.scripthash.listunspent', [scriptHash]);
      WalletLogger.debug('Unspent outputs response: $response');
      return List<Map<String, dynamic>>.from(response);
    } catch (e, stackTrace) {
      WalletLogger.error('Failed to get unspent outputs', e, stackTrace);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getTransaction(String txId) async {
    WalletLogger.debug('Getting transaction details for txId: $txId');
    try {
      final response = await _enqueueRequest('blockchain.transaction.get', [txId, true]);
      WalletLogger.debug('Transaction response received');
      return Map<String, dynamic>.from(response);
    } catch (e, stackTrace) {
      WalletLogger.error('Failed to get transaction', e, stackTrace);
      rethrow;
    }
  }

  Future<String> broadcastTransaction(String rawTx) async {
    WalletLogger.debug('Broadcasting transaction');
    try {
      final response = await _enqueueRequest('blockchain.transaction.broadcast', [rawTx]);
      WalletLogger.debug('Broadcast response: $response');
      return response as String;
    } catch (e, stackTrace) {
      WalletLogger.error('Failed to broadcast transaction', e, stackTrace);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getFeeEstimate(int targetBlocks) async {
    WalletLogger.debug('Getting fee estimate for $targetBlocks blocks');
    try {
      final response = await _enqueueRequest('blockchain.estimatefee', [targetBlocks]);
      WalletLogger.debug('Fee estimate response: $response');
      return {'feeRate': response};
    } catch (e, stackTrace) {
      WalletLogger.error('Failed to get fee estimate', e, stackTrace);
      rethrow;
    }
  }

  Future<void> subscribeToAddress(String address) async {
    WalletLogger.debug('Subscribing to address: $address');
    try {
      final scriptHash = _getScriptHash(address);
      await _enqueueRequest('blockchain.scripthash.subscribe', [scriptHash]);
      WalletLogger.debug('Successfully subscribed to address');
    } catch (e, stackTrace) {
      WalletLogger.error('Failed to subscribe to address', e, stackTrace);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getAddressStatus(String address) async {
    WalletLogger.debug('Getting status for address: $address');
    try {
      final scriptHash = _getScriptHash(address);
      final response = await _enqueueRequest('blockchain.scripthash.get_history', [scriptHash]);
      WalletLogger.debug('Address status response received');
      return {
        'scriptHash': scriptHash,
        'history': response,
      };
    } catch (e, stackTrace) {
      WalletLogger.error('Failed to get address status', e, stackTrace);
      rethrow;
    }
  }

  Future<int> getCurrentHeight() async {
    WalletLogger.debug('Getting current block height');
    try {
      final response = await _enqueueRequest('blockchain.headers.subscribe', []);
      WalletLogger.debug('Block height response: $response');
      return response['height'] as int;
    } catch (e, stackTrace) {
      WalletLogger.error('Failed to get current block height', e, stackTrace);
      rethrow;
    }
  }

  // New method to create and broadcast a transaction
  Future<String> createAndBroadcastTransaction({
    required String fromAddress,
    required String toAddress,
    required double amount,
    required String privateKeyWIF,
    double fee = 0.0001,
  }) async {
    WalletLogger.debug('Creating transaction from $fromAddress to $toAddress');

    try {
      // Fetch unspent outputs
      final unspentOutputs = await getUnspentOutputs(fromAddress);

      // Convert amount and fee to satoshis
      int amountSatoshi = (amount * 1e8).toInt();
      int feeSatoshi = (fee * 1e8).toInt();

      // Build the transaction inputs
      List<Map<String, dynamic>> selectedUTXOs = [];
      int totalInputValue = 0;
      for (var utxo in unspentOutputs) {
        totalInputValue += utxo['value'] as int;
        selectedUTXOs.add(utxo);
        if (totalInputValue >= amountSatoshi + feeSatoshi) break;
      }

      if (totalInputValue < amountSatoshi + feeSatoshi) {
        throw Exception('Insufficient funds');
      }

      // Build the transaction outputs
      Map<String, int> outputs = {
        toAddress: amountSatoshi,
      };

      // Calculate change and add change output if necessary
      int change = totalInputValue - amountSatoshi - feeSatoshi;
      if (change > 0) {
        outputs[fromAddress] = change;
      }

      // Define BitcoinZ network parameters
      final bitcoin.NetworkType bitcoinZNetwork = bitcoin.NetworkType(
        messagePrefix: '\x18BitcoinZ Signed Message:\n',
        bip32: bitcoin.Bip32Type(public: 0x0488b21e, private: 0x0488ade4),
        pubKeyHash: 0x1CB8, // BitcoinZ pubKeyHash
        scriptHash: 0x1CBD, // BitcoinZ scriptHash
        wif: 0x80,
      );

      // Create the transaction builder
      bitcoin.TransactionBuilder txb = bitcoin.TransactionBuilder(network: bitcoinZNetwork);

      // Set the transaction version and version group ID for Sapling
      txb.setVersion(4);
      txb.setVersionGroupId(0x892F2085);

      // Add inputs
      for (var utxo in selectedUTXOs) {
        txb.addInput(utxo['tx_hash'], utxo['tx_pos']);
      }

      // Add outputs
      outputs.forEach((address, value) {
        txb.addOutput(address, value);
      });

      // Sign the inputs
      final keyPair = bitcoin.ECPair.fromWIF(privateKeyWIF, network: bitcoinZNetwork);
      for (int i = 0; i < selectedUTXOs.length; i++) {
        txb.sign(vin: i, keyPair: keyPair);
      }

      // Build and serialize the transaction
      bitcoin.Transaction tx = txb.build();
      String rawTxHex = tx.toHex();
      WalletLogger.debug('Constructed transaction hex: $rawTxHex');

      // Broadcast the transaction
      String txId = await broadcastTransaction(rawTxHex);
      WalletLogger.info('Transaction broadcasted with txId: $txId');
      return txId;
    } catch (e, stackTrace) {
      WalletLogger.error('Failed to create and broadcast transaction', e, stackTrace);
      rethrow;
    }
  }
}
```

### **Usage Example**

Here is an example of how you can use the `ElectrumService` class to create and broadcast a transaction:

```dart
void main() async {
  ElectrumService electrumService = ElectrumService();

  // Wait until connected
  await electrumService.statusStream.firstWhere((status) => status == ConnectionStatus.connected);

  try {
    String txId = await electrumService.createAndBroadcastTransaction(
      fromAddress: 't1YourFromAddress', // Replace with your actual from address
      toAddress: 't1RecipientAddress',  // Replace with the recipient's address
      amount: 1.0, // Amount in BitcoinZ to send
      privateKeyWIF: 'YourPrivateKeyInWIFFormat', // Replace with your private key in WIF format
      fee: 0.0001, // Optional transaction fee
    );
    print('Transaction sent with txId: $txId');
  } catch (e) {
    print('Error sending transaction: $e');
  } finally {
    electrumService.dispose();
  }
}
```

### **Important Notes**

- **Dependencies**: Ensure you have the following dependencies in your `pubspec.yaml`:

  ```yaml
  dependencies:
    bitcoin_flutter: ^2.0.0
    bs58check: ^1.0.1
    crypto: ^3.0.1
    hex: ^0.1.3
    connectivity_plus: ^2.0.2
  ```

- **Private Key**: The `privateKeyWIF` should correspond to the `fromAddress`. Make sure it's securely stored and never exposed.

- **Addresses**: Replace `'t1YourFromAddress'` and `'t1RecipientAddress'` with actual BitcoinZ transparent addresses.

- **Testing**: Before sending real transactions, consider testing with small amounts or on a testnet if available.

- **Error Handling**: The code includes comprehensive error handling and logging to help you diagnose any issues.

### **Conclusion**

By ensuring that the transaction version and version group ID align with BitcoinZ's Sapling protocol, and correctly constructing and signing the transaction, the issue should be resolved. This full code provides a complete implementation of the `ElectrumService` class with the necessary fixes.

Feel free to integrate this code into your project and adjust it as needed. If you encounter any further issues, please check the logs for detailed error messages, and ensure that all inputs (addresses, private keys, amounts) are correct.