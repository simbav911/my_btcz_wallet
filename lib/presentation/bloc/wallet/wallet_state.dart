import 'package:equatable/equatable.dart';
import 'package:my_btcz_wallet/domain/entities/wallet.dart';

abstract class WalletState extends Equatable {
  const WalletState();

  @override
  List<Object?> get props => [];
}

class WalletInitial extends WalletState {}

class WalletLoading extends WalletState {}

class WalletCreated extends WalletState {
  final Wallet wallet;

  const WalletCreated(this.wallet);

  @override
  List<Object?> get props => [wallet];
}

class WalletRestored extends WalletState {
  final Wallet wallet;

  const WalletRestored(this.wallet);

  @override
  List<Object?> get props => [wallet];
}

class WalletError extends WalletState {
  final String message;

  const WalletError(this.message);

  @override
  List<Object?> get props => [message];
}

class BalanceLoaded extends WalletState {
  final double balance;

  const BalanceLoaded(this.balance);

  @override
  List<Object?> get props => [balance];
}

class TransactionsLoaded extends WalletState {
  final List<String> transactions;

  const TransactionsLoaded(this.transactions);

  @override
  List<Object?> get props => [transactions];
}

class WalletBackedUp extends WalletState {}
