import 'package:equatable/equatable.dart';

class Wallet extends Equatable {
  final String address;
  final double balance;
  final List<String> transactions;
  final bool isInitialized;

  const Wallet({
    required this.address,
    required this.balance,
    required this.transactions,
    required this.isInitialized,
  });

  @override
  List<Object?> get props => [address, balance, transactions, isInitialized];
}
