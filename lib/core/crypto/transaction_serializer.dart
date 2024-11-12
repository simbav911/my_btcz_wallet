import 'dart:typed_data';
import 'package:hex/hex.dart';
import 'package:my_btcz_wallet/core/crypto/transaction_utils.dart';
import 'package:my_btcz_wallet/core/constants/bitcoinz_constants.dart';

class TransactionSerializer {
  static String serializeToHex(Map<String, dynamic> txData) {
    final buffer = BytesBuilder();

    // Header with Sapling version and version group ID
    buffer.add(TransactionUtils.writeUint32LE(BitcoinZConstants.SAPLING_VERSION));
    buffer.add(TransactionUtils.writeUint32LE(TransactionUtils.BTCZ_VERSION_GROUP_ID));

    // Inputs
    final inputs = txData['inputs'] as List;
    buffer.add(TransactionUtils.writeCompactSize(inputs.length));
    for (final input in inputs) {
      // Previous transaction hash (reversed)
      buffer.add(Uint8List.fromList(HEX.decode(input['txid']).reversed.toList()));
      // Output index
      buffer.add(TransactionUtils.writeUint32LE(input['vout'] as int));
      // ScriptSig
      final scriptSig = input['scriptSig'] as Uint8List;
      buffer.add(TransactionUtils.writeCompactSize(scriptSig.length));
      buffer.add(scriptSig);
      // Sequence
      buffer.add(TransactionUtils.writeUint32LE(input['sequence'] as int));
    }

    // Outputs
    final outputs = txData['outputs'] as List;
    buffer.add(TransactionUtils.writeCompactSize(outputs.length));
    for (final output in outputs) {
      // Amount (in satoshis)
      buffer.add(TransactionUtils.writeUint64LE(output['value'] as int));
      // ScriptPubKey
      final scriptPubKey = output['scriptPubKey'] as Uint8List;
      buffer.add(TransactionUtils.writeCompactSize(scriptPubKey.length));
      buffer.add(scriptPubKey);
    }

    // Locktime
    buffer.add(TransactionUtils.writeUint32LE(txData['locktime'] as int));

    // Expiry height (Sapling)
    buffer.add(TransactionUtils.writeUint32LE(txData['expiryHeight'] as int));

    // Value balance (Sapling)
    buffer.add(TransactionUtils.writeUint64LE(txData['valueBalance'] as int));

    // Sapling spends (empty array for transparent tx)
    buffer.add(TransactionUtils.writeCompactSize(0));

    // Sapling outputs (empty array for transparent tx)
    buffer.add(TransactionUtils.writeCompactSize(0));

    // JoinSplits (empty array for transparent tx)
    buffer.add(TransactionUtils.writeCompactSize(0));

    return HEX.encode(buffer.toBytes());
  }

  static Map<String, dynamic> deserializeFromHex(String hex) {
    final data = HEX.decode(hex);
    var offset = 0;

    // Helper function to read VarInt
    int readVarInt() {
      final firstByte = data[offset++];
      if (firstByte < 0xfd) {
        return firstByte;
      } else if (firstByte == 0xfd) {
        final value = data[offset] | (data[offset + 1] << 8);
        offset += 2;
        return value;
      } else if (firstByte == 0xfe) {
        final value = data[offset] |
            (data[offset + 1] << 8) |
            (data[offset + 2] << 16) |
            (data[offset + 3] << 24);
        offset += 4;
        return value;
      } else {
        final value = data[offset] |
            (data[offset + 1] << 8) |
            (data[offset + 2] << 16) |
            (data[offset + 3] << 24) |
            (data[offset + 4] << 32) |
            (data[offset + 5] << 40) |
            (data[offset + 6] << 48) |
            (data[offset + 7] << 56);
        offset += 8;
        return value;
      }
    }

    // Read 4 bytes as little-endian uint32
    int readUint32() {
      final value = data[offset] |
          (data[offset + 1] << 8) |
          (data[offset + 2] << 16) |
          (data[offset + 3] << 24);
      offset += 4;
      return value;
    }

    // Read 8 bytes as little-endian uint64
    int readUint64() {
      final value = data[offset] |
          (data[offset + 1] << 8) |
          (data[offset + 2] << 16) |
          (data[offset + 3] << 24) |
          (data[offset + 4] << 32) |
          (data[offset + 5] << 40) |
          (data[offset + 6] << 48) |
          (data[offset + 7] << 56);
      offset += 8;
      return value;
    }

    // Read bytes of specified length
    Uint8List readBytes(int length) {
      final bytes = data.sublist(offset, offset + length);
      offset += length;
      return Uint8List.fromList(bytes);
    }

    final txData = <String, dynamic>{
      'version': readUint32(),
      'versionGroupId': readUint32(),
      'inputs': <Map<String, dynamic>>[],
      'outputs': <Map<String, dynamic>>[],
    };

    // Read inputs
    final numInputs = readVarInt();
    for (var i = 0; i < numInputs; i++) {
      final txid = HEX.encode(readBytes(32).reversed.toList());
      final vout = readUint32();
      final scriptLength = readVarInt();
      final scriptSig = readBytes(scriptLength);
      final sequence = readUint32();

      txData['inputs'].add({
        'txid': txid,
        'vout': vout,
        'scriptSig': scriptSig,
        'sequence': sequence,
      });
    }

    // Read outputs
    final numOutputs = readVarInt();
    for (var i = 0; i < numOutputs; i++) {
      final value = readUint64();
      final scriptLength = readVarInt();
      final scriptPubKey = readBytes(scriptLength);

      txData['outputs'].add({
        'value': value,
        'scriptPubKey': scriptPubKey,
      });
    }

    // Read remaining Sapling fields
    txData['locktime'] = readUint32();
    txData['expiryHeight'] = readUint32();
    txData['valueBalance'] = readUint64();

    // Skip empty Sapling arrays
    readVarInt(); // vShieldedSpend
    readVarInt(); // vShieldedOutput
    readVarInt(); // vJoinSplit

    return txData;
  }
}
