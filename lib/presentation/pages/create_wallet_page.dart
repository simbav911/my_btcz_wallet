import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_btcz_wallet/presentation/bloc/wallet/wallet_bloc.dart';
import 'package:my_btcz_wallet/presentation/bloc/wallet/wallet_event.dart';
import 'package:my_btcz_wallet/presentation/bloc/wallet/wallet_state.dart';
import 'package:my_btcz_wallet/presentation/pages/home_page.dart';

class CreateWalletPage extends StatefulWidget {
  final String mnemonic;

  const CreateWalletPage({
    super.key,
    required this.mnemonic,
  });

  @override
  State<CreateWalletPage> createState() => _CreateWalletPageState();
}

class _CreateWalletPageState extends State<CreateWalletPage> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final List<TextEditingController> _wordControllers = [];
  bool _showMnemonic = true;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    // Create controllers for each word
    for (int i = 0; i < 24; i++) {
      _wordControllers.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    for (var controller in _wordControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Wallet'),
      ),
      body: BlocListener<WalletBloc, WalletState>(
        listener: (context, state) {
          if (state is WalletCreated) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const HomePage()),
            );
          } else if (state is WalletError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSecurityWarning(),
                const SizedBox(height: 24),
                if (_showMnemonic) ...[
                  _buildMnemonicDisplay(),
                  const SizedBox(height: 24),
                  _buildContinueButton(),
                ] else if (_isVerifying) ...[
                  _buildMnemonicVerification(),
                  const SizedBox(height: 24),
                  _buildVerifyButton(),
                ] else ...[
                  _buildNotesInput(),
                  const SizedBox(height: 24),
                  _buildCreateButton(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityWarning() {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Important Security Information',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '• Your wallet can only be restored using your recovery phrase\n'
              '• Keep your recovery phrase in a safe, offline location\n'
              '• Never share your private keys or recovery phrase with anyone\n'
              '• You are the only owner of your keys and fully responsible for them',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMnemonicDisplay() {
    final words = widget.mnemonic.split(' ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recovery Phrase',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Write down these 24 words in exact order. You will need to verify them in the next step.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            childAspectRatio: 2.5,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: 24,
          itemBuilder: (context, index) {
            return Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('${index + 1}. ${words[index]}'),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMnemonicVerification() {
    final words = widget.mnemonic.split(' ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Verify Recovery Phrase',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Enter your recovery phrase to verify you have saved it correctly.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            childAspectRatio: 2.5,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: 24,
          itemBuilder: (context, index) {
            return TextFormField(
              controller: _wordControllers[index],
              decoration: InputDecoration(
                labelText: '${index + 1}',
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              validator: (value) {
                if (value != words[index]) {
                  return 'Incorrect';
                }
                return null;
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildNotesInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Add Notes (Optional)',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Add any notes to help you identify this wallet.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _notesController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Enter notes here...',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildContinueButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            _showMnemonic = false;
            _isVerifying = true;
          });
        },
        child: const Text('I Have Written Down My Recovery Phrase'),
      ),
    );
  }

  Widget _buildVerifyButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          if (_formKey.currentState!.validate()) {
            setState(() {
              _isVerifying = false;
            });
          }
        },
        child: const Text('Verify'),
      ),
    );
  }

  Widget _buildCreateButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          context.read<WalletBloc>().add(
                CreateWalletEvent(notes: _notesController.text),
              );
        },
        child: const Text('Create Wallet'),
      ),
    );
  }
}
