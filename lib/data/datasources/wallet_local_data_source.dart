import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:my_btcz_wallet/core/error/failures.dart';
import 'package:my_btcz_wallet/core/utils/logger.dart';
import 'package:my_btcz_wallet/data/models/wallet_model.dart';

abstract class WalletLocalDataSource {
  Future<WalletModel?> getWallet();
  Future<void> saveWallet(WalletModel wallet);
  Future<void> deleteWallet();
  Future<bool> hasWallet();
}

class WalletLocalDataSourceImpl implements WalletLocalDataSource {
  final FlutterSecureStorage secureStorage;

  WalletLocalDataSourceImpl({required this.secureStorage});

  static const String _walletKey = 'wallet_data';

  // Configure storage for each platform
  static const _storageConfig = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock,
  );

  @override
  Future<WalletModel?> getWallet() async {
    try {
      WalletLogger.debug('Retrieving wallet from secure storage');
      final walletString = await secureStorage.read(
        key: _walletKey,
        iOptions: _storageConfig,
        mOptions: const MacOsOptions(
          accessibility: KeychainAccessibility.first_unlock,
        ),
      );

      if (walletString == null) {
        WalletLogger.info('No wallet found in secure storage');
        return null;
      }
      
      final walletJson = json.decode(walletString) as Map<String, dynamic>;
      WalletLogger.debug('Successfully retrieved wallet from secure storage');
      return WalletModel.fromJson(walletJson);
    } catch (e, stackTrace) {
      WalletLogger.error(
        'Failed to get wallet from secure storage',
        e,
        stackTrace,
      );
      throw CacheFailure(
        message: 'Failed to get wallet from secure storage',
        code: 'SECURE_STORAGE_READ_ERROR',
      );
    }
  }

  @override
  Future<void> saveWallet(WalletModel wallet) async {
    try {
      WalletLogger.debug('Saving wallet to secure storage');
      final walletJson = wallet.toJson();
      final walletString = json.encode(walletJson);
      
      await secureStorage.write(
        key: _walletKey,
        value: walletString,
        iOptions: _storageConfig,
        mOptions: const MacOsOptions(
          accessibility: KeychainAccessibility.first_unlock,
        ),
      );
      
      WalletLogger.info('Wallet saved successfully to secure storage');
    } catch (e, stackTrace) {
      WalletLogger.error(
        'Failed to save wallet to secure storage',
        e,
        stackTrace,
      );
      throw CacheFailure(
        message: 'Failed to save wallet to secure storage',
        code: 'SECURE_STORAGE_WRITE_ERROR',
      );
    }
  }

  @override
  Future<void> deleteWallet() async {
    try {
      WalletLogger.debug('Deleting wallet from secure storage');
      await secureStorage.delete(
        key: _walletKey,
        iOptions: _storageConfig,
        mOptions: const MacOsOptions(
          accessibility: KeychainAccessibility.first_unlock,
        ),
      );
      WalletLogger.info('Wallet deleted successfully from secure storage');
    } catch (e, stackTrace) {
      WalletLogger.error(
        'Failed to delete wallet from secure storage',
        e,
        stackTrace,
      );
      throw CacheFailure(
        message: 'Failed to delete wallet from secure storage',
        code: 'SECURE_STORAGE_DELETE_ERROR',
      );
    }
  }

  @override
  Future<bool> hasWallet() async {
    try {
      WalletLogger.debug('Checking wallet existence in secure storage');
      final walletString = await secureStorage.read(
        key: _walletKey,
        iOptions: _storageConfig,
        mOptions: const MacOsOptions(
          accessibility: KeychainAccessibility.first_unlock,
        ),
      );
      final exists = walletString != null;
      WalletLogger.debug('Wallet exists: $exists');
      return exists;
    } catch (e, stackTrace) {
      WalletLogger.error(
        'Failed to check wallet existence',
        e,
        stackTrace,
      );
      throw CacheFailure(
        message: 'Failed to check wallet existence',
        code: 'SECURE_STORAGE_READ_ERROR',
      );
    }
  }
}
