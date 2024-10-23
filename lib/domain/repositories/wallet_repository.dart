import 'package:dartz/dartz.dart';
import 'package:my_btcz_wallet/core/error/failures.dart';
import 'package:my_btcz_wallet/domain/entities/wallet.dart';

abstract class WalletRepository {
  Future<Either<Failure, Wallet>> createWallet({String? notes});
  Future<Either<Failure, Wallet>> restoreWallet(String mnemonic, {String? notes});
  Future<Either<Failure, double>> getBalance(String address);
  Future<Either<Failure, List<String>>> getTransactions(String address);
  Future<Either<Failure, String>> generateAddress();
  Future<Either<Failure, void>> backupWallet();
}
