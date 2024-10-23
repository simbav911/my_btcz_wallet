import 'package:dartz/dartz.dart';
import 'package:my_btcz_wallet/core/error/failures.dart';
import 'package:my_btcz_wallet/domain/entities/wallet.dart';
import 'package:my_btcz_wallet/domain/repositories/wallet_repository.dart';

class RestoreWalletParams {
  final String mnemonic;
  final String? notes;

  RestoreWalletParams({
    required this.mnemonic,
    this.notes,
  });
}

class RestoreWallet {
  final WalletRepository repository;

  RestoreWallet(this.repository);

  Future<Either<Failure, Wallet>> call(RestoreWalletParams params) async {
    return await repository.restoreWallet(params.mnemonic, notes: params.notes);
  }
}
