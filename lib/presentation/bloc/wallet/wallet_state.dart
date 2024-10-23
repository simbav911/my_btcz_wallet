import 'package:my_btcz_wallet/domain/entities/wallet.dart';

abstract class WalletState {}

class WalletInitial extends WalletState {}

class WalletLoading extends WalletState {}

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

  MnemonicVerified({
    required this.mnemonic,
    this.notes,
  });
}

class WalletCreated extends WalletState {
  final Wallet wallet;

  WalletCreated(this.wallet);
}

class WalletRestored extends WalletState {
  final Wallet wallet;

  WalletRestored(this.wallet);
}

class WalletLoaded extends WalletState {
  final Wallet wallet;

  WalletLoaded(this.wallet);
}

class BalanceLoaded extends WalletState {
  final double balance;

  BalanceLoaded(this.balance);
}

class TransactionsLoaded extends WalletState {
  final List<String> transactions;

  TransactionsLoaded(this.transactions);
}
