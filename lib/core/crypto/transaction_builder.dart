import 'dart:typed_data';
import 'package:hex/hex.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/ecc/api.dart';
import 'package:pointycastle/signers/ecdsa_signer.dart';
import 'package:pointycastle/macs/hmac.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:bs58check/bs58check.dart' as bs58check;
import 'package:my_btcz_wallet/core/crypto/transaction_utils.dart';
import 'package:my_btcz_wallet/core/crypto/transaction_script.dart';
import 'package:my_btcz_wallet/core/error/failures.dart';

class TransactionBuilder {
  static Future<Map<String, dynamic>> createAndSignTransaction(
    List<Map<String, dynamic>> inputs,
    String toAddress,
    double amount,
    String fromAddress,
    String privateKeyWIF,
    double fee,
  ) async {
    // Calculate expiry height
    final currentHeight = inputs[0]['height'] as int? ?? 0;
    final expiryHeight = TransactionUtils.calculateExpiryHeight(currentHeight);

    // Prepare transaction data with BitcoinZ Overwinter version
    final txData = <String, dynamic>{
      'version': TransactionUtils.BTCZ_VERSION,
      'versionGroupId': TransactionUtils.BTCZ_VERSION_GROUP_ID,
      'locktime': 0,
      'expiryHeight': expiryHeight,
      'inputs': <Map<String, dynamic>>[],
      'outputs': <Map<String, dynamic>>[],
    };

    // Build inputs
    for (final input in inputs) {
      (txData['inputs'] as List).add({
        'txid': input['tx_hash'],
        'vout': input['tx_pos'],
        'sequence': 0xffffffff,
        'scriptSig': '',
        'value': input['value'],
        'address': fromAddress,
        'scriptPubKey': TransactionScript.createOutputScript(fromAddress),
      });
    }

    // Build outputs
    final totalInputValue = inputs.fold<int>(
        0, (sum, input) => sum + (input['value'] as int));
    final amountToSend = (amount * 100000000).round();
    final feeInSatoshis = (fee * 100000000).round();
    final changeValue = totalInputValue - amountToSend - feeInSatoshis;

    if (changeValue < 0) {
      throw const CryptoFailure(
        message: 'Insufficient funds after fee',
        code: 'INSUFFICIENT_FUNDS_FEE',
      );
    }

    // Output to recipient
    (txData['outputs'] as List).add({
      'address': toAddress,
      'value': amountToSend,
    });

    // Change output if needed
    if (changeValue > 0) {
      (txData['outputs'] as List).add({
        'address': fromAddress,
        'value': changeValue,
      });
    }

    // Sign transaction
    return await _signTransaction(txData, privateKeyWIF);
  }

  static Future<Map<String, dynamic>> _signTransaction(
    Map<String, dynamic> txData,
    String privateKeyWIF,
  ) async {
    try {
      // Decode WIF private key
      final decoded = bs58check.decode(privateKeyWIF);
      // Remove version byte (1 byte) and compression flag (1 byte)
      final privateKeyBytes = decoded.sublist(1, decoded.length - 1);
      
      final privateKeyNum = BigInt.parse(HEX.encode(privateKeyBytes), radix: 16);
      final domainParams = ECDomainParameters('secp256k1');
      final privateKey = ECPrivateKey(privateKeyNum, domainParams);

      for (int i = 0; i < (txData['inputs'] as List).length; i++) {
        final input = (txData['inputs'] as List)[i];

        final scriptCode = input['scriptPubKey'] as Uint8List;
        final value = input['value'] as int;

        // Create signing hash with Overwinter fields
        final sigHash = _createSigningHash(txData, i, scriptCode, value);

        // Sign the hash
        final signature = _sign(sigHash, privateKey);

        // Append SIGHASH_ALL to the signature
        final signatureWithHashType = Uint8List.fromList([...signature, 0x01]);

        // Create scriptSig
        final scriptSig = TransactionScript.createScriptSig(
            signatureWithHashType, _getPublicKey(privateKeyBytes));

        // Update the input
        (txData['inputs'] as List)[i]['scriptSig'] = scriptSig;
      }

      return txData;
    } catch (e) {
      throw CryptoFailure(
        message: 'Failed to sign transaction: ${e.toString()}',
        code: 'TRANSACTION_SIGNING_ERROR',
      );
    }
  }

  static Uint8List _createSigningHash(
    Map<String, dynamic> txData,
    int inputIndex,
    Uint8List scriptCode,
    int value,
  ) {
    final preimage = BytesBuilder();

    // Header with Overwinter fields
    preimage.add(_writeUint32LE(txData['version'] as int));
    preimage.add(_writeUint32LE(txData['versionGroupId'] as int));

    // Previous outputs hash
    final prevouts = BytesBuilder();
    for (final input in txData['inputs'] as List) {
      prevouts.add(HEX.decode(input['txid']).reversed.toList());
      prevouts.add(_writeUint32LE(input['vout'] as int));
    }
    preimage.add(TransactionUtils.doubleSha256(prevouts.toBytes()));

    // Sequence hash
    final sequences = BytesBuilder();
    for (final input in txData['inputs'] as List) {
      sequences.add(_writeUint32LE(input['sequence'] as int));
    }
    preimage.add(TransactionUtils.doubleSha256(sequences.toBytes()));

    // Outputs hash
    final outputs = BytesBuilder();
    for (final output in txData['outputs'] as List) {
      outputs.add(_writeUint64LE(output['value'] as int));
      final scriptPubKey = TransactionScript.createOutputScript(output['address'] as String);
      outputs.add(TransactionUtils.writeCompactSize(scriptPubKey.length));
      outputs.add(scriptPubKey);
    }
    preimage.add(TransactionUtils.doubleSha256(outputs.toBytes()));

    // Additional fields
    preimage.add(_writeUint32LE(txData['locktime'] as int));
    preimage.add(_writeUint32LE(txData['expiryHeight'] as int));
    preimage.add(_writeUint32LE(1)); // SIGHASH_ALL

    // Current input
    preimage.add(HEX.decode(txData['inputs'][inputIndex]['txid']).reversed.toList());
    preimage.add(_writeUint32LE(txData['inputs'][inputIndex]['vout'] as int));
    preimage.add(TransactionUtils.writeCompactSize(scriptCode.length));
    preimage.add(scriptCode);
    preimage.add(_writeUint64LE(value));
    preimage.add(_writeUint32LE(txData['inputs'][inputIndex]['sequence'] as int));

    return TransactionUtils.doubleSha256(preimage.toBytes());
  }

  static Uint8List _sign(Uint8List messageHash, ECPrivateKey privateKey) {
    final signer = ECDSASigner(null, HMac(SHA256Digest(), 64));
    signer.init(true, PrivateKeyParameter<ECPrivateKey>(privateKey));

    ECSignature sig = signer.generateSignature(messageHash) as ECSignature;

    // Ensure low S value
    final n = privateKey.parameters!.n;
    final halfN = n >> 1;
    if (sig.s.compareTo(halfN) > 0) {
      sig = ECSignature(sig.r, n - sig.s);
    }

    return Uint8List.fromList(TransactionUtils.encodeDER(sig.r, sig.s));
  }

  static Uint8List _getPublicKey(Uint8List privateKeyBytes) {
    final domainParams = ECDomainParameters('secp256k1');
    final privateKeyNum = BigInt.parse(HEX.encode(privateKeyBytes), radix: 16);
    final privateKey = ECPrivateKey(privateKeyNum, domainParams);
    final publicKey = domainParams.G * privateKey.d;
    
    // Get X and Y coordinates
    final x = publicKey!.x!.toBigInteger()!;
    final y = publicKey.y!.toBigInteger()!;
    
    // Create compressed public key
    final prefix = y.isEven ? 0x02 : 0x03;
    final xBytes = _padTo32Bytes(x.toRadixString(16));
    
    return Uint8List.fromList([prefix, ...xBytes]);
  }

  static List<int> _padTo32Bytes(String hex) {
    final paddedHex = hex.padLeft(64, '0');
    return HEX.decode(paddedHex);
  }

  // Helper methods for consistent little-endian encoding
  static Uint8List _writeUint32LE(int value) {
    final buffer = Uint8List(4);
    buffer[0] = value & 0xFF;
    buffer[1] = (value >> 8) & 0xFF;
    buffer[2] = (value >> 16) & 0xFF;
    buffer[3] = (value >> 24) & 0xFF;
    return buffer;
  }

  static Uint8List _writeUint64LE(int value) {
    final buffer = Uint8List(8);
    buffer[0] = value & 0xFF;
    buffer[1] = (value >> 8) & 0xFF;
    buffer[2] = (value >> 16) & 0xFF;
    buffer[3] = (value >> 24) & 0xFF;
    buffer[4] = (value >> 32) & 0xFF;
    buffer[5] = (value >> 40) & 0xFF;
    buffer[6] = (value >> 48) & 0xFF;
    buffer[7] = (value >> 56) & 0xFF;
    return buffer;
  }
}
