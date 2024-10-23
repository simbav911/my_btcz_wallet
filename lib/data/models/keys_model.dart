import 'package:equatable/equatable.dart';

class KeysModel extends Equatable {
  final String privateKey;
  final String publicKey;
  final String address;
  final String mnemonic;

  const KeysModel({
    required this.privateKey,
    required this.publicKey,
    required this.address,
    required this.mnemonic,
  });

  factory KeysModel.fromJson(Map<String, dynamic> json) {
    return KeysModel(
      privateKey: json['privateKey'] as String,
      publicKey: json['publicKey'] as String,
      address: json['address'] as String,
      mnemonic: json['mnemonic'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'privateKey': privateKey,
      'publicKey': publicKey,
      'address': address,
      'mnemonic': mnemonic,
    };
  }

  @override
  List<Object?> get props => [privateKey, publicKey, address, mnemonic];
}
