class Wallet {
  final String address;
  final double balance;
  final List<String> transactions;
  final bool isInitialized;
  final String privateKey;
  final String publicKey;
  final String mnemonic;
  final String? notes;

  const Wallet({
    required this.address,
    required this.balance,
    required this.transactions,
    required this.isInitialized,
    required this.privateKey,
    required this.publicKey,
    required this.mnemonic,
    this.notes,
  });
}
