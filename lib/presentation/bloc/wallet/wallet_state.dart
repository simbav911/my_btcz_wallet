import 'package:equatable/equatable.dart';
import 'package:my_btcz_wallet/core/network/electrum_service.dart';
import 'package:my_btcz_wallet/data/models/wallet_model.dart';

abstract class WalletState extends Equatable {
  final ConnectionStatus connectionStatus;

  const WalletState({
    this.connectionStatus = ConnectionStatus.disconnected,
  });

  @override
  List<Object?> get props => [connectionStatus];
}

class WalletInitial extends WalletState {}

class WalletLoading extends WalletState {}

class WalletCreated extends WalletState {
  final WalletModel wallet;

  const WalletCreated(this.wallet);

  @override
  List<Object?> get props => [wallet, connectionStatus];
}

class WalletRestored extends WalletState {
  final WalletModel wallet;

  const WalletRestored(this.wallet);

  @override
  List<Object?> get props => [wallet, connectionStatus];
}

class WalletLoaded extends WalletState {
  final WalletModel wallet;

  const WalletLoaded(
    this.wallet, {
    ConnectionStatus connectionStatus = ConnectionStatus.disconnected,
  }) : super(connectionStatus: connectionStatus);

  WalletLoaded copyWith({
    WalletModel? wallet,
    ConnectionStatus? connectionStatus,
  }) {
    return WalletLoaded(
      wallet ?? this.wallet,
      connectionStatus: connectionStatus ?? this.connectionStatus,
    );
  }

  @override
  List<Object?> get props => [wallet, connectionStatus];
}

class BalanceLoaded extends WalletState {
  final double balance;

  const BalanceLoaded(this.balance);

  @override
  List<Object?> get props => [balance, connectionStatus];
}

class TransactionsLoaded extends WalletState {
  final List<String> transactions;

  const TransactionsLoaded(this.transactions);

  @override
  List<Object?> get props => [transactions, connectionStatus];
}

class MnemonicGenerated extends WalletState {
  final String mnemonic;

  const MnemonicGenerated(this.mnemonic);

  @override
  List<Object?> get props => [mnemonic, connectionStatus];
}

class MnemonicVerified extends WalletState {
  final String mnemonic;
  final String notes;

  const MnemonicVerified({
    required this.mnemonic,
    required this.notes,
  });

  @override
  List<Object?> get props => [mnemonic, notes, connectionStatus];
}

class WalletError extends WalletState {
  final String message;

  const WalletError(this.message);

  @override
  List<Object?> get props => [message, connectionStatus];
}
