import 'package:my_btcz_wallet/core/network/connection_status.dart';

abstract class WalletEvent {
  const WalletEvent();
}

class CreateWalletEvent extends WalletEvent {
  final String? notes;
  const CreateWalletEvent({this.notes});
}

class RestoreWalletEvent extends WalletEvent {
  final String mnemonic;
  final String? notes;
  const RestoreWalletEvent({required this.mnemonic, this.notes});
}

class LoadWalletEvent extends WalletEvent {
  const LoadWalletEvent();
}

class GetBalanceEvent extends WalletEvent {
  final String address;
  const GetBalanceEvent({required this.address});
}

class GetTransactionsEvent extends WalletEvent {
  final String address;
  const GetTransactionsEvent({required this.address});
}

class GenerateMnemonicEvent extends WalletEvent {
  const GenerateMnemonicEvent();
}

class VerifyMnemonicEvent extends WalletEvent {
  final String mnemonic;
  final String? notes;
  const VerifyMnemonicEvent({required this.mnemonic, this.notes});
}

class UpdateConnectionStatus extends WalletEvent {
  final ConnectionStatus status;
  const UpdateConnectionStatus(this.status);
}

class ConnectToServer extends WalletEvent {
  const ConnectToServer();
}

class StartAutoUpdateEvent extends WalletEvent {
  final String address;
  final Duration interval;
  const StartAutoUpdateEvent({
    required this.address,
    this.interval = const Duration(minutes: 2),
  });
}

class StopAutoUpdateEvent extends WalletEvent {
  const StopAutoUpdateEvent();
}

class RefreshWalletEvent extends WalletEvent {
  final String address;
  const RefreshWalletEvent({required this.address});
}

class UpdatePendingTransactionEvent extends WalletEvent {
  final String txId;
  final Map<String, dynamic> transaction;
  const UpdatePendingTransactionEvent({
    required this.txId,
    required this.transaction,
  });
}

// New events for transaction confirmation flow
class PrepareTransactionEvent extends WalletEvent {
  final String fromAddress;
  final String toAddress;
  final double amount;
  final String privateKey;
  final double? fee;

  const PrepareTransactionEvent({
    required this.fromAddress,
    required this.toAddress,
    required this.amount,
    required this.privateKey,
    this.fee,
  });
}

class ConfirmTransactionEvent extends WalletEvent {
  final Map<String, dynamic> transactionDetails;
  const ConfirmTransactionEvent(this.transactionDetails);
}

class CancelTransactionEvent extends WalletEvent {
  const CancelTransactionEvent();
}
