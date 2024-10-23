import 'package:dio/dio.dart';
import 'package:my_btcz_wallet/core/error/failures.dart';
import 'package:my_btcz_wallet/core/constants/app_constants.dart';

abstract class WalletRemoteDataSource {
  Future<double> getBalance(String address);
  Future<List<String>> getTransactions(String address);
  Future<void> broadcastTransaction(String rawTransaction);
}

class WalletRemoteDataSourceImpl implements WalletRemoteDataSource {
  final Dio dio;
  final List<String> servers;
  int currentServerIndex = 0;

  WalletRemoteDataSourceImpl({
    required this.dio,
  }) : servers = AppConstants.electrumServers;

  String get currentServer => servers[currentServerIndex];

  void _rotateServer() {
    currentServerIndex = (currentServerIndex + 1) % servers.length;
  }

  Future<T> _executeWithRetry<T>(Future<T> Function() operation) async {
    for (var i = 0; i < servers.length; i++) {
      try {
        return await operation();
      } on DioException catch (e) {
        if (i == servers.length - 1) {
          throw ServerFailure(
            message: 'All servers failed: ${e.message}',
            code: 'ALL_SERVERS_FAILED',
          );
        }
        _rotateServer();
      }
    }
    throw ServerFailure(
      message: 'Unexpected error occurred',
      code: 'UNEXPECTED_ERROR',
    );
  }

  @override
  Future<double> getBalance(String address) async {
    return _executeWithRetry(() async {
      final response = await dio.post(
        'https://$currentServer',
        data: {
          'method': 'blockchain.address.get_balance',
          'params': [address],
          'id': 1,
        },
      );

      if (response.data['error'] != null) {
        throw ServerFailure(
          message: 'Server returned error: ${response.data['error']}',
          code: 'SERVER_ERROR',
        );
      }

      final balance = response.data['result']['confirmed'] as int;
      return balance / 100000000; // Convert satoshis to BTCZ
    });
  }

  @override
  Future<List<String>> getTransactions(String address) async {
    return _executeWithRetry(() async {
      final response = await dio.post(
        'https://$currentServer',
        data: {
          'method': 'blockchain.address.get_history',
          'params': [address],
          'id': 1,
        },
      );

      if (response.data['error'] != null) {
        throw ServerFailure(
          message: 'Server returned error: ${response.data['error']}',
          code: 'SERVER_ERROR',
        );
      }

      final transactions = (response.data['result'] as List)
          .map((tx) => tx['tx_hash'] as String)
          .toList();

      return transactions;
    });
  }

  @override
  Future<void> broadcastTransaction(String rawTransaction) async {
    return _executeWithRetry(() async {
      final response = await dio.post(
        'https://$currentServer',
        data: {
          'method': 'blockchain.transaction.broadcast',
          'params': [rawTransaction],
          'id': 1,
        },
      );

      if (response.data['error'] != null) {
        throw ServerFailure(
          message: 'Failed to broadcast transaction: ${response.data['error']}',
          code: 'BROADCAST_ERROR',
        );
      }
    });
  }
}
