import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_btcz_wallet/core/theme/app_theme.dart';
import 'package:my_btcz_wallet/presentation/bloc/wallet/wallet_bloc.dart';
import 'package:my_btcz_wallet/presentation/bloc/wallet/wallet_event.dart';
import 'package:my_btcz_wallet/presentation/bloc/wallet/wallet_state.dart';
import 'package:my_btcz_wallet/presentation/pages/home_page.dart';

class RestoreWalletPage extends StatefulWidget {
  const RestoreWalletPage({super.key});

  @override
  State<RestoreWalletPage> createState() => _RestoreWalletPageState();
}

class _RestoreWalletPageState extends State<RestoreWalletPage> {
  final _formKey = GlobalKey<FormState>();
  final _mnemonicController = TextEditingController();
  final _privateKeyController = TextEditingController();
  bool _isValidating = false;
  bool _isUsingPrivateKey = false;

  @override
  void dispose() {
    _mnemonicController.dispose();
    _privateKeyController.dispose();
    super.dispose();
  }

  void _restoreWallet() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isValidating = true;
      });
      
      context.read<WalletBloc>().add(
            RestoreWalletEvent(
              mnemonic: _isUsingPrivateKey ? null : _mnemonicController.text.trim(),
              privateKey: _isUsingPrivateKey ? _privateKeyController.text.trim() : null,
              notes: '',
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restore Wallet'),
      ),
      body: BlocConsumer<WalletBloc, WalletState>(
        listener: (context, state) {
          if (state is WalletRestored || state is WalletLoaded) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomePage()),
            );
          } else if (state is WalletError) {
            setState(() {
              _isValidating = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.restore,
                  size: 64,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Restore Your Wallet',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Use Recovery Phrase'),
                    Switch(
                      value: _isUsingPrivateKey,
                      onChanged: (value) {
                        setState(() {
                          _isUsingPrivateKey = value;
                        });
                      },
                    ),
                    const Text('Use Private Key'),
                  ],
                ),
                const SizedBox(height: 32),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!_isUsingPrivateKey)
                        TextFormField(
                          controller: _mnemonicController,
                          decoration: InputDecoration(
                            labelText: 'Recovery Phrase',
                            hintText: 'Enter your 12 words separated by spaces',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppTheme.primaryColor,
                                width: 2,
                              ),
                            ),
                            prefixIcon: const Icon(
                              Icons.vpn_key_outlined,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          maxLines: 3,
                          textInputAction: TextInputAction.done,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your recovery phrase';
                            }
                            final words = value.trim().split(' ');
                            if (words.length != 12) {
                              return 'Please enter exactly 12 words';
                            }
                            return null;
                          },
                        ),
                      if (_isUsingPrivateKey)
                        TextFormField(
                          controller: _privateKeyController,
                          decoration: InputDecoration(
                            labelText: 'Private Key',
                            hintText: 'Enter your private key',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppTheme.primaryColor,
                                width: 2,
                              ),
                            ),
                            prefixIcon: const Icon(
                              Icons.vpn_key_outlined,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          textInputAction: TextInputAction.done,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your private key';
                            }
                            return null;
                          },
                        ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _isValidating ? null : _restoreWallet,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isValidating
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text(
                                'Restore Wallet',
                                style: TextStyle(fontSize: 18),
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Make sure you are entering the correct recovery phrase or private key. Anyone with access to this information can access your funds.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.red,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
