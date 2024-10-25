import 'package:my_btcz_wallet/core/error/failures.dart';
import 'package:my_btcz_wallet/core/network/electrum_service.dart';
import 'package:my_btcz_wallet/core/utils/logger.dart';
import 'package:my_btcz_wallet/core/crypto/qr_code_service.dart';
import 'package:my_btcz_wallet/core/crypto/crypto_service.dart';
import 'package:my_btcz_wallet/core/crypto/transaction_builder.dart';
import 'package:my_btcz_wallet/core/crypto/transaction_serializer.dart';

class TransactionService {
  final ElectrumService electrumService;
  final QRCodeService qrCodeService;
  final CryptoService cryptoService;

  TransactionService({
    required this.electrumService,
    required this.cryptoService,
  }) : qrCodeService = QRCodeService();

  Future<String> generateReceiveQRCode(String address, {double? amount}) async {
    return qrCodeService.generateReceiveQRCode(address, amount: amount);
  }

  Future<Map<String, String>> decodeQRCode(String data) async {
    return qrCodeService.decodeQRCode(data);
  }

  Future<Map<String, dynamic>> createTransaction({
    required String fromAddress,
    required String toAddress,
    required double amount,
    required String privateKey,
    double? fee,
  }) async {
    try {
      WalletLogger.debug('Creating transaction preview');
      
      // Convert hex private key to WIF format
      WalletLogger.debug('Converting private key to WIF format');
      final privateKeyWIF = cryptoService.privateKeyToWIF(privateKey);
      WalletLogger.debug('Private key converted to WIF format');

      // Get unspent outputs
      WalletLogger.debug('Getting unspent outputs for address: $fromAddress');
      final unspentOutputs = await electrumService.getUnspentOutputs(fromAddress);
      WalletLogger.debug('Unspent outputs response: $unspentOutputs');

      // Create transaction data
      final txData = await TransactionBuilder.createAndSignTransaction(
        unspentOutputs,
        toAddress,
        amount,
        fromAddress,
        privateKeyWIF,
        fee ?? 0.0001,
      );

      // Serialize for preview
      final rawTx = TransactionSerializer.serializeToHex(txData);
      WalletLogger.debug('Created transaction hex: $rawTx');

      // Log transaction details
      WalletLogger.debug('Transaction details:');
      WalletLogger.debug('- Version: ${txData['version']}');
      WalletLogger.debug('- Version Group ID: 0x${txData['versionGroupId'].toRadixString(16)}');
      WalletLogger.debug('- Inputs count: ${txData['inputs'].length}');
      WalletLogger.debug('- Outputs count: ${txData['outputs'].length}');
      WalletLogger.debug('- Lock time: ${txData['locktime']}');
      WalletLogger.debug('- Expiry height: ${txData['expiryHeight']}');

      return {
        'rawTransaction': rawTx,
        'fee': (fee ?? 0.0001).toString(),
        'amount': amount.toString(),
        'fromAddress': fromAddress,
        'toAddress': toAddress,
        'transactionData': txData,
      };
    } catch (e, stackTrace) {
      WalletLogger.error('Failed to create transaction', e, stackTrace);
      throw CryptoFailure(
        message: 'Failed to create transaction: ${e.toString()}',
        code: 'TRANSACTION_CREATE_ERROR',
      );
    }
  }

  Future<String> broadcastTransaction(Map<String, dynamic> transactionDetails) async {
    try {
      WalletLogger.debug('Broadcasting confirmed transaction');
      
      final rawTx = transactionDetails['rawTransaction'] as String;
      WalletLogger.debug('Broadcasting transaction hex: $rawTx');
      
      // Use ElectrumService's implementation to broadcast
      final txId = await electrumService.broadcastTransaction(rawTx);
      WalletLogger.info('Transaction broadcasted successfully: $txId');

      return txId;
    } catch (e, stackTrace) {
      WalletLogger.error('Failed to broadcast transaction', e, stackTrace);
      throw CryptoFailure(
        message: 'Failed to broadcast transaction: ${e.toString()}',
        code: 'TRANSACTION_BROADCAST_ERROR',
      );
    }
  }

  Future<double> estimateFee(int targetBlocks) async {
    try {
      final estimate = await electrumService.getFeeEstimate(targetBlocks);
      return (estimate['feeRate'] as num).toDouble();
    } catch (e) {
      // Default to 0.0001 BTCZ if estimation fails
      return 0.0001;
    }
  }
}
