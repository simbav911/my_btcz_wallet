import 'package:dartz/dartz.dart';
import 'package:my_btcz_wallet/core/error/failures.dart';
import 'package:my_btcz_wallet/domain/entities/wallet.dart';
import 'package:my_btcz_wallet/domain/repositories/wallet_repository.dart';

class RestoreWalletParams {
  final String? mnemonic;
  final String? privateKey;
  final String? notes;

  RestoreWalletParams({
    this.mnemonic,
    this.privateKey,
    this.notes,
  });
}

class RestoreWallet {
  final WalletRepository repository;

  RestoreWallet(this.repository);

  Future<Either<Failure, Wallet>> call(RestoreWalletParams params) async {
    return await repository.restoreWallet(
      mnemonic: params.mnemonic,
      privateKey: params.privateKey,
      notes: params.notes,
    );
  }
}
