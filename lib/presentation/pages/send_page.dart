import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_btcz_wallet/core/crypto/transaction_service.dart';
import 'package:my_btcz_wallet/domain/entities/wallet.dart';
import 'package:my_btcz_wallet/core/di/injection_container.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

class SendPage extends StatefulWidget {
  final Wallet wallet;

  const SendPage({
    super.key,
    required this.wallet,
  });

  @override
  State<SendPage> createState() => _SendPageState();
}

class _SendPageState extends State<SendPage> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _amountController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  double _fee = 0.0001; // Default fee
  final _qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? _qrController;
  bool _isScanning = false;
  late final TransactionService _transactionService;

  @override
  void initState() {
    super.initState();
    _transactionService = sl<TransactionService>();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _amountController.dispose();
    _qrController?.dispose();
    super.dispose();
  }

  Future<void> _scanQR() async {
    setState(() => _isScanning = true);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Expanded(
              child: QRView(
                key: _qrKey,
                onQRViewCreated: _onQRViewCreated,
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Scan a BitcoinZ address QR code',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
          ],
        ),
      ),
    ).whenComplete(() => setState(() => _isScanning = false));
  }

  void _onQRViewCreated(QRViewController controller) {
    _qrController = controller;
    controller.scannedDataStream.listen((scanData) async {
      if (!_isScanning) return;
      
      try {
        final data = await _transactionService.decodeQRCode(scanData.code!);
        final address = data['address'];
        if (address == null) {
          throw const FormatException('Invalid QR code: missing address');
        }
        
        setState(() {
          _addressController.text = address;
          if (data['amount'] != null) {
            _amountController.text = data['amount'].toString();
          }
        });
        
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid QR code')),
        );
      }
    });
  }

  Future<bool> _showConfirmationDialog(Map<String, dynamic> transactionDetails) async {
    final amount = double.parse(_amountController.text);
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Transaction'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Send: $amount BTCZ'),
                const SizedBox(height: 8),
                Text('To: ${_addressController.text}'),
                const SizedBox(height: 8),
                Text('Fee: $_fee BTCZ'),
                const SizedBox(height: 16),
                const Text(
                  'Please verify all details carefully.\n'
                  'Transactions cannot be reversed.',
                  style: TextStyle(color: Colors.red),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text('Confirm'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final amount = double.parse(_amountController.text);
      
      // First create transaction preview
      final transactionDetails = await _transactionService.createTransaction(
        fromAddress: widget.wallet.address,
        toAddress: _addressController.text,
        amount: amount,
        privateKey: widget.wallet.privateKey,
        fee: _fee,
      );

      if (!mounted) return;

      // Show confirmation dialog
      final confirmed = await _showConfirmationDialog(transactionDetails);
      
      if (!mounted) return;

      if (confirmed) {
        // Broadcast transaction only after confirmation
        final txId = await _transactionService.broadcastTransaction(transactionDetails);
        if (!mounted) return;
        Navigator.pop(context, txId);
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send BTCZ'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _addressController,
                              decoration: const InputDecoration(
                                labelText: 'Recipient Address',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter an address';
                                }
                                if (!value.startsWith('t1')) {
                                  return 'Invalid BitcoinZ address';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.qr_code_scanner),
                            onPressed: _isScanning ? null : _scanQR,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Amount (BTCZ)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter an amount';
                          }
                          final amount = double.tryParse(value);
                          if (amount == null || amount <= 0) {
                            return 'Please enter a valid amount';
                          }
                          if (amount > widget.wallet.balance) {
                            return 'Insufficient balance';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Transaction Fee',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text('$_fee BTCZ'),
                      const SizedBox(height: 16),
                      if (_error != null)
                        Container(
                          padding: const EdgeInsets.all(8),
                          color: Theme.of(context).colorScheme.errorContainer,
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _send,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Send'),
              ),
              const SizedBox(height: 16),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Important',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '• Double-check the recipient address\n'
                        '• Make sure you have enough balance\n'
                        '• Transactions cannot be reversed',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
