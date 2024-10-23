import 'package:dartz/dartz.dart';
import 'package:my_btcz_wallet/core/error/failures.dart';
import 'package:my_btcz_wallet/domain/entities/wallet.dart';
import 'package:my_btcz_wallet/domain/repositories/wallet_repository.dart';

class CreateWalletParams {
  final String? notes;

  CreateWalletParams({this.notes});
}

class CreateWallet {
  final WalletRepository repository;

  CreateWallet(this.repository);

  Future<Either<Failure, Wallet>> call([CreateWalletParams? params]) async {
    return await repository.createWallet(notes: params?.notes);
  }
}
