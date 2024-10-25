import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_btcz_wallet/presentation/bloc/wallet/wallet_bloc.dart';
import 'package:my_btcz_wallet/presentation/bloc/wallet/wallet_event.dart';
import 'package:my_btcz_wallet/presentation/bloc/wallet/wallet_state.dart';
import 'package:my_btcz_wallet/presentation/pages/home_page.dart';

class VerifyMnemonicPage extends StatefulWidget {
  final String originalMnemonic;

  const VerifyMnemonicPage({
    super.key,
    required this.originalMnemonic,
  });

  @override
  State<VerifyMnemonicPage> createState() => _VerifyMnemonicPageState();
}

class _VerifyMnemonicPageState extends State<VerifyMnemonicPage> {
  final List<TextEditingController> _controllers = List.generate(
    12,
    (index) => TextEditingController(),
  );

  bool _isValid = false;
  bool _isCreating = false;

  void _validateWords() {
    final enteredMnemonic = _controllers.map((c) => c.text.trim()).join(' ');
    setState(() {
      _isValid = enteredMnemonic == widget.originalMnemonic;
    });
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Recovery Phrase'),
      ),
      body: BlocConsumer<WalletBloc, WalletState>(
        listener: (context, state) {
          if (state is MnemonicVerified) {
            // After mnemonic is verified, create the wallet
            context.read<WalletBloc>().add(const CreateWalletEvent(notes: ''));
          } else if (state is WalletCreated || state is WalletLoaded) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomePage()),
            );
          } else if (state is WalletError) {
            setState(() => _isCreating = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        builder: (context, state) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.verified_user,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'Verify Your Recovery Phrase',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onBackground,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Please enter your 12 words in the correct order to verify you have saved them.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.primary,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 4,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: 12,
                  itemBuilder: (context, index) => Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _controllers[index],
                            onChanged: (_) => _validateWords(),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Word ${index + 1}',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            style: TextStyle(
                              fontSize: 16,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (_isCreating)
                  const Center(child: CircularProgressIndicator())
                else
                  ElevatedButton(
                    onPressed: _isValid
                        ? () {
                            setState(() => _isCreating = true);
                            context.read<WalletBloc>().add(VerifyMnemonicEvent(
                                  mnemonic: widget.originalMnemonic,
                                  notes: '',
                                ));
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Create Wallet',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
