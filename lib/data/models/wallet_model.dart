import 'package:my_btcz_wallet/domain/entities/wallet.dart';

class WalletModel extends Wallet {
  const WalletModel({
    required String address,
    required double balance,
    required List<String> transactions,
    required bool isInitialized,
    required this.privateKey,
    required this.publicKey,
    required this.mnemonic,
  }) : super(
          address: address,
          balance: balance,
          transactions: transactions,
          isInitialized: isInitialized,
        );

  final String privateKey;
  final String publicKey;
  final String mnemonic;

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    return WalletModel(
      address: json['address'] as String,
      balance: (json['balance'] as num).toDouble(),
      transactions: List<String>.from(json['transactions'] as List),
      isInitialized: json['isInitialized'] as bool,
      privateKey: json['privateKey'] as String,
      publicKey: json['publicKey'] as String,
      mnemonic: json['mnemonic'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'address': address,
      'balance': balance,
      'transactions': transactions,
      'isInitialized': isInitialized,
      'privateKey': privateKey,
      'publicKey': publicKey,
      'mnemonic': mnemonic,
    };
  }

  WalletModel copyWith({
    String? address,
    double? balance,
    List<String>? transactions,
    bool? isInitialized,
    String? privateKey,
    String? publicKey,
    String? mnemonic,
  }) {
    return WalletModel(
      address: address ?? this.address,
      balance: balance ?? this.balance,
      transactions: transactions ?? this.transactions,
      isInitialized: isInitialized ?? this.isInitialized,
      privateKey: privateKey ?? this.privateKey,
      publicKey: publicKey ?? this.publicKey,
      mnemonic: mnemonic ?? this.mnemonic,
    );
  }
}
