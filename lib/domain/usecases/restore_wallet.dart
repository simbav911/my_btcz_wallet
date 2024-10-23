import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:my_btcz_wallet/core/error/failures.dart';
import 'package:my_btcz_wallet/domain/entities/wallet.dart';
import 'package:my_btcz_wallet/domain/repositories/wallet_repository.dart';

class RestoreWallet {
  final WalletRepository repository;

  RestoreWallet(this.repository);

  Future<Either<Failure, Wallet>> call(RestoreWalletParams params) async {
    return await repository.restoreWallet(params.mnemonic);
  }
}

class RestoreWalletParams extends Equatable {
  final String mnemonic;

  const RestoreWalletParams({required this.mnemonic});

  @override
  List<Object?> get props => [mnemonic];
}
