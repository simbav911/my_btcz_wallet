import 'dart:async';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_btcz_wallet/core/crypto/crypto_service.dart';
import 'package:my_btcz_wallet/core/network/electrum_service.dart';
import 'package:my_btcz_wallet/core/utils/logger.dart';
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
  Timer? _autoUpdateTimer;
  StreamSubscription? _connectionSubscription;
  final Map<String, Map<String, dynamic>> _pendingTransactions = {};

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
    on<StartAutoUpdateEvent>(_onStartAutoUpdate);
    on<StopAutoUpdateEvent>(_onStopAutoUpdate);
    on<RefreshWalletEvent>(_onRefreshWallet);
    on<UpdatePendingTransactionEvent>(_onUpdatePendingTransaction);

    _connectionSubscription = electrumService.statusStream.listen((status) {
      add(UpdateConnectionStatus(status));
      if (status == ConnectionStatus.connected) {
        final currentState = state;
        if (currentState is WalletLoaded) {
          add(RefreshWalletEvent(address: currentState.wallet.address));
        }
      }
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

  Future<void> _onCreateWallet(CreateWalletEvent event, Emitter<WalletState> emit) async {
    if (_pendingMnemonic == null) {
      emit(WalletError('No mnemonic generated'));
      return;
    }

    emit(WalletLoading());
    final result = await createWallet(CreateWalletParams(notes: event.notes));
    result.fold(
      (failure) => emit(WalletError(failure.message)),
      (wallet) async {
        _pendingMnemonic = null;
        _pendingNotes = null;
        final walletModel = _convertToModel(wallet);
        await localDataSource.saveWallet(walletModel);
        emit(WalletCreated(walletModel));
        electrumService.connect();
        add(StartAutoUpdateEvent(address: wallet.address));
      },
    );
  }

  Future<void> _onRestoreWallet(RestoreWalletEvent event, Emitter<WalletState> emit) async {
    emit(WalletLoading());
    final result = await restoreWallet(RestoreWalletParams(
      mnemonic: event.mnemonic,
      notes: event.notes,
    ));
    result.fold(
      (failure) => emit(WalletError(failure.message)),
      (wallet) async {
        final walletModel = _convertToModel(wallet);
        await localDataSource.saveWallet(walletModel);
        emit(WalletRestored(walletModel));
        electrumService.connect();
        add(StartAutoUpdateEvent(address: wallet.address));
      },
    );
  }

  Future<void> _onLoadWallet(LoadWalletEvent event, Emitter<WalletState> emit) async {
    emit(WalletLoading());
    try {
      final wallet = await localDataSource.getWallet();
      if (wallet != null) {
        emit(WalletLoaded(wallet));
        electrumService.connect();
        add(StartAutoUpdateEvent(address: wallet.address));
      } else {
        emit(WalletInitial());
      }
    } catch (e) {
      emit(WalletError(e.toString()));
    }
  }

  Future<void> _onGetBalance(GetBalanceEvent event, Emitter<WalletState> emit) async {
    try {
      if (electrumService.status != ConnectionStatus.connected) {
        throw const SocketException('Not connected to Electrum server');
      }

      WalletLogger.debug('Requesting balance for address: ${event.address}');
      final balance = await electrumService.getBalance(event.address);
      WalletLogger.debug('Received balance: $balance');
      
      if (state is WalletLoaded) {
        final currentState = state as WalletLoaded;
        final updatedWallet = currentState.wallet.copyWith(
          balance: balance,
        );
        
        // Save updated wallet to local storage
        await localDataSource.saveWallet(updatedWallet);
        
        // Emit updated wallet state
        emit(WalletLoaded(updatedWallet));
      }

    } catch (e, stackTrace) {
      WalletLogger.error('Failed to get balance', e, stackTrace);
      // Don't emit error state to avoid UI disruption
      // Just log the error and retry on next update
    }
  }

  Future<void> _onGetTransactions(GetTransactionsEvent event, Emitter<WalletState> emit) async {
    try {
      if (electrumService.status != ConnectionStatus.connected) {
        throw const SocketException('Not connected to Electrum server');
      }

      WalletLogger.debug('Requesting transaction history for address: ${event.address}');
      final history = await electrumService.getHistory(event.address);
      WalletLogger.debug('Received transaction history: $history');
      
      if (state is WalletLoaded) {
        final currentState = state as WalletLoaded;
        
        // Extract transaction IDs
        final txIds = history.map((tx) => tx['tx_hash'] as String).toList();
        
        // Update wallet with new transactions
        final updatedWallet = currentState.wallet.copyWith(
          transactions: txIds,
        );
        
        // Save updated wallet to local storage
        await localDataSource.saveWallet(updatedWallet);
        
        // Update pending transactions
        _pendingTransactions.clear();
        for (var tx in history) {
          if (tx['height'] == 0 || tx['height'] == null) { // Unconfirmed transaction
            _pendingTransactions[tx['tx_hash']] = tx;
          }
        }

        // Emit transaction state
        emit(TransactionsLoaded(
          transactions: history.where((tx) => tx['height'] != 0 && tx['height'] != null).toList(),
          pendingTransactions: _pendingTransactions.values.toList(),
        ));
        
        // Emit updated wallet state
        emit(WalletLoaded(updatedWallet));
      }
    } catch (e, stackTrace) {
      WalletLogger.error('Failed to get transactions', e, stackTrace);
      // Don't emit error state to avoid UI disruption
      // Just log the error and retry on next update
    }
  }

  Future<void> _onRefreshWallet(RefreshWalletEvent event, Emitter<WalletState> emit) async {
    try {
      WalletLogger.debug('Starting wallet refresh for address: ${event.address}');
      
      // First get balance
      await _onGetBalance(GetBalanceEvent(address: event.address), emit);
      
      // Then get transactions
      await _onGetTransactions(GetTransactionsEvent(address: event.address), emit);
      
      WalletLogger.debug('Wallet refresh completed');
    } catch (e, stackTrace) {
      WalletLogger.error('Failed to refresh wallet', e, stackTrace);
    }
  }

  void _onStartAutoUpdate(StartAutoUpdateEvent event, Emitter<WalletState> emit) {
    _autoUpdateTimer?.cancel();
    _autoUpdateTimer = Timer.periodic(event.interval, (_) {
      if (state is WalletLoaded) {
        add(RefreshWalletEvent(address: event.address));
      }
    });
    // Trigger immediate refresh
    add(RefreshWalletEvent(address: event.address));
  }

  void _onStopAutoUpdate(StopAutoUpdateEvent event, Emitter<WalletState> emit) {
    _autoUpdateTimer?.cancel();
    _autoUpdateTimer = null;
  }

  void _onUpdatePendingTransaction(UpdatePendingTransactionEvent event, Emitter<WalletState> emit) {
    _pendingTransactions[event.txId] = event.transaction;
    if (state is WalletLoaded) {
      final currentState = state as WalletLoaded;
      emit(currentState.copyWith(
        pendingTransactions: _pendingTransactions.values.toList(),
      ));
    }
  }

  void _onGenerateMnemonic(GenerateMnemonicEvent event, Emitter<WalletState> emit) {
    try {
      final mnemonic = cryptoService.generateMnemonic();
      _pendingMnemonic = mnemonic;
      emit(MnemonicGenerated(mnemonic));
    } catch (e) {
      emit(WalletError('Failed to generate mnemonic: $e'));
    }
  }

  void _onVerifyMnemonic(VerifyMnemonicEvent event, Emitter<WalletState> emit) {
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

  void _onUpdateConnectionStatus(UpdateConnectionStatus event, Emitter<WalletState> emit) {
    final currentState = state;
    if (currentState is WalletLoaded) {
      emit(currentState.copyWith(connectionStatus: event.status));
    }
  }

  void _onConnectToServer(ConnectToServer event, Emitter<WalletState> emit) {
    electrumService.connect();
  }

  @override
  Future<void> close() {
    _autoUpdateTimer?.cancel();
    _connectionSubscription?.cancel();
    return super.close();
  }
}
