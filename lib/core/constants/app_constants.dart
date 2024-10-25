class AppConstants {
  // App
  static const String appName = 'BitcoinZ Wallet';
  
  // Network
  static const String defaultElectrumServer = 'electrum.btcz.rocks';
  static const int defaultElectrumPort = 1001;
  static const bool defaultElectrumSSL = true;
  static const List<String> electrumServers = [
    'electrum.btcz.rocks',
    'electrum2.btcz.rocks'
  ];

  // Wallet
  static const int mnemonicStrength = 128; // 12 words
  static const String coinType = 'BTCZ';
  static const String coinName = 'BitcoinZ';
  static const String coinSymbol = 'BTCZ';
  static const int decimals = 8;
  static const double defaultFee = 0.0001;

  // UI
  static const int qrSize = 300;
  static const double minSendAmount = 0.00000001;
  static const double maxSendAmount = 21000000;
}
