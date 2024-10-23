import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:my_btcz_wallet/core/crypto/crypto_service.dart';
import 'package:my_btcz_wallet/data/datasources/wallet_local_data_source.dart';
import 'package:my_btcz_wallet/data/datasources/wallet_remote_data_source.dart';
import 'package:my_btcz_wallet/data/repositories/wallet_repository_impl.dart';
import 'package:my_btcz_wallet/domain/repositories/wallet_repository.dart';
import 'package:my_btcz_wallet/domain/usecases/create_wallet.dart';
import 'package:my_btcz_wallet/domain/usecases/get_balance.dart';
import 'package:my_btcz_wallet/domain/usecases/get_transactions.dart';
import 'package:my_btcz_wallet/domain/usecases/restore_wallet.dart';
import 'package:my_btcz_wallet/presentation/bloc/wallet/wallet_bloc.dart';

final sl = GetIt.instance;

Future<void> init() async {
  //! Features - Wallet
  // Bloc
  sl.registerFactory(
    () => WalletBloc(
      createWallet: sl(),
      restoreWallet: sl(),
      getBalance: sl(),
      getTransactions: sl(),
    ),
  );

  // Use cases
  sl.registerLazySingleton(() => CreateWallet(sl()));
  sl.registerLazySingleton(() => RestoreWallet(sl()));
  sl.registerLazySingleton(() => GetBalance(sl()));
  sl.registerLazySingleton(() => GetTransactions(sl()));

  // Repository
  sl.registerLazySingleton<WalletRepository>(
    () => WalletRepositoryImpl(
      localDataSource: sl(),
      remoteDataSource: sl(),
      cryptoService: sl(),
    ),
  );

  // Data sources
  sl.registerLazySingleton<WalletLocalDataSource>(
    () => WalletLocalDataSourceImpl(
      secureStorage: sl(),
    ),
  );

  sl.registerLazySingleton<WalletRemoteDataSource>(
    () => WalletRemoteDataSourceImpl(
      dio: sl(),
    ),
  );

  //! Core
  sl.registerLazySingleton(() => CryptoService());

  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => sharedPreferences);
  
  // Configure secure storage with platform-specific options
  const secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
    mOptions: MacOsOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );
  sl.registerLazySingleton(() => secureStorage);
  
  sl.registerLazySingleton(() {
    final dio = Dio();
    dio.options.connectTimeout = const Duration(seconds: 30);
    dio.options.receiveTimeout = const Duration(seconds: 30);
    dio.options.validateStatus = (status) => status != null && status < 500;
    return dio;
  });
}
