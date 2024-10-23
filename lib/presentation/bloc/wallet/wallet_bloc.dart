import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_btcz_wallet/domain/usecases/create_wallet.dart';
import 'package:my_btcz_wallet/domain/usecases/get_balance.dart';
import 'package:my_btcz_wallet/domain/usecases/get_transactions.dart';
import 'package:my_btcz_wallet/domain/usecases/restore_wallet.dart';
import 'package:my_btcz_wallet/presentation/bloc/wallet/wallet_event.dart';
import 'package:my_btcz_wallet/presentation/bloc/wallet/wallet_state.dart';

class WalletBloc extends Bloc<WalletEvent, WalletState> {
  final CreateWallet createWallet;
  final RestoreWallet restoreWallet;
  final GetBalance getBalance;
  final GetTransactions getTransactions;

  WalletBloc({
    required this.createWallet,
    required this.restoreWallet,
    required this.getBalance,
    required this.getTransactions,
  }) : super(WalletInitial()) {
    on<CreateWalletEvent>(_onCreateWallet);
    on<RestoreWalletEvent>(_onRestoreWallet);
    on<GetBalanceEvent>(_onGetBalance);
    on<GetTransactionsEvent>(_onGetTransactions);
  }

  Future<void> _onCreateWallet(
    CreateWalletEvent event,
    Emitter<WalletState> emit,
  ) async {
    emit(WalletLoading());
    final result = await createWallet();
    result.fold(
      (failure) => emit(WalletError(failure.message)),
      (wallet) => emit(WalletCreated(wallet)),
    );
  }

  Future<void> _onRestoreWallet(
    RestoreWalletEvent event,
    Emitter<WalletState> emit,
  ) async {
    emit(WalletLoading());
    final result = await restoreWallet(RestoreWalletParams(
      mnemonic: event.mnemonic,
    ));
    result.fold(
      (failure) => emit(WalletError(failure.message)),
      (wallet) => emit(WalletRestored(wallet)),
    );
  }

  Future<void> _onGetBalance(
    GetBalanceEvent event,
    Emitter<WalletState> emit,
  ) async {
    emit(WalletLoading());
    final result = await getBalance(GetBalanceParams(
      address: event.address,
    ));
    result.fold(
      (failure) => emit(WalletError(failure.message)),
      (balance) => emit(BalanceLoaded(balance)),
    );
  }

  Future<void> _onGetTransactions(
    GetTransactionsEvent event,
    Emitter<WalletState> emit,
  ) async {
    emit(WalletLoading());
    final result = await getTransactions(GetTransactionsParams(
      address: event.address,
    ));
    result.fold(
      (failure) => emit(WalletError(failure.message)),
      (transactions) => emit(TransactionsLoaded(transactions)),
    );
  }
}
