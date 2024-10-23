import 'package:dartz/dartz.dart';
import 'package:my_btcz_wallet/core/error/failures.dart';
import 'package:my_btcz_wallet/domain/entities/wallet.dart';
import 'package:my_btcz_wallet/domain/repositories/wallet_repository.dart';

class CreateWallet {
  final WalletRepository repository;

  CreateWallet(this.repository);

  Future<Either<Failure, Wallet>> call() async {
    return await repository.createWallet();
  }
}
