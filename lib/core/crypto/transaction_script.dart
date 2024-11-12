import 'dart:typed_data';
import 'package:bs58check/bs58check.dart' as bs58check;
import 'package:my_btcz_wallet/core/error/failures.dart';
import 'package:my_btcz_wallet/core/crypto/transaction_utils.dart';
import 'package:my_btcz_wallet/core/constants/bitcoinz_constants.dart';

class TransactionScript {
  static Uint8List createOutputScript(String address) {
    try {
      // Decode the base58check address
      final decoded = bs58check.decode(address);

      // BitcoinZ uses 0x1CB8 (t-address), so first two bytes are version
      // Remove the version bytes (first 2 bytes)
      final pubKeyHash = Uint8List.fromList(decoded.sublist(2));

      // Create P2PKH script: OP_DUP OP_HASH160 <pubKeyHash> OP_EQUALVERIFY OP_CHECKSIG
      final script = BytesBuilder();
      script.addByte(0x76); // OP_DUP
      script.addByte(0xa9); // OP_HASH160
      script.addByte(0x14); // Push 20 bytes
      script.add(pubKeyHash);
      script.addByte(0x88); // OP_EQUALVERIFY
      script.addByte(0xac); // OP_CHECKSIG

      return script.toBytes();
    } catch (e) {
      throw CryptoFailure(
        message: 'Failed to create output script: ${e.toString()}',
        code: 'OUTPUT_SCRIPT_ERROR',
      );
    }
  }

  static Uint8List createScriptSig(Uint8List signature, Uint8List publicKey) {
    try {
      final scriptSig = BytesBuilder();

      // Add signature with DER encoding and SIGHASH_ALL
      scriptSig.addByte(signature.length);
      scriptSig.add(signature);

      // Add public key
      scriptSig.addByte(publicKey.length);
      scriptSig.add(publicKey);

      return scriptSig.toBytes();
    } catch (e) {
      throw CryptoFailure(
        message: 'Failed to create scriptSig: ${e.toString()}',
        code: 'SCRIPTSIG_ERROR',
      );
    }
  }

  static Uint8List getScriptPubKeyFromAddress(String address) {
    try {
      final decoded = bs58check.decode(address);
      if (decoded.length < 2) {
        throw CryptoFailure(
          message: 'Invalid address length',
          code: 'INVALID_ADDRESS',
        );
      }

      // Check version bytes for BitcoinZ t-address (0x1CB8)
      if (decoded[0] != 0x1C || decoded[1] != 0xB8) {
        throw CryptoFailure(
          message: 'Invalid address version',
          code: 'INVALID_ADDRESS_VERSION',
        );
      }

      final pubKeyHash = decoded.sublist(2);
      if (pubKeyHash.length != 20) {
        throw CryptoFailure(
          message: 'Invalid public key hash length',
          code: 'INVALID_PUBKEY_HASH',
        );
      }

      return createP2PKHScript(Uint8List.fromList(pubKeyHash));
    } catch (e) {
      throw CryptoFailure(
        message: 'Failed to get scriptPubKey from address: ${e.toString()}',
        code: 'SCRIPTPUBKEY_ERROR',
      );
    }
  }

  static Uint8List createP2PKHScript(Uint8List pubKeyHash) {
    if (pubKeyHash.length != 20) {
      throw CryptoFailure(
        message: 'Public key hash must be 20 bytes',
        code: 'INVALID_PUBKEY_HASH_LENGTH',
      );
    }

    final script = BytesBuilder();
    script.addByte(0x76); // OP_DUP
    script.addByte(0xa9); // OP_HASH160
    script.addByte(0x14); // Push 20 bytes
    script.add(pubKeyHash);
    script.addByte(0x88); // OP_EQUALVERIFY
    script.addByte(0xac); // OP_CHECKSIG
    return script.toBytes();
  }

  static Uint8List createRedeemScript(Uint8List publicKey) {
    final script = BytesBuilder();
    script.addByte(publicKey.length);
    script.add(publicKey);
    script.addByte(0xac); // OP_CHECKSIG
    return script.toBytes();
  }

  static Uint8List createSignatureScript(Uint8List signature, Uint8List publicKey) {
    final script = BytesBuilder();

    // Add signature with length prefix
    script.addByte(signature.length);
    script.add(signature);

    // Add public key with length prefix
    script.addByte(publicKey.length);
    script.add(publicKey);

    return script.toBytes();
  }

  static bool verifyScript(Uint8List scriptSig, Uint8List scriptPubKey) {
    try {
      // Verify script lengths
      if (scriptSig.isEmpty || scriptPubKey.isEmpty) {
        return false;
      }

      // Extract signature and public key from scriptSig
      var offset = 0;
      final sigLength = scriptSig[offset++];
      final signature = scriptSig.sublist(offset, offset + sigLength);
      offset += sigLength;
      final pubKeyLength = scriptSig[offset++];
      final publicKey = scriptSig.sublist(offset, offset + pubKeyLength);

      // Verify signature length (DER encoding + SIGHASH_ALL)
      if (signature.length < 70 || signature.length > 73) {
        return false;
      }

      // Verify public key length (compressed or uncompressed)
      if (publicKey.length != 33 && publicKey.length != 65) {
        return false;
      }

      // Verify public key prefix for compressed keys
      if (publicKey.length == 33 && 
          (publicKey[0] != 0x02 && publicKey[0] != 0x03)) {
        return false;
      }

      // Verify public key prefix for uncompressed keys
      if (publicKey.length == 65 && publicKey[0] != 0x04) {
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }
}
