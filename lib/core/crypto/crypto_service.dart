import 'dart:typed_data';
import 'package:bip32/bip32.dart' as bip32;
import 'package:bip39/bip39.dart' as bip39;
import 'package:bs58check/bs58check.dart' as bs58check;
import 'package:crypto/crypto.dart';
import 'package:hex/hex.dart';
import 'package:my_btcz_wallet/core/error/failures.dart';
import 'package:pointycastle/digests/ripemd160.dart';

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
      final sha256Hash = Uint8List.fromList(sha256.convert(publicKey).bytes);

      // 2. Perform RIPEMD-160 hashing on the result
      final ripemd160 = RIPEMD160Digest();
      final ripemd160Hash = Uint8List(20);
      ripemd160.update(sha256Hash, 0, sha256Hash.length);
      ripemd160.doFinal(ripemd160Hash, 0);

      // 3. Add version bytes (0x1CB8 = [0x1C, 0xB8])
      final versionedHash = Uint8List(22);
      versionedHash[0] = 0x1C;
      versionedHash[1] = 0xB8;
      versionedHash.setRange(2, 22, ripemd160Hash);

      // 4. Create checksum (first 4 bytes of double SHA-256)
      final checksum = sha256
          .convert(sha256.convert(versionedHash).bytes)
          .bytes
          .sublist(0, 4);

      // 5. Create final binary address
      final binaryAddress = Uint8List(26);
      binaryAddress.setRange(0, 22, versionedHash);
      binaryAddress.setRange(22, 26, checksum);

      // 6. Convert to base58
      final address = bs58check.encode(binaryAddress);
      
      // 7. Add 't' prefix for BitcoinZ
      return 't$address';
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
