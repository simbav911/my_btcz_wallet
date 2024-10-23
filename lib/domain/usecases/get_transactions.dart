import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:my_btcz_wallet/core/error/failures.dart';
import 'package:my_btcz_wallet/domain/repositories/wallet_repository.dart';

class GetTransactions {
  final WalletRepository repository;

  GetTransactions(this.repository);

  Future<Either<Failure, List<String>>> call(GetTransactionsParams params) async {
    return await repository.getTransactions(params.address);
  }
}

class GetTransactionsParams extends Equatable {
  final String address;

  const GetTransactionsParams({required this.address});

  @override
  List<Object?> get props => [address];
}
