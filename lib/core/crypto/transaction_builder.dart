import 'dart:typed_data';
import 'package:hex/hex.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/ecc/api.dart';
import 'package:pointycastle/signers/ecdsa_signer.dart';
import 'package:pointycastle/macs/hmac.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/digests/blake2b.dart';
import 'package:bs58check/bs58check.dart' as bs58check;
import 'package:my_btcz_wallet/core/crypto/transaction_utils.dart';
import 'package:my_btcz_wallet/core/crypto/transaction_script.dart';
import 'package:my_btcz_wallet/core/error/failures.dart';
import 'package:my_btcz_wallet/core/network/electrum_service.dart';

class TransactionBuilder {
  // Use the correct Sapling branch ID
  static const int CONSENSUS_BRANCH_ID = 0x76B809BB;
  static const int SIGHASH_ALL = 0x01;

  static Future<Map<String, dynamic>> createAndSignTransaction(
    List<Map<String, dynamic>> inputs,
    String toAddress,
    double amount,
    String fromAddress,
    String privateKeyWIF,
    double fee,
    ElectrumService electrumService,
  ) async {
    // Get current network height for expiry calculation
    final currentHeight = await electrumService.getCurrentHeight();
    final expiryHeight = currentHeight + TransactionUtils.BTCZ_EXPIRY_OFFSET;

    // Prepare transaction data with updated BitcoinZ version parameters
    final txData = <String, dynamic>{
      'version': TransactionUtils.BTCZ_VERSION,
      'versionGroupId': TransactionUtils.BTCZ_VERSION_GROUP_ID,
      'locktime': 0,
      'expiryHeight': expiryHeight,
      'valueBalance': 0, // No shielded components
      'vShieldedSpend': [],
      'vShieldedOutput': [],
      'vJoinSplit': [],
      'inputs': <Map<String, dynamic>>[],
      'outputs': <Map<String, dynamic>>[],
    };

    // Build inputs
    for (final input in inputs) {
      final scriptPubKey = TransactionScript.getScriptPubKeyFromAddress(fromAddress);
      (txData['inputs'] as List).add({
        'txid': input['tx_hash'],
        'vout': input['tx_pos'],
        'sequence': 0xffffffff,
        'scriptSig': '',
        'value': input['value'],
        'address': fromAddress,
        'scriptPubKey': scriptPubKey,
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
    final recipientScript = TransactionScript.getScriptPubKeyFromAddress(toAddress);
    (txData['outputs'] as List).add({
      'address': toAddress,
      'value': amountToSend,
      'scriptPubKey': recipientScript,
    });

    // Change output if needed
    if (changeValue > 0) {
      final changeScript = TransactionScript.getScriptPubKeyFromAddress(fromAddress);
      (txData['outputs'] as List).add({
        'address': fromAddress,
        'value': changeValue,
        'scriptPubKey': changeScript,
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
      final publicKey = _getPublicKey(privateKeyBytes);

      for (int i = 0; i < (txData['inputs'] as List).length; i++) {
        final input = (txData['inputs'] as List)[i];
        final scriptCode = input['scriptPubKey'] as Uint8List;
        final value = input['value'] as int;

        // Create signing hash with consensus branch ID
        final sigHash = _createSigningHash(txData, i, scriptCode, value);

        // Sign the hash
        final signature = _sign(sigHash, privateKey);

        // Append SIGHASH_ALL to the signature
        final signatureWithHashType = Uint8List.fromList([...signature, SIGHASH_ALL]);

        // Create scriptSig using the new method
        final scriptSig = TransactionScript.createSignatureScript(signatureWithHashType, publicKey);

        // Verify the script
        if (!TransactionScript.verifyScript(scriptSig, scriptCode)) {
          throw CryptoFailure(
            message: 'Script verification failed for input $i',
            code: 'SCRIPT_VERIFY_ERROR',
          );
        }

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

    // Header
    preimage.add(_writeUint32LE(txData['version'] as int));
    preimage.add(_writeUint32LE(txData['versionGroupId'] as int));

    // Previous outputs hash
    final prevouts = BytesBuilder();
    for (final input in txData['inputs'] as List) {
      prevouts.add(Uint8List.fromList(HEX.decode(input['txid']).reversed.toList()));
      prevouts.add(_writeUint32LE(input['vout'] as int));
    }
    final hashPrevouts = _blake2bHash(prevouts.toBytes());
    preimage.add(hashPrevouts);

    // Sequence hash
    final sequences = BytesBuilder();
    for (final input in txData['inputs'] as List) {
      sequences.add(_writeUint32LE(input['sequence'] as int));
    }
    final hashSequence = _blake2bHash(sequences.toBytes());
    preimage.add(hashSequence);

    // Outputs hash
    final outputs = BytesBuilder();
    for (final output in txData['outputs'] as List) {
      outputs.add(_writeUint64LE(output['value'] as int));
      final scriptPubKey = output['scriptPubKey'] as Uint8List;
      outputs.add(TransactionUtils.writeCompactSize(scriptPubKey.length));
      outputs.add(scriptPubKey);
    }
    final hashOutputs = _blake2bHash(outputs.toBytes());
    preimage.add(hashOutputs);

    // Additional fields
    preimage.add(_writeUint32LE(txData['locktime'] as int));
    preimage.add(_writeUint32LE(txData['expiryHeight'] as int));
    preimage.add(_writeUint64LE(txData['valueBalance'] as int));
    preimage.add(_writeUint32LE(SIGHASH_ALL));

    // Current input
    preimage.add(Uint8List.fromList(HEX.decode(txData['inputs'][inputIndex]['txid']).reversed.toList()));
    preimage.add(_writeUint32LE(txData['inputs'][inputIndex]['vout'] as int));
    preimage.add(TransactionUtils.writeCompactSize(scriptCode.length));
    preimage.add(scriptCode);
    preimage.add(_writeUint64LE(value));
    preimage.add(_writeUint32LE(txData['inputs'][inputIndex]['sequence'] as int));

    // Create personalization for BLAKE2b
    final personalization = Uint8List(16); // 16 bytes for personalization
    final prefix = 'ZcashSigHash';
    for (var i = 0; i < prefix.length; i++) {
      personalization[i] = prefix.codeUnitAt(i);
    }
    // Add consensus branch ID in big-endian
    personalization[12] = (CONSENSUS_BRANCH_ID >> 24) & 0xFF;
    personalization[13] = (CONSENSUS_BRANCH_ID >> 16) & 0xFF;
    personalization[14] = (CONSENSUS_BRANCH_ID >> 8) & 0xFF;
    personalization[15] = CONSENSUS_BRANCH_ID & 0xFF;

    // Create BLAKE2b digest with personalization
    final digest = Blake2bDigest(digestSize: 32, personalization: personalization);
    final preimageBytes = preimage.toBytes();
    digest.update(preimageBytes, 0, preimageBytes.length);
    final hash = Uint8List(32);
    digest.doFinal(hash, 0);

    return hash;
  }

  static Uint8List _blake2bHash(Uint8List data) {
    final digest = Blake2bDigest(digestSize: 32);
    digest.update(data, 0, data.length);
    final hash = Uint8List(32);
    digest.doFinal(hash, 0);
    return hash;
  }

  static Uint8List _sign(Uint8List messageHash, ECPrivateKey privateKey) {
    final signer = ECDSASigner(SHA256Digest(), HMac(SHA256Digest(), 64));
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
