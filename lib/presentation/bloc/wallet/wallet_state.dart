import 'package:my_btcz_wallet/core/network/connection_status.dart';
import 'package:my_btcz_wallet/data/models/wallet_model.dart';

abstract class WalletState {}

class WalletInitial extends WalletState {}

class WalletLoading extends WalletState {}

class WalletCreated extends WalletState {
  final WalletModel wallet;
  WalletCreated(this.wallet);
}

class WalletRestored extends WalletState {
  final WalletModel wallet;
  WalletRestored(this.wallet);
}

class WalletLoaded extends WalletState {
  final WalletModel wallet;
  final ConnectionStatus connectionStatus;
  final List<Map<String, dynamic>> pendingTransactions;

  WalletLoaded(
    this.wallet, {
    this.connectionStatus = ConnectionStatus.disconnected,
    this.pendingTransactions = const [],
  });

  WalletLoaded copyWith({
    WalletModel? wallet,
    ConnectionStatus? connectionStatus,
    List<Map<String, dynamic>>? pendingTransactions,
  }) {
    return WalletLoaded(
      wallet ?? this.wallet,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      pendingTransactions: pendingTransactions ?? this.pendingTransactions,
    );
  }
}

class WalletError extends WalletState {
  final String message;
  WalletError(this.message);
}

class MnemonicGenerated extends WalletState {
  final String mnemonic;
  MnemonicGenerated(this.mnemonic);
}

class MnemonicVerified extends WalletState {
  final String mnemonic;
  final String? notes;
  MnemonicVerified({required this.mnemonic, this.notes});
}

class TransactionsLoaded extends WalletState {
  final List<Map<String, dynamic>> transactions;
  final List<Map<String, dynamic>> pendingTransactions;
  TransactionsLoaded({
    required this.transactions,
    required this.pendingTransactions,
  });
}

// New states for transaction confirmation flow
class TransactionPrepared extends WalletState {
  final Map<String, dynamic> transactionDetails;
  final double amount;
  final double fee;
  final String toAddress;

  TransactionPrepared({
    required this.transactionDetails,
    required this.amount,
    required this.fee,
    required this.toAddress,
  });
}

class TransactionConfirmed extends WalletState {
  final String transactionId;
  TransactionConfirmed(this.transactionId);
}

class TransactionCancelled extends WalletState {}
