import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_btcz_wallet/presentation/bloc/wallet/wallet_bloc.dart';
import 'package:my_btcz_wallet/presentation/bloc/wallet/wallet_state.dart';
import 'package:my_btcz_wallet/presentation/pages/receive_page.dart';
import 'package:my_btcz_wallet/presentation/pages/send_page.dart';
import 'package:my_btcz_wallet/presentation/widgets/connection_status_indicator.dart';
import 'package:my_btcz_wallet/core/di/injection_container.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BitcoinZ Wallet'),
        actions: [
          ConnectionStatusIndicator(
            electrumService: sl(),
          ),
        ],
      ),
      body: BlocBuilder<WalletBloc, WalletState>(
        builder: (context, state) {
          if (state is WalletCreated || 
              state is WalletRestored || 
              state is WalletLoaded) {
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
        : state is WalletRestored
            ? state.wallet
            : (state as WalletLoaded).wallet;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  const SizedBox(height: 8),
                  Text(
                    'Address: ${wallet.address}',
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SendPage(wallet: wallet),
                      ),
                    );
                  },
                  icon: const Icon(Icons.send),
                  label: const Text('Send'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReceivePage(wallet: wallet),
                      ),
                    );
                  },
                  icon: const Icon(Icons.qr_code),
                  label: const Text('Receive'),
                ),
              ),
            ],
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
