import 'package:flutter/material.dart';
import 'package:my_btcz_wallet/core/di/injection_container.dart' as di;
import 'package:my_btcz_wallet/data/datasources/wallet_local_data_source.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await di.init();
  
  runApp(const WalletResetApp());
}

class WalletResetApp extends StatelessWidget {
  const WalletResetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: FutureBuilder(
          future: _resetWallet(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              return const Center(
                child: Text('Wallet has been reset. You can close this window.'),
              );
            }
            return const Center(
              child: CircularProgressIndicator(),
            );
          },
        ),
      ),
    );
  }

  Future<void> _resetWallet() async {
    final localDataSource = di.sl<WalletLocalDataSource>();
    await localDataSource.resetWallet();
  }
}
