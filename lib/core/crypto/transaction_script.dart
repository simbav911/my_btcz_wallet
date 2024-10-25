import 'dart:typed_data';
import 'package:bs58check/bs58check.dart' as bs58check;
import 'package:my_btcz_wallet/core/error/failures.dart';
import 'package:my_btcz_wallet/core/crypto/transaction_utils.dart';

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
    final scriptSig = BytesBuilder();

    // Push signature
    scriptSig.add(TransactionUtils.writeCompactSize(signature.length));
    scriptSig.add(signature);

    // Push public key
    scriptSig.add(TransactionUtils.writeCompactSize(publicKey.length));
    scriptSig.add(publicKey);

    return scriptSig.toBytes();
  }
}
