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
  final double? unconfirmedBalance;
  final List<Map<String, dynamic>>? pendingTransactions;

  const WalletLoaded(
    this.wallet, {
    this.unconfirmedBalance,
    this.pendingTransactions,
    ConnectionStatus connectionStatus = ConnectionStatus.disconnected,
  }) : super(connectionStatus: connectionStatus);

  WalletLoaded copyWith({
    WalletModel? wallet,
    double? unconfirmedBalance,
    List<Map<String, dynamic>>? pendingTransactions,
    ConnectionStatus? connectionStatus,
  }) {
    return WalletLoaded(
      wallet ?? this.wallet,
      unconfirmedBalance: unconfirmedBalance ?? this.unconfirmedBalance,
      pendingTransactions: pendingTransactions ?? this.pendingTransactions,
      connectionStatus: connectionStatus ?? this.connectionStatus,
    );
  }

  @override
  List<Object?> get props => [wallet, unconfirmedBalance, pendingTransactions, connectionStatus];
}

class BalanceLoaded extends WalletState {
  final double confirmedBalance;
  final double unconfirmedBalance;

  const BalanceLoaded({
    required this.confirmedBalance,
    required this.unconfirmedBalance,
  });

  double get totalBalance => confirmedBalance + unconfirmedBalance;

  @override
  List<Object?> get props => [confirmedBalance, unconfirmedBalance, connectionStatus];
}

class TransactionsLoaded extends WalletState {
  final List<Map<String, dynamic>> transactions;
  final List<Map<String, dynamic>> pendingTransactions;

  const TransactionsLoaded({
    required this.transactions,
    required this.pendingTransactions,
  });

  @override
  List<Object?> get props => [transactions, pendingTransactions, connectionStatus];
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
