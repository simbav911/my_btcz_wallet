import 'dart:typed_data';
import 'package:pointycastle/export.dart';

class Blake2b {
  static const int BLAKE2B_PERSONALBYTES = 16;
  static const int BLAKE2B_OUTBYTES = 32;
  static const int BLAKE2B_KEYBYTES = 32;

  static Uint8List hashWithPersonalization(
    Uint8List message,
    Uint8List personalization,
  ) {
    if (personalization.length != BLAKE2B_PERSONALBYTES) {
      throw ArgumentError('Personalization must be exactly $BLAKE2B_PERSONALBYTES bytes');
    }

    final digest = Blake2bDigest(
      digestSize: BLAKE2B_OUTBYTES,
      personalization: personalization,
    );

    digest.update(message, 0, message.length);
    final hash = Uint8List(BLAKE2B_OUTBYTES);
    digest.doFinal(hash, 0);

    return hash;
  }

  static Uint8List createPersonalization(String prefix, int consensusBranchId) {
    // Create personalization bytes: prefix || consensusBranchId
    final result = Uint8List(BLAKE2B_PERSONALBYTES);
    
    // Copy prefix bytes
    for (int i = 0; i < prefix.length && i < 12; i++) {
      result[i] = prefix.codeUnitAt(i);
    }

    // Add consensus branch ID in big-endian format
    result[12] = (consensusBranchId >> 24) & 0xFF;
    result[13] = (consensusBranchId >> 16) & 0xFF;
    result[14] = (consensusBranchId >> 8) & 0xFF;
    result[15] = consensusBranchId & 0xFF;

    return result;
  }
}
