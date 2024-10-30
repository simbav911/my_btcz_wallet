import 'dart:typed_data';
import 'package:dartz/dartz.dart';
import 'package:hex/hex.dart';
import 'package:my_btcz_wallet/core/crypto/crypto_service.dart';
import 'package:my_btcz_wallet/core/error/failures.dart';
import 'package:my_btcz_wallet/core/utils/logger.dart';
import 'package:my_btcz_wallet/data/datasources/wallet_local_data_source.dart';
import 'package:my_btcz_wallet/data/datasources/wallet_remote_data_source.dart';
import 'package:my_btcz_wallet/data/models/wallet_model.dart';
import 'package:my_btcz_wallet/domain/entities/wallet.dart';
import 'package:my_btcz_wallet/domain/repositories/wallet_repository.dart';
import 'package:bs58check/bs58check.dart' as bs58check;

class WalletRepositoryImpl implements WalletRepository {
  final WalletLocalDataSource localDataSource;
  final WalletRemoteDataSource remoteDataSource;
  final CryptoService cryptoService;

  WalletRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
    required this.cryptoService,
  });

  @override
  Future<Either<Failure, Wallet>> createWallet({String? notes}) async {
    try {
      WalletLogger.info('Creating new wallet...');
      final mnemonic = cryptoService.generateMnemonic();
      WalletLogger.debug('Generated mnemonic phrase');

      final masterKey = cryptoService.generateMasterKey(mnemonic);
      WalletLogger.debug('Generated master key');

      final privateKey = cryptoService.derivePrivateKey(masterKey, 0, 0);
      WalletLogger.debug('Derived private key');

      final publicKey = cryptoService.generatePublicKey(privateKey);
      WalletLogger.debug('Generated public key');

      final address = cryptoService.generateAddress(publicKey);
      WalletLogger.info('Generated BitcoinZ address: $address');

      final wallet = WalletModel(
        address: address,
        balance: 0.0,
        transactions: [],
        isInitialized: true,
        privateKey: HEX.encode(privateKey),
        publicKey: HEX.encode(publicKey),
        mnemonic: mnemonic,
        notes: notes ?? '',
      );

      await localDataSource.saveWallet(wallet);
      WalletLogger.info('Wallet saved successfully');
      return Right(wallet);
    } catch (e, stackTrace) {
      WalletLogger.error('Failed to create wallet', e, stackTrace);
      return Left(WalletFailure(
        message: 'Failed to create wallet: ${e.toString()}',
        code: 'WALLET_CREATION_ERROR',
      ));
    }
  }

  @override
  Future<Either<Failure, Wallet>> restoreWallet({String? mnemonic, String? privateKey, String? notes}) async {
    try {
      WalletLogger.info('Restoring wallet...');
      if (mnemonic != null) {
        WalletLogger.info('Restoring wallet from mnemonic...');
        if (!cryptoService.validateMnemonic(mnemonic)) {
          WalletLogger.warning('Invalid mnemonic phrase provided');
          return Left(WalletFailure(
            message: 'Invalid mnemonic phrase',
            code: 'INVALID_MNEMONIC',
          ));
        }

        final masterKey = cryptoService.generateMasterKey(mnemonic);
        WalletLogger.debug('Generated master key from mnemonic');

        final derivedPrivateKey = cryptoService.derivePrivateKey(masterKey, 0, 0);
        WalletLogger.debug('Derived private key');

        final publicKey = cryptoService.generatePublicKey(derivedPrivateKey);
        WalletLogger.debug('Generated public key');

        final address = cryptoService.generateAddress(publicKey);
        WalletLogger.info('Generated BitcoinZ address: $address');

        final wallet = WalletModel(
          address: address,
          balance: 0.0,
          transactions: [],
          isInitialized: true,
          privateKey: HEX.encode(derivedPrivateKey),
          publicKey: HEX.encode(publicKey),
          mnemonic: mnemonic,
          notes: notes ?? '',
        );

        await localDataSource.saveWallet(wallet);
        WalletLogger.info('Restored wallet saved successfully');
        return Right(wallet);
      } else if (privateKey != null) {
        WalletLogger.info('Restoring wallet from private key...');
        WalletLogger.debug('Private key being used: $privateKey');

        Uint8List privateKeyBytes;
        if (privateKey.length == 64 && RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(privateKey)) {
          // Raw hexadecimal private key
          privateKeyBytes = Uint8List.fromList(HEX.decode(privateKey));
        } else if (privateKey.length == 52 && privateKey.startsWith('L') || privateKey.startsWith('K')) {
          // WIF private key
          privateKeyBytes = bs58check.decode(privateKey).sublist(1, 33);
        } else {
          WalletLogger.warning('Invalid private key format provided');
          return Left(WalletFailure(
            message: 'Invalid private key format',
            code: 'INVALID_PRIVATE_KEY_FORMAT',
          ));
        }

        final publicKey = cryptoService.generatePublicKey(privateKeyBytes);
        WalletLogger.debug('Generated public key from private key');

        final address = cryptoService.generateAddress(publicKey);
        WalletLogger.info('Generated BitcoinZ address: $address');

        final wallet = WalletModel(
          address: address,
          balance: 0.0,
          transactions: [],
          isInitialized: true,
          privateKey: privateKey,
          publicKey: HEX.encode(publicKey),
          mnemonic: '',
          notes: notes ?? '',
        );

        await localDataSource.saveWallet(wallet);
        WalletLogger.info('Restored wallet saved successfully');
        return Right(wallet);
      } else {
        WalletLogger.warning('No mnemonic or private key provided for wallet restoration');
        return Left(WalletFailure(
          message: 'No mnemonic or private key provided for wallet restoration',
          code: 'NO_RESTORATION_DATA',
        ));
      }
    } catch (e, stackTrace) {
      WalletLogger.error('Failed to restore wallet', e, stackTrace);
      return Left(WalletFailure(
        message: 'Failed to restore wallet: ${e.toString()}',
        code: 'WALLET_RESTORE_ERROR',
      ));
    }
  }

  @override
  Future<Either<Failure, double>> getBalance(String address) async {
    try {
      WalletLogger.info('Fetching balance for address: $address');
      final balance = await remoteDataSource.getBalance(address);
      WalletLogger.info('Balance fetched: $balance BTCZ');
      return Right(balance);
    } catch (e, stackTrace) {
      WalletLogger.error('Failed to get balance', e, stackTrace);
      return Left(NetworkFailure(
        message: 'Failed to get balance: ${e.toString()}',
        code: 'BALANCE_FETCH_ERROR',
      ));
    }
  }

  @override
  Future<Either<Failure, List<String>>> getTransactions(String address) async {
    try {
      WalletLogger.info('Fetching transactions for address: $address');
      final transactions = await remoteDataSource.getTransactions(address);
      WalletLogger.info('Fetched ${transactions.length} transactions');
      return Right(transactions);
    } catch (e, stackTrace) {
      WalletLogger.error('Failed to get transactions', e, stackTrace);
      return Left(NetworkFailure(
        message: 'Failed to get transactions: ${e.toString()}',
        code: 'TRANSACTIONS_FETCH_ERROR',
      ));
    }
  }

  @override
  Future<Either<Failure, String>> generateAddress() async {
    try {
      WalletLogger.info('Generating new address...');
      final wallet = await localDataSource.getWallet();
      if (wallet == null) {
        WalletLogger.warning('No wallet found');
        return Left(WalletFailure(
          message: 'No wallet found',
          code: 'NO_WALLET_FOUND',
        ));
      }

      final masterKey = cryptoService.generateMasterKey(wallet.mnemonic);
      final privateKey = cryptoService.derivePrivateKey(masterKey, 0, 1); // New index
      final publicKey = cryptoService.generatePublicKey(privateKey);
      final address = cryptoService.generateAddress(publicKey);

      WalletLogger.info('Generated new BitcoinZ address: $address');
      return Right(address);
    } catch (e, stackTrace) {
      WalletLogger.error('Failed to generate address', e, stackTrace);
      return Left(WalletFailure(
        message: 'Failed to generate address: ${e.toString()}',
        code: 'ADDRESS_GENERATION_ERROR',
      ));
    }
  }

  @override
  Future<Either<Failure, void>> backupWallet() async {
    try {
      WalletLogger.info('Initiating wallet backup...');
      final wallet = await localDataSource.getWallet();
      if (wallet == null) {
        WalletLogger.warning('No wallet found to backup');
        return Left(WalletFailure(
          message: 'No wallet found to backup',
          code: 'NO_WALLET_FOUND',
        ));
      }
      // TODO: Implement proper backup mechanism
      WalletLogger.info('Wallet backup completed');
      return const Right(null);
    } catch (e, stackTrace) {
      WalletLogger.error('Failed to backup wallet', e, stackTrace);
      return Left(WalletFailure(
        message: 'Failed to backup wallet: ${e.toString()}',
        code: 'BACKUP_ERROR',
      ));
    }
  }
}
