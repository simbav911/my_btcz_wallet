import 'dart:typed_data';
import 'package:hex/hex.dart';
import 'package:my_btcz_wallet/core/crypto/transaction_utils.dart';
import 'package:my_btcz_wallet/core/crypto/transaction_script.dart';
import 'package:my_btcz_wallet/core/utils/logger.dart';

class TransactionSerializer {
  static Uint8List serializeTransaction(Map<String, dynamic> txData) {
    final buffer = BytesBuilder();

    // Version (4 bytes) with Overwinter bit
    final version = TransactionUtils.writeVersion();
    WalletLogger.debug('Version bytes: ${HEX.encode(version)}');
    buffer.add(version);

    // Version Group ID (4 bytes)
    final versionGroupId = TransactionUtils.writeVersionGroupId();
    WalletLogger.debug('Version Group ID bytes: ${HEX.encode(versionGroupId)}');
    buffer.add(versionGroupId);

    // Inputs
    final inputs = txData['inputs'] as List;
    buffer.add(TransactionUtils.writeCompactSize(inputs.length));
    WalletLogger.debug('Input count: ${inputs.length}');

    for (final input in inputs) {
      // txid (32 bytes, reversed)
      final txid = HEX.decode(input['txid']).reversed.toList();
      WalletLogger.debug('Input txid: ${input['txid']} -> ${HEX.encode(txid)}');
      buffer.add(txid);

      // vout (4 bytes, little-endian)
      final vout = TransactionUtils.writeUint32LE(input['vout'] as int);
      WalletLogger.debug('Input vout: ${input['vout']} -> ${HEX.encode(vout)}');
      buffer.add(vout);

      // scriptSig
      final scriptSig = input['scriptSig'] as Uint8List;
      buffer.add(TransactionUtils.writeCompactSize(scriptSig.length));
      buffer.add(scriptSig);
      WalletLogger.debug('Input scriptSig: ${HEX.encode(scriptSig)}');

      // sequence (4 bytes, little-endian)
      final sequence = TransactionUtils.writeUint32LE(input['sequence'] as int);
      WalletLogger.debug('Input sequence: ${input['sequence']} -> ${HEX.encode(sequence)}');
      buffer.add(sequence);
    }

    // Outputs
    final outputs = txData['outputs'] as List;
    buffer.add(TransactionUtils.writeCompactSize(outputs.length));
    WalletLogger.debug('Output count: ${outputs.length}');

    for (final output in outputs) {
      // value (8 bytes, little-endian)
      final value = TransactionUtils.writeUint64LE(output['value'] as int);
      WalletLogger.debug('Output value: ${output['value']} -> ${HEX.encode(value)}');
      buffer.add(value);

      // scriptPubKey
      final scriptPubKey = TransactionScript.createOutputScript(output['address'] as String);
      buffer.add(TransactionUtils.writeCompactSize(scriptPubKey.length));
      buffer.add(scriptPubKey);
      WalletLogger.debug('Output scriptPubKey: ${HEX.encode(scriptPubKey)}');
    }

    // nLockTime (4 bytes, little-endian)
    final locktime = TransactionUtils.writeUint32LE(txData['locktime'] as int);
    WalletLogger.debug('Locktime: ${txData['locktime']} -> ${HEX.encode(locktime)}');
    buffer.add(locktime);

    // nExpiryHeight (4 bytes, little-endian)
    final expiryHeight = TransactionUtils.writeUint32LE(txData['expiryHeight'] as int);
    WalletLogger.debug('Expiry height: ${txData['expiryHeight']} -> ${HEX.encode(expiryHeight)}');
    buffer.add(expiryHeight);

    final result = buffer.toBytes();
    WalletLogger.debug('Final transaction hex: ${HEX.encode(result)}');
    return result;
  }

  static String serializeToHex(Map<String, dynamic> txData) {
    final bytes = serializeTransaction(txData);
    return HEX.encode(bytes);
  }
}
