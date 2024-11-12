import 'dart:typed_data';
import 'package:hex/hex.dart';
import 'package:crypto/crypto.dart';

class TransactionUtils {
  // BitcoinZ Sapling constants
  static const int BTCZ_VERSION = 0x80000004;  // Version 4 with Overwinter bit
  static const int BTCZ_VERSION_GROUP_ID = 0x892F2085;  // Sapling version group ID from Copay
  static const int BTCZ_EXPIRY_OFFSET = 20;  // Number of blocks until expiry

  // Network parameters from Copay
  static const int NETWORK_MAGIC = 0x5A42;
  static const int PUBKEY_HASH = 0x1CB8;
  static const int SCRIPT_HASH = 0x1CBD;
  static const int WIF_PREFIX = 0x80;
  static const int PROTOCOL_MAGIC = 0x24e92764;

  static Uint8List doubleSha256(Uint8List data) {
    final hash1 = sha256.convert(data);
    final hash2 = sha256.convert(hash1.bytes);
    return Uint8List.fromList(hash2.bytes);
  }

  static String doubleSha256Hex(String hexData) {
    final data = HEX.decode(hexData);
    final hash = doubleSha256(Uint8List.fromList(data));
    return HEX.encode(hash);
  }

  static Uint8List writeCompactSize(int size) {
    if (size < 253) {
      return Uint8List.fromList([size]);
    } else if (size <= 0xffff) {
      return Uint8List.fromList([253, size & 0xff, (size >> 8) & 0xff]);
    } else if (size <= 0xffffffff) {
      return Uint8List.fromList([
        254,
        size & 0xff,
        (size >> 8) & 0xff,
        (size >> 16) & 0xff,
        (size >> 24) & 0xff
      ]);
    } else {
      final buffer = Uint8List(9);
      buffer[0] = 255;
      buffer[1] = size & 0xff;
      buffer[2] = (size >> 8) & 0xff;
      buffer[3] = (size >> 16) & 0xff;
      buffer[4] = (size >> 24) & 0xff;
      buffer[5] = (size >> 32) & 0xff;
      buffer[6] = (size >> 40) & 0xff;
      buffer[7] = (size >> 48) & 0xff;
      buffer[8] = (size >> 56) & 0xff;
      return buffer;
    }
  }

  static List<int> encodeDER(BigInt r, BigInt s) {
    final rBytes = _bigIntToBytes(r);
    final sBytes = _bigIntToBytes(s);

    final rSeq = [0x02, rBytes.length, ...rBytes];
    final sSeq = [0x02, sBytes.length, ...sBytes];
    final totalLength = rSeq.length + sSeq.length;
    return [0x30, totalLength, ...rSeq, ...sSeq];
  }

  static List<int> _bigIntToBytes(BigInt value) {
    final bytes = value.toUnsigned(256).toRadixString(16);
    final paddedBytes = bytes.length % 2 == 0 ? bytes : '0$bytes';
    final bytesList = HEX.decode(paddedBytes);
    if (bytesList.isEmpty || (bytesList[0] & 0x80) != 0) {
      return [0x00, ...bytesList];
    }
    return bytesList;
  }

  static String createP2PKHScript(List<int> pubKeyHash) {
    // OP_DUP OP_HASH160 <pubKeyHash> OP_EQUALVERIFY OP_CHECKSIG
    return '76a914' + HEX.encode(pubKeyHash) + '88ac';
  }

  static int calculateExpiryHeight(int currentHeight) {
    return currentHeight + BTCZ_EXPIRY_OFFSET;
  }

  // Helper methods for consistent byte ordering
  static Uint8List writeUint32LE(int value) {
    final buffer = Uint8List(4);
    buffer[0] = value & 0xFF;
    buffer[1] = (value >> 8) & 0xFF;
    buffer[2] = (value >> 16) & 0xFF;
    buffer[3] = (value >> 24) & 0xFF;
    return buffer;
  }

  static Uint8List writeUint32BE(int value) {
    final buffer = Uint8List(4);
    buffer[0] = (value >> 24) & 0xFF;
    buffer[1] = (value >> 16) & 0xFF;
    buffer[2] = (value >> 8) & 0xFF;
    buffer[3] = value & 0xFF;
    return buffer;
  }

  static Uint8List writeUint64LE(int value) {
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

  // Helper methods for transaction fields
  static Uint8List writeVersion() {
    // Version 4 with Overwinter bit (0x80000004)
    // This already includes the fOverwintered flag in the most significant bit
    return writeUint32LE(BTCZ_VERSION);
  }

  static Uint8List writeVersionGroupId() {
    // Version group ID (0x892F2085) in little-endian
    return writeUint32LE(BTCZ_VERSION_GROUP_ID);
  }

  // Calculate transaction size for fee estimation
  static int calculateTransactionSize(int numInputs, int numOutputs) {
    const baseSize = 166;  // Base transaction size from Copay
    const inputSize = 148; // Size per input
    const outputSize = 34; // Size per output
    return baseSize + (inputSize * numInputs) + (outputSize * numOutputs);
  }

  // Calculate minimum fee based on transaction size
  static int calculateMinimumFee(int numInputs, int numOutputs) {
    final size = calculateTransactionSize(numInputs, numOutputs);
    const feeRate = 10; // Satoshis per byte from Copay
    return size * feeRate;
  }
}
