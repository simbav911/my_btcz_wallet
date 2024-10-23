import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_btcz_wallet/core/constants/app_constants.dart';
import 'package:my_btcz_wallet/presentation/bloc/wallet/wallet_bloc.dart';
import 'package:my_btcz_wallet/presentation/bloc/wallet/wallet_event.dart';
import 'package:my_btcz_wallet/presentation/bloc/wallet/wallet_state.dart';
import 'package:my_btcz_wallet/presentation/pages/home_page.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<WalletBloc, WalletState>(
        listener: (context, state) {
          if (state is WalletCreated || state is WalletRestored) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => const HomePage(),
              ),
            );
          } else if (state is WalletError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  AppConstants.appName,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  'Welcome to your secure BitcoinZ wallet',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      context.read<WalletBloc>().add(CreateWalletEvent());
                    },
                    child: const Text('Create New Wallet'),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      _showRestoreDialog(context);
                    },
                    child: const Text('Restore Wallet'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRestoreDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Wallet'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Enter your 24-word recovery phrase',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                context.read<WalletBloc>().add(
                      RestoreWalletEvent(mnemonic: controller.text.trim()),
                    );
                Navigator.pop(context);
              }
            },
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }
}
