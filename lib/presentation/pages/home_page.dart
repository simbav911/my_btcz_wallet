import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_btcz_wallet/presentation/bloc/wallet/wallet_bloc.dart';
import 'package:my_btcz_wallet/presentation/bloc/wallet/wallet_state.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BitcoinZ Wallet'),
      ),
      body: BlocBuilder<WalletBloc, WalletState>(
        builder: (context, state) {
          if (state is WalletCreated) {
            return _buildWalletContent(context, state);
          } else if (state is WalletRestored) {
            return _buildWalletContent(context, state);
          } else if (state is WalletLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is WalletError) {
            return Center(child: Text(state.message));
          }
          return const Center(child: Text('Wallet not initialized'));
        },
      ),
    );
  }

  Widget _buildWalletContent(BuildContext context, WalletState state) {
    final wallet = state is WalletCreated
        ? state.wallet
        : (state as WalletRestored).wallet;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Balance',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${wallet.balance} BTCZ',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Recent Transactions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: wallet.transactions.isEmpty
                ? const Center(
                    child: Text('No transactions yet'),
                  )
                : ListView.builder(
                    itemCount: wallet.transactions.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text(wallet.transactions[index]),
                        // TODO: Add more transaction details
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
