import 'package:equatable/equatable.dart';
import 'package:my_btcz_wallet/core/network/electrum_service.dart';

abstract class WalletEvent extends Equatable {
  const WalletEvent();

  @override
  List<Object?> get props => [];
}

class CreateWalletEvent extends WalletEvent {
  final String notes;

  const CreateWalletEvent({required this.notes});

  @override
  List<Object> get props => [notes];
}

class RestoreWalletEvent extends WalletEvent {
  final String mnemonic;
  final String notes;

  const RestoreWalletEvent({
    required this.mnemonic,
    required this.notes,
  });

  @override
  List<Object> get props => [mnemonic, notes];
}

class LoadWalletEvent extends WalletEvent {}

class GetBalanceEvent extends WalletEvent {
  final String address;

  const GetBalanceEvent({required this.address});

  @override
  List<Object> get props => [address];
}

class GetTransactionsEvent extends WalletEvent {
  final String address;

  const GetTransactionsEvent({required this.address});

  @override
  List<Object> get props => [address];
}

class StartAutoUpdateEvent extends WalletEvent {
  final String address;
  final Duration interval;

  const StartAutoUpdateEvent({
    required this.address,
    this.interval = const Duration(seconds: 15), // Updated to 15 seconds
  });

  @override
  List<Object> get props => [address, interval];
}

class StopAutoUpdateEvent extends WalletEvent {}

class RefreshWalletEvent extends WalletEvent {
  final String address;

  const RefreshWalletEvent({required this.address});

  @override
  List<Object> get props => [address];
}

class UpdatePendingTransactionEvent extends WalletEvent {
  final String txId;
  final Map<String, dynamic> transaction;

  const UpdatePendingTransactionEvent({
    required this.txId,
    required this.transaction,
  });

  @override
  List<Object> get props => [txId, transaction];
}

class GenerateMnemonicEvent extends WalletEvent {}

class VerifyMnemonicEvent extends WalletEvent {
  final String mnemonic;
  final String notes;

  const VerifyMnemonicEvent({
    required this.mnemonic,
    required this.notes,
  });

  @override
  List<Object> get props => [mnemonic, notes];
}

class UpdateConnectionStatus extends WalletEvent {
  final ConnectionStatus status;

  const UpdateConnectionStatus(this.status);

  @override
  List<Object> get props => [status];
}

class ConnectToServer extends WalletEvent {}
