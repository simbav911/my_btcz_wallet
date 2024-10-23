import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:my_btcz_wallet/core/error/failures.dart';
import 'package:my_btcz_wallet/domain/repositories/wallet_repository.dart';

class GetBalance {
  final WalletRepository repository;

  GetBalance(this.repository);

  Future<Either<Failure, double>> call(GetBalanceParams params) async {
    return await repository.getBalance(params.address);
  }
}

class GetBalanceParams extends Equatable {
  final String address;

  const GetBalanceParams({required this.address});

  @override
  List<Object?> get props => [address];
}
