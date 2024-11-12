import 'package:my_btcz_wallet/core/error/failures.dart';
import 'package:my_btcz_wallet/core/network/electrum_service.dart';
import 'package:my_btcz_wallet/core/utils/logger.dart';

abstract class WalletRemoteDataSource {
  Future<double> getBalance(String address);
  Future<List<String>> getTransactions(String address);
  Future<void> broadcastTransaction(String rawTransaction);
}

class WalletRemoteDataSourceImpl implements WalletRemoteDataSource {
  final ElectrumService electrumService;

  WalletRemoteDataSourceImpl({
    required this.electrumService,
  });

  @override
  Future<double> getBalance(String address) async {
    try {
      WalletLogger.debug('Getting balance for address: $address');
      final balance = await electrumService.getBalance(address);
      WalletLogger.debug('Balance received: $balance BTCZ');
      return balance;
    } catch (e, stackTrace) {
      WalletLogger.error('Failed to get balance', e, stackTrace);
      throw ServerFailure(
        message: 'Failed to get balance: ${e.toString()}',
        code: 'BALANCE_FETCH_ERROR',
      );
    }
  }

  @override
  Future<List<String>> getTransactions(String address) async {
    try {
      WalletLogger.debug('Getting transaction history for address: $address');
      final history = await electrumService.getHistory(address);
      final transactions = history.map((tx) => tx['tx_hash'] as String).toList();
      WalletLogger.debug('Retrieved ${transactions.length} transactions');
      return transactions;
    } catch (e, stackTrace) {
      WalletLogger.error('Failed to get transactions', e, stackTrace);
      throw ServerFailure(
        message: 'Failed to get transactions: ${e.toString()}',
        code: 'TRANSACTION_HISTORY_ERROR',
      );
    }
  }

  @override
  Future<void> broadcastTransaction(String rawTransaction) async {
    try {
      WalletLogger.debug('Broadcasting transaction');
      await electrumService.broadcastTransaction(rawTransaction);
      WalletLogger.debug('Transaction broadcast successful');
    } catch (e, stackTrace) {
      WalletLogger.error('Failed to broadcast transaction', e, stackTrace);
      throw ServerFailure(
        message: 'Failed to broadcast transaction: ${e.toString()}',
        code: 'BROADCAST_ERROR',
      );
    }
  }
}
