import 'dart:typed_data';
import 'package:bip32/bip32.dart' as bip32;
import 'package:bip39/bip39.dart' as bip39;
import 'package:bs58check/bs58check.dart' as bs58check;
import 'package:crypto/crypto.dart';
import 'package:hex/hex.dart';
import 'package:pointycastle/digests/ripemd160.dart';
import 'package:my_btcz_wallet/core/error/failures.dart';

class CryptoService {
  // BitcoinZ network constants
  static const int _btczPurpose = 44;      // BIP44
  static const int _btczCoinType = 177;    // BitcoinZ
  static const int _btczVersion = 0x1CB8;  // Updated BitcoinZ mainnet version for t1 addresses
  static const int _btczP2PKHVersion = 0x1CB8;  // Updated P2PKH version
  static const int _btczP2SHVersion = 0x1CBD;   // P2SH version
  static const int _btczWIFVersion = 0x80;      // WIF version

  // Generate new mnemonic (12 words for BitcoinZ compatibility)
  String generateMnemonic() {
    try {
      return bip39.generateMnemonic(strength: 128); // Changed from 256 to 128 for 12 words
    } catch (e) {
      throw CryptoFailure(
        message: 'Failed to generate mnemonic: ${e.toString()}',
        code: 'MNEMONIC_GENERATION_ERROR',
      );
    }
  }

  // Convert private key to WIF format
  String privateKeyToWIF(String privateKeyHex) {
    try {
      // Decode hex private key
      final privateKeyBytes = HEX.decode(privateKeyHex);
      return _privateKeyBytesToWIF(privateKeyBytes);
    } catch (e) {
      throw CryptoFailure(
        message: 'Failed to convert private key to WIF: ${e.toString()}',
        code: 'WIF_CONVERSION_ERROR',
      );
    }
  }

  // Convert private key bytes to WIF format
  String _privateKeyBytesToWIF(List<int> privateKeyBytes) {
    try {
      if (privateKeyBytes.length != 32) {
        throw const CryptoFailure(
          message: 'Invalid private key length',
          code: 'INVALID_PRIVATE_KEY',
        );
      }

      // Create payload with version byte and compression byte
      final payload = Uint8List(34);
      payload[0] = _btczWIFVersion;
      payload.setRange(1, 33, privateKeyBytes);
      payload[33] = 0x01; // Compression flag

      // Encode to WIF format
      return bs58check.encode(payload);
    } catch (e) {
      throw CryptoFailure(
        message: 'Failed to convert private key bytes to WIF: ${e.toString()}',
        code: 'WIF_CONVERSION_ERROR',
      );
    }
  }

  // Validate mnemonic phrase
  bool validateMnemonic(String mnemonic) {
    try {
      return bip39.validateMnemonic(mnemonic);
    } catch (e) {
      return false;
    }
  }

  // Generate master key from mnemonic with additional validation
  Uint8List generateMasterKey(String mnemonic) {
    if (!validateMnemonic(mnemonic)) {
      throw const CryptoFailure(
        message: 'Invalid mnemonic phrase',
        code: 'INVALID_MNEMONIC',
      );
    }

    try {
      final seed = bip39.mnemonicToSeed(mnemonic);
      if (seed.length != 64) {
        throw const CryptoFailure(
          message: 'Invalid seed length',
          code: 'INVALID_SEED',
        );
      }
      return seed;
    } catch (e) {
      throw CryptoFailure(
        message: 'Failed to generate master key: ${e.toString()}',
        code: 'MASTER_KEY_GENERATION_ERROR',
      );
    }
  }

  // Derive private key using BIP44 path with additional validation
  // m/44'/177'/account'/change/index
  Uint8List derivePrivateKey(Uint8List masterKey, int account, int index) {
    try {
      if (masterKey.length != 64) {
        throw const CryptoFailure(
          message: 'Invalid master key length',
          code: 'INVALID_MASTER_KEY',
        );
      }

      final node = bip32.BIP32.fromSeed(masterKey);
      
      // Validate account and index ranges
      if (account < 0 || account > 2147483647) { // 2^31-1
        throw const CryptoFailure(
          message: 'Invalid account number',
          code: 'INVALID_ACCOUNT',
        );
      }
      if (index < 0 || index > 2147483647) {
        throw const CryptoFailure(
          message: 'Invalid address index',
          code: 'INVALID_INDEX',
        );
      }

      final derivedNode = node
          .derivePath("m/$_btczPurpose'/$_btczCoinType'/$account'/0/$index");
      
      final privateKey = derivedNode.privateKey;
      if (privateKey == null || privateKey.length != 32) {
        throw const CryptoFailure(
          message: 'Invalid derived private key',
          code: 'INVALID_PRIVATE_KEY',
        );
      }
      
      return privateKey;
    } catch (e) {
      throw CryptoFailure(
        message: 'Failed to derive private key: ${e.toString()}',
        code: 'KEY_DERIVATION_ERROR',
      );
    }
  }

  // Generate public key from private key with validation
  Uint8List generatePublicKey(Uint8List privateKey) {
    try {
      if (privateKey.length != 32) {
        throw const CryptoFailure(
          message: 'Invalid private key length',
          code: 'INVALID_PRIVATE_KEY',
        );
      }

      final node = bip32.BIP32.fromPrivateKey(
        privateKey,
        Uint8List(32), // chaincode
      );
      
      final publicKey = node.publicKey;
      if (publicKey.length != 33 && publicKey.length != 65) {
        throw const CryptoFailure(
          message: 'Invalid public key length',
          code: 'INVALID_PUBLIC_KEY',
        );
      }
      
      return publicKey;
    } catch (e) {
      throw CryptoFailure(
        message: 'Failed to generate public key: ${e.toString()}',
        code: 'PUBLIC_KEY_GENERATION_ERROR',
      );
    }
  }

  // Generate BitcoinZ address from public key with proper versioning
  String generateAddress(Uint8List publicKey) {
    try {
      if (publicKey.isEmpty) {
        throw const CryptoFailure(
          message: 'Empty public key',
          code: 'EMPTY_PUBLIC_KEY',
        );
      }

      // 1. SHA-256 hash
      final sha256Hash = sha256.convert(publicKey).bytes;

      // 2. RIPEMD-160 hash
      final ripemd160 = RIPEMD160Digest();
      final ripemd160Hash = Uint8List(20);
      ripemd160.update(Uint8List.fromList(sha256Hash), 0, sha256Hash.length);
      ripemd160.doFinal(ripemd160Hash, 0);

      // 3. Add version bytes for t1 address format
      final payload = Uint8List(22);
      payload[0] = (_btczP2PKHVersion >> 8) & 0xFF;
      payload[1] = _btczP2PKHVersion & 0xFF;
      payload.setRange(2, 22, ripemd160Hash);

      // 4. Base58Check encoding
      final address = bs58check.encode(payload);

      // 5. Validate the generated address
      if (!validateAddress(address)) {
        throw const CryptoFailure(
          message: 'Generated invalid address',
          code: 'INVALID_ADDRESS_GENERATED',
        );
      }

      return address;
    } catch (e) {
      throw CryptoFailure(
        message: 'Failed to generate address: ${e.toString()}',
        code: 'ADDRESS_GENERATION_ERROR',
      );
    }
  }

  // Validate BitcoinZ address format
  bool validateAddress(String address) {
    try {
      // Check basic format
      if (!address.startsWith('t1')) {
        return false;
      }

      // Check length
      if (address.length < 34 || address.length > 36) {
        return false;
      }

      // Decode and verify version
      final decoded = bs58check.decode(address);
      if (decoded.length != 22) {
        return false;
      }

      // Check version bytes
      final version = (decoded[0] << 8) | decoded[1];
      return version == _btczP2PKHVersion;
    } catch (e) {
      return false;
    }
  }

  // Sign transaction with additional validation
  Uint8List signTransaction(Uint8List privateKey, Uint8List transactionHash) {
    try {
      if (privateKey.length != 32) {
        throw const CryptoFailure(
          message: 'Invalid private key length',
          code: 'INVALID_PRIVATE_KEY',
        );
      }

      if (transactionHash.length != 32) {
        throw const CryptoFailure(
          message: 'Invalid transaction hash length',
          code: 'INVALID_TRANSACTION_HASH',
        );
      }

      final node = bip32.BIP32.fromPrivateKey(
        privateKey,
        Uint8List(32), // chaincode
      );
      
      final signature = node.sign(transactionHash);
      if (signature.length != 64 && signature.length != 65) {
        throw const CryptoFailure(
          message: 'Invalid signature length',
          code: 'INVALID_SIGNATURE',
        );
      }
      
      return signature;
    } catch (e) {
      throw CryptoFailure(
        message: 'Failed to sign transaction: ${e.toString()}',
        code: 'TRANSACTION_SIGNING_ERROR',
      );
    }
  }

  // Verify signature with additional validation
  bool verifySignature(
    Uint8List publicKey,
    Uint8List signature,
    Uint8List transactionHash,
  ) {
    try {
      if (publicKey.isEmpty || signature.isEmpty || transactionHash.isEmpty) {
        return false;
      }

      final node = bip32.BIP32.fromPublicKey(
        publicKey,
        Uint8List(32), // chaincode
      );
      return node.verify(transactionHash, signature);
    } catch (e) {
      return false;
    }
  }
}
