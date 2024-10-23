import 'dart:typed_data';
import 'package:bip32/bip32.dart' as bip32;
import 'package:bip39/bip39.dart' as bip39;
import 'package:bs58check/bs58check.dart' as bs58check;
import 'package:crypto/crypto.dart';
import 'package:hex/hex.dart';
import 'package:my_btcz_wallet/core/error/failures.dart';

class CryptoService {
  // BitcoinZ specific constants
  static const int _btczPurpose = 44; // BIP44
  static const int _btczCoinType = 177; // BitcoinZ
  static const int _btczVersion = 0x1CB8; // BitcoinZ mainnet version
  static const int _btczP2PKHVersion = 0x1CB8; // BitcoinZ P2PKH version
  static const int _btczP2SHVersion = 0x1CBD; // BitcoinZ P2SH version

  // Generate a new mnemonic phrase (24 words)
  String generateMnemonic() {
    return bip39.generateMnemonic(strength: 256);
  }

  // Validate mnemonic phrase
  bool validateMnemonic(String mnemonic) {
    return bip39.validateMnemonic(mnemonic);
  }

  // Generate master key from mnemonic
  Uint8List generateMasterKey(String mnemonic) {
    if (!validateMnemonic(mnemonic)) {
      throw const CryptoFailure(
        message: 'Invalid mnemonic phrase',
        code: 'INVALID_MNEMONIC',
      );
    }

    final seed = bip39.mnemonicToSeed(mnemonic);
    return seed;
  }

  // Derive private key using BIP44 path
  // m/44'/177'/account'/change/index
  Uint8List derivePrivateKey(Uint8List masterKey, int account, int index) {
    try {
      final node = bip32.BIP32.fromSeed(masterKey);
      
      // Derive the path according to BIP44
      // m/44'/177'/account'/0/index
      final derivedNode = node
          .derivePath("m/$_btczPurpose'/$_btczCoinType'/$account'/0/$index");
      
      return derivedNode.privateKey!;
    } catch (e) {
      throw CryptoFailure(
        message: 'Failed to derive private key: ${e.toString()}',
        code: 'KEY_DERIVATION_ERROR',
      );
    }
  }

  // Generate public key from private key
  Uint8List generatePublicKey(Uint8List privateKey) {
    try {
      final node = bip32.BIP32.fromPrivateKey(
        privateKey,
        Uint8List(32), // chaincode (not needed for public key generation)
      );
      return node.publicKey;
    } catch (e) {
      throw CryptoFailure(
        message: 'Failed to generate public key: ${e.toString()}',
        code: 'PUBLIC_KEY_GENERATION_ERROR',
      );
    }
  }

  // Generate BitcoinZ address from public key
  String generateAddress(Uint8List publicKey) {
    try {
      // 1. Perform SHA-256 hashing on the public key
      final sha256Hash = sha256.convert(publicKey);

      // 2. Perform RIPEMD-160 hashing on the result
      final ripemd160Hash = Uint8List.fromList(
        List<int>.from(sha256Hash.bytes),
      );

      // 3. Add version byte in front of RIPEMD-160 hash
      final versionedHash = Uint8List(21);
      versionedHash[0] = _btczP2PKHVersion >> 8;
      versionedHash[1] = _btczP2PKHVersion & 0xFF;
      versionedHash.setRange(2, 21, ripemd160Hash);

      // 4. Create checksum (first 4 bytes of double SHA-256)
      final checksum = sha256
          .convert(sha256.convert(versionedHash).bytes)
          .bytes
          .sublist(0, 4);

      // 5. Append checksum to versioned hash
      final binaryAddress = Uint8List(25);
      binaryAddress.setRange(0, 21, versionedHash);
      binaryAddress.setRange(21, 25, checksum);

      // 6. Convert to base58
      return bs58check.encode(binaryAddress);
    } catch (e) {
      throw CryptoFailure(
        message: 'Failed to generate address: ${e.toString()}',
        code: 'ADDRESS_GENERATION_ERROR',
      );
    }
  }

  // Sign a transaction
  Uint8List signTransaction(Uint8List privateKey, Uint8List transactionHash) {
    try {
      final node = bip32.BIP32.fromPrivateKey(
        privateKey,
        Uint8List(32), // chaincode (not needed for signing)
      );
      // TODO: Implement proper transaction signing
      return node.sign(transactionHash);
    } catch (e) {
      throw CryptoFailure(
        message: 'Failed to sign transaction: ${e.toString()}',
        code: 'TRANSACTION_SIGNING_ERROR',
      );
    }
  }

  // Verify a signature
  bool verifySignature(
    Uint8List publicKey,
    Uint8List signature,
    Uint8List transactionHash,
  ) {
    try {
      final node = bip32.BIP32.fromPublicKey(
        publicKey,
        Uint8List(32), // chaincode (not needed for verification)
      );
      return node.verify(transactionHash, signature);
    } catch (e) {
      throw CryptoFailure(
        message: 'Failed to verify signature: ${e.toString()}',
        code: 'SIGNATURE_VERIFICATION_ERROR',
      );
    }
  }
}
