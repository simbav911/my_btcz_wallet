import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_btcz_wallet/core/crypto/crypto_service.dart';
import 'package:my_btcz_wallet/core/network/electrum_service.dart';
import 'package:my_btcz_wallet/data/datasources/wallet_local_data_source.dart';
import 'package:my_btcz_wallet/data/models/wallet_model.dart';
import 'package:my_btcz_wallet/domain/entities/wallet.dart';
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
  final CryptoService cryptoService;
  final WalletLocalDataSource localDataSource;
  final ElectrumService electrumService;
  String? _pendingMnemonic;
  String? _pendingNotes;
  StreamSubscription? _connectionSubscription;

  WalletBloc({
    required this.createWallet,
    required this.restoreWallet,
    required this.getBalance,
    required this.getTransactions,
    required this.cryptoService,
    required this.localDataSource,
    required this.electrumService,
  }) : super(WalletInitial()) {
    on<CreateWalletEvent>(_onCreateWallet);
    on<RestoreWalletEvent>(_onRestoreWallet);
    on<LoadWalletEvent>(_onLoadWallet);
    on<GetBalanceEvent>(_onGetBalance);
    on<GetTransactionsEvent>(_onGetTransactions);
    on<GenerateMnemonicEvent>(_onGenerateMnemonic);
    on<VerifyMnemonicEvent>(_onVerifyMnemonic);
    on<UpdateConnectionStatus>(_onUpdateConnectionStatus);
    on<ConnectToServer>(_onConnectToServer);

    // Listen to connection status changes
    _connectionSubscription = electrumService.statusStream.listen((status) {
      add(UpdateConnectionStatus(status));
    });
  }

  WalletModel _convertToModel(Wallet wallet) {
    return WalletModel(
      address: wallet.address,
      balance: wallet.balance,
      transactions: wallet.transactions,
      isInitialized: wallet.isInitialized,
      privateKey: wallet.privateKey,
      publicKey: wallet.publicKey,
      mnemonic: wallet.mnemonic,
      notes: wallet.notes,
    );
  }

  Future<void> _onCreateWallet(
    CreateWalletEvent event,
    Emitter<WalletState> emit,
  ) async {
    if (_pendingMnemonic == null) {
      emit(WalletError('No mnemonic generated'));
      return;
    }

    emit(WalletLoading());
    final result = await createWallet(CreateWalletParams(notes: event.notes));
    result.fold(
      (failure) => emit(WalletError(failure.message)),
      (wallet) {
        _pendingMnemonic = null;
        _pendingNotes = null;
        final walletModel = _convertToModel(wallet);
        emit(WalletCreated(walletModel));
        electrumService.connect(); // Connect after wallet creation
      },
    );
  }

  Future<void> _onRestoreWallet(
    RestoreWalletEvent event,
    Emitter<WalletState> emit,
  ) async {
    emit(WalletLoading());
    final result = await restoreWallet(RestoreWalletParams(
      mnemonic: event.mnemonic,
      notes: event.notes,
    ));
    result.fold(
      (failure) => emit(WalletError(failure.message)),
      (wallet) {
        final walletModel = _convertToModel(wallet);
        emit(WalletRestored(walletModel));
        electrumService.connect(); // Connect after wallet restoration
      },
    );
  }

  Future<void> _onLoadWallet(
    LoadWalletEvent event,
    Emitter<WalletState> emit,
  ) async {
    emit(WalletLoading());
    try {
      final wallet = await localDataSource.getWallet();
      if (wallet != null) {
        emit(WalletLoaded(wallet));
        electrumService.connect(); // Connect after wallet load
      } else {
        emit(WalletInitial());
      }
    } catch (e) {
      emit(WalletError(e.toString()));
    }
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

  void _onGenerateMnemonic(
    GenerateMnemonicEvent event,
    Emitter<WalletState> emit,
  ) {
    try {
      final mnemonic = cryptoService.generateMnemonic();
      _pendingMnemonic = mnemonic;
      emit(MnemonicGenerated(mnemonic));
    } catch (e) {
      emit(WalletError('Failed to generate mnemonic: $e'));
    }
  }

  void _onVerifyMnemonic(
    VerifyMnemonicEvent event,
    Emitter<WalletState> emit,
  ) {
    try {
      if (cryptoService.validateMnemonic(event.mnemonic)) {
        _pendingMnemonic = event.mnemonic;
        _pendingNotes = event.notes;
        emit(MnemonicVerified(
          mnemonic: event.mnemonic,
          notes: event.notes,
        ));
      } else {
        emit(WalletError('Invalid mnemonic phrase'));
      }
    } catch (e) {
      emit(WalletError('Failed to verify mnemonic: $e'));
    }
  }

  void _onUpdateConnectionStatus(
    UpdateConnectionStatus event,
    Emitter<WalletState> emit,
  ) {
    final currentState = state;
    if (currentState is WalletLoaded) {
      emit(currentState.copyWith(connectionStatus: event.status));
    }
  }

  void _onConnectToServer(
    ConnectToServer event,
    Emitter<WalletState> emit,
  ) {
    electrumService.connect();
  }

  @override
  Future<void> close() {
    _connectionSubscription?.cancel();
    return super.close();
  }
}
