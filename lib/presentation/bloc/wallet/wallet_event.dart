import 'package:equatable/equatable.dart';

abstract class WalletEvent extends Equatable {
  const WalletEvent();

  @override
  List<Object?> get props => [];
}

class CreateWalletEvent extends WalletEvent {}

class RestoreWalletEvent extends WalletEvent {
  final String mnemonic;

  const RestoreWalletEvent({required this.mnemonic});

  @override
  List<Object?> get props => [mnemonic];
}

class GetBalanceEvent extends WalletEvent {
  final String address;

  const GetBalanceEvent({required this.address});

  @override
  List<Object?> get props => [address];
}

class GetTransactionsEvent extends WalletEvent {
  final String address;

  const GetTransactionsEvent({required this.address});

  @override
  List<Object?> get props => [address];
}

class BackupWalletEvent extends WalletEvent {}
