import 'package:my_btcz_wallet/core/error/failures.dart';

class QRCodeService {
  Future<String> generateReceiveQRCode(String address, {double? amount}) async {
    try {
      // Format: btcz:<address>?amount=<amount>
      final uri = StringBuffer('btcz:$address');
      if (amount != null) {
        uri.write('?amount=$amount');
      }
      return uri.toString();
    } catch (e) {
      throw CryptoFailure(
        message: 'Failed to generate QR code: ${e.toString()}',
        code: 'QR_GENERATION_ERROR',
      );
    }
  }

  Future<Map<String, String>> decodeQRCode(String data) async {
    try {
      // Expected format: btcz:<address> or btcz:<address>?amount=<amount>
      if (!data.startsWith('btcz:')) {
        throw const CryptoFailure(
          message: 'Invalid QR code format',
          code: 'INVALID_QR_FORMAT',
        );
      }

      final parts = data.substring(5).split('?');
      final address = parts[0];

      // Ensure address is not empty and valid
      if (address.isEmpty || !address.startsWith('t1')) {
        throw const CryptoFailure(
          message: 'Invalid BitcoinZ address in QR code',
          code: 'INVALID_ADDRESS',
        );
      }

      final result = <String, String>{
        'address': address,
      };

      if (parts.length > 1) {
        final params = Uri.splitQueryString(parts[1]);
        if (params.containsKey('amount')) {
          final amountStr = params['amount'];
          if (amountStr != null) {
            final amount = double.tryParse(amountStr);
            if (amount != null && amount > 0) {
              result['amount'] = amount.toString();
            }
          }
        }
      }

      return result;
    } catch (e) {
      throw CryptoFailure(
        message: 'Failed to decode QR code: ${e.toString()}',
        code: 'QR_DECODE_ERROR',
      );
    }
  }
}
