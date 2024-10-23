abstract class WalletEvent {}

class CreateWalletEvent extends WalletEvent {
  final String? notes;

  CreateWalletEvent({this.notes});
}

class RestoreWalletEvent extends WalletEvent {
  final String mnemonic;
  final String? notes;

  RestoreWalletEvent({
    required this.mnemonic,
    this.notes,
  });
}

class LoadWalletEvent extends WalletEvent {}

class GetBalanceEvent extends WalletEvent {
  final String address;

  GetBalanceEvent({required this.address});
}

class GetTransactionsEvent extends WalletEvent {
  final String address;

  GetTransactionsEvent({required this.address});
}

class GenerateMnemonicEvent extends WalletEvent {}

class VerifyMnemonicEvent extends WalletEvent {
  final String mnemonic;
  final String? notes;

  VerifyMnemonicEvent({
    required this.mnemonic,
    this.notes,
  });
}
