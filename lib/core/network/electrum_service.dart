import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' show Random;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:hex/hex.dart';
import 'package:bs58check/bs58check.dart' as bs58check;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:my_btcz_wallet/core/utils/logger.dart';
import 'package:my_btcz_wallet/core/network/connection_status.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/ecc/api.dart';
import 'package:pointycastle/ecc/curves/secp256k1.dart';
import 'package:pointycastle/macs/hmac.dart';
import 'package:pointycastle/random/fortuna_random.dart';
import 'package:pointycastle/signers/ecdsa_signer.dart';
import 'package:bip32/bip32.dart' as bip32;

class _QueuedRequest {
  final String method;
  final List<dynamic> params;
  final Completer<dynamic> completer;

  _QueuedRequest(this.method, this.params, this.completer);
}

// Utility functions
Uint8List bigIntToBytes(BigInt number) {
  int bytes = (number.bitLength + 7) >> 3;
  var b256 = BigInt.from(256);
  var result = Uint8List(bytes);
  for (int i = bytes - 1; i >= 0; i--) {
    result[i] = (number % b256).toInt();
    number = number >> 8;
  }
  return result;
}

Uint8List derEncodeSignature(BigInt r, BigInt s) {
  List<int> sequence = [];

  List<int> rBytes = bigIntToBytes(r);
  if (rBytes[0] & 0x80 != 0) {
    rBytes = [0x00] + rBytes;
  }
  sequence.add(0x02); // INTEGER tag
  sequence.add(rBytes.length);
  sequence.addAll(rBytes);

  List<int> sBytes = bigIntToBytes(s);
  if (sBytes[0] & 0x80 != 0) {
    sBytes = [0x00] + sBytes;
  }
  sequence.add(0x02); // INTEGER tag
  sequence.add(sBytes.length);
  sequence.addAll(sBytes);

  sequence = [0x30, sequence.length] + sequence;

  return Uint8List.fromList(sequence);
}

// Transaction related classes
class Transaction {
  final int version;
  final int versionGroupId;  // Added for Overwinter
  final List<TxInput> inputs;
  final List<TxOutput> outputs;
  final int lockTime;
  final int expiryHeight;   // Added for Overwinter
  final int valueBalance;   // Added for Overwinter

  Transaction({
    required this.version,
    required this.inputs,
    required this.outputs,
    this.lockTime = 0,
    this.versionGroupId = 0x03C48270,  // BitcoinZ Overwinter version group ID
    this.expiryHeight = 0,
    this.valueBalance = 0,
  });

  Uint8List serialize() {
    final totalSize = 4 + // version
        4 + // version group id
        varintLength(inputs.length) +
        inputs.fold<int>(0, (int sum, input) => sum + input.getSize()) +
        varintLength(outputs.length) +
        outputs.fold<int>(0, (int sum, output) => sum + output.getSize()) +
        4 + // lockTime
        4 + // expiry height
        8;  // value balance

    final buffer = ByteData(totalSize);
    var offset = 0;

    // Write version
    buffer.setInt32(offset, version, Endian.little);
    offset += 4;

    // Write version group ID (Overwinter)
    buffer.setInt32(offset, versionGroupId, Endian.little);
    offset += 4;

    // Write number of inputs
    offset = writeVarInt(buffer, offset, inputs.length);

    // Write inputs
    for (var input in inputs) {
      offset = input.serialize(buffer, offset);
    }

    // Write number of outputs
    offset = writeVarInt(buffer, offset, outputs.length);

    // Write outputs
    for (var output in outputs) {
      offset = output.serialize(buffer, offset);
    }

    // Write lock time
    buffer.setInt32(offset, lockTime, Endian.little);
    offset += 4;

    // Write expiry height (Overwinter)
    buffer.setInt32(offset, expiryHeight, Endian.little);
    offset += 4;

    // Write value balance (Overwinter)
    buffer.setInt64(offset, valueBalance, Endian.little);
    offset += 8;

    return buffer.buffer.asUint8List(0, offset);
  }

  static int varintLength(int number) {
    if (number < 0xfd) return 1;
    if (number <= 0xffff) return 3;
    if (number <= 0xffffffff) return 5;
    return 9;
  }

  static int writeVarInt(ByteData buffer, int offset, int number) {
    if (number < 0xfd) {
      buffer.setUint8(offset, number);
      return offset + 1;
    }
    if (number <= 0xffff) {
      buffer.setUint8(offset, 0xfd);
      buffer.setUint16(offset + 1, number, Endian.little);
      return offset + 3;
    }
    if (number <= 0xffffffff) {
      buffer.setUint8(offset, 0xfe);
      buffer.setUint32(offset + 1, number, Endian.little);
      return offset + 5;
    }
    buffer.setUint8(offset, 0xff);
    buffer.setInt64(offset + 1, number, Endian.little);
    return offset + 9;
  }
}

class TxInput {
  final Uint8List hash;
  final int index;
  Uint8List script;
  final int sequence;
  Uint8List? signature;
  Uint8List? publicKey;

  TxInput({
    required this.hash,
    required this.index,
    required this.script,
    this.sequence = 0xffffffff,
    this.signature,
    this.publicKey,
  });

  int getSize() {
    return 36 + // hash + index
        Transaction.varintLength(script.length) +
        script.length +
        4; // sequence
  }

  int serialize(ByteData buffer, int offset) {
    buffer.buffer.asUint8List().setRange(offset, offset + 32, hash);
    offset += 32;

    buffer.setUint32(offset, index, Endian.little);
    offset += 4;

    offset = Transaction.writeVarInt(buffer, offset, script.length);
    buffer.buffer.asUint8List().setRange(offset, offset + script.length, script);
    offset += script.length;

    buffer.setUint32(offset, sequence, Endian.little);
    return offset + 4;
  }
}

class TxOutput {
  final int value;
  final Uint8List script;

  TxOutput({
    required this.value,
    required this.script,
  });

  int getSize() {
    return 8 + // value
        Transaction.varintLength(script.length) +
        script.length;
  }

  int serialize(ByteData buffer, int offset) {
    buffer.setInt64(offset, value, Endian.little);
    offset += 8;

    offset = Transaction.writeVarInt(buffer, offset, script.length);
    buffer.buffer.asUint8List().setRange(offset, offset + script.length, script);
    offset += script.length;

    return offset;
  }
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

  ElectrumService() {
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

  String _getScriptHash(String address) {
    if (_scriptHashCache.containsKey(address)) {
      return _scriptHashCache[address]!;
    }

    try {
      WalletLogger.debug('Calculating script hash for address: $address');

      final decoded = bs58check.decode(address);
      WalletLogger.debug('Decoded address bytes: ${decoded.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}');

      final pubKeyHash = decoded.sublist(2);
      WalletLogger.debug('PubKeyHash: ${pubKeyHash.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}');

      final script = Uint8List(pubKeyHash.length + 5);
      script[0] = 0x76; // OP_DUP
      script[1] = 0xa9; // OP_HASH160
      script[2] = 0x14; // Push 20 bytes
      script.setRange(3, 3 + pubKeyHash.length, pubKeyHash);
      script[script.length - 2] = 0x88; // OP_EQUALVERIFY
      script[script.length - 1] = 0xac; // OP_CHECKSIG

      WalletLogger.debug('Script: ${script.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}');

      final hash = sha256.convert(script);
      WalletLogger.debug('SHA256: ${hash.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}');

      final reversedHash = hash.bytes.reversed.toList();
      final scriptHash = HEX.encode(reversedHash);

      WalletLogger.debug('Final script hash: $scriptHash');

      _scriptHashCache[address] = scriptHash;
      return scriptHash;
    } catch (e, stackTrace) {
      WalletLogger.error('Failed to calculate script hash', e, stackTrace);
      throw Exception('Invalid address format');
    }
  }

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
      return Map<String, dynamic>.from({'feeRate': response});
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

  // Transaction helper methods
  Uint8List _createP2PKHScript(Uint8List publicKeyHash) {
    final script = Uint8List(publicKeyHash.length + 5);
    script[0] = 0x76; // OP_DUP
    script[1] = 0xa9; // OP_HASH160
    script[2] = 0x14; // Push 20 bytes
    script.setRange(3, 3 + publicKeyHash.length, publicKeyHash);
    script[script.length - 2] = 0x88; // OP_EQUALVERIFY
    script[script.length - 1] = 0xac; // OP_CHECKSIG
    return script;
  }

  Uint8List _decodeWIF(String wif) {
    final decoded = bs58check.decode(wif);
    return decoded.sublist(1, decoded.length - 1);
  }

  Uint8List _sign(Uint8List messageHash, Uint8List privateKey) {
    final privKey = ECPrivateKey(
      BigInt.parse(HEX.encode(privateKey), radix: 16),
      ECDomainParameters('secp256k1'),
    );

    final secureRandom = FortunaRandom();
    final random = Random.secure();
    final seeds = List<int>.generate(32, (i) => random.nextInt(256));
    secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));

    final signer = ECDSASigner(SHA256Digest(), HMac(SHA256Digest(), 64))
      ..init(true, PrivateKeyParameter<ECPrivateKey>(privKey));

    ECSignature sig = signer.generateSignature(messageHash) as ECSignature;

    final n = privKey.parameters!.n;
    final halfN = n >> 1;
    if (sig.s.compareTo(halfN) > 0) {
      sig = ECSignature(sig.r, n - sig.s);
    }

    return derEncodeSignature(sig.r, sig.s);
  }

  Future<String> createAndBroadcastTransaction({
    required String fromAddress,
    required String toAddress,
    required double amount,
    required String privateKeyWIF,
    double fee = 0.0001,
  }) async {
    WalletLogger.debug('Creating transaction from $fromAddress to $toAddress');

    try {
      final unspentOutputs = await getUnspentOutputs(fromAddress);
      int amountSatoshi = (amount * 1e8).toInt();
      int feeSatoshi = (fee * 1e8).toInt();

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

      int change = totalInputValue - amountSatoshi - feeSatoshi;

      final fromAddressDecoded = bs58check.decode(fromAddress);
      final toAddressDecoded = bs58check.decode(toAddress);
      final fromPubKeyHash = fromAddressDecoded.sublist(2);
      final toPubKeyHash = toAddressDecoded.sublist(2);

      final toScript = _createP2PKHScript(Uint8List.fromList(toPubKeyHash));
      final changeScript = change > 0 ? _createP2PKHScript(Uint8List.fromList(fromPubKeyHash)) : null;

      // Get current block height for expiry height calculation
      final currentHeight = await getCurrentHeight();
      final expiryHeight = currentHeight + 20; // Set expiry 20 blocks in the future

      // Create transaction with BitcoinZ Overwinter format
      final tx = Transaction(
        version: 3, // Overwinter version
        versionGroupId: 0x03C48270, // BitcoinZ Overwinter version group ID
        inputs: selectedUTXOs.map((utxo) {
          final txid = HEX.decode(utxo['tx_hash']).reversed.toList();
          return TxInput(
            hash: Uint8List.fromList(txid),
            index: utxo['tx_pos'],
            script: Uint8List(0),
          );
        }).toList(),
        outputs: [
          TxOutput(value: amountSatoshi, script: toScript),
          if (change > 0) TxOutput(value: change, script: changeScript!),
        ],
        expiryHeight: expiryHeight,
        valueBalance: 0,
      );

      final privateKey = _decodeWIF(privateKeyWIF);
      final keyPair = bip32.BIP32.fromPrivateKey(privateKey, Uint8List(32));

      for (var i = 0; i < tx.inputs.length; i++) {
        final input = tx.inputs[i];
        final sigHash = sha256.convert(tx.serialize()).bytes;
        final signature = _sign(Uint8List.fromList(sigHash), privateKey);

        input.signature = signature;
        input.publicKey = keyPair.publicKey;

        final signatureWithHashType = Uint8List(signature.length + 1);
        signatureWithHashType.setRange(0, signature.length, signature);
        signatureWithHashType[signature.length] = 0x01; // SIGHASH_ALL

        final scriptSig = Uint8List(signatureWithHashType.length + input.publicKey!.length + 2);
        scriptSig[0] = signatureWithHashType.length;
        scriptSig.setRange(1, 1 + signatureWithHashType.length, signatureWithHashType);
        scriptSig[signatureWithHashType.length + 1] = input.publicKey!.length;
        scriptSig.setRange(
          signatureWithHashType.length + 2,
          signatureWithHashType.length + 2 + input.publicKey!.length,
          input.publicKey!,
        );

        input.script = scriptSig;
      }

      final rawTx = HEX.encode(tx.serialize());
      WalletLogger.debug('Constructed transaction hex: $rawTx');

      final txId = await broadcastTransaction(rawTx);
      WalletLogger.info('Transaction broadcasted with txId: $txId');
      return txId;
    } catch (e, stackTrace) {
      WalletLogger.error('Failed to create and broadcast transaction', e, stackTrace);
      rethrow;
    }
  }
}
