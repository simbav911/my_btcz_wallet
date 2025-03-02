import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:hex/hex.dart';
import 'package:bs58check/bs58check.dart' as bs58check;
import 'package:my_btcz_wallet/core/utils/logger.dart';

class _QueuedRequest {
  final String method;
  final List<dynamic> params;
  final Completer<dynamic> completer;

  _QueuedRequest(this.method, this.params, this.completer);
}

class WebElectrumServiceImpl extends WebElectrumService {
  final Map<String, String> _scriptHashCache = {};

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
}