class AppConstants {
  // App
  static const String appName = 'BitcoinZ Wallet';
  static const String appVersion = '1.0.0';

  // Network
  static const List<String> electrumServers = [
    'electrum1.btcz.rocks:50002',
    'electrum2.btcz.rocks:50002',
    'electrum3.btcz.rocks:50002',
    'electrum4.btcz.rocks:50002',
    'electrum5.btcz.rocks:50002',
  ];

  // Storage Keys
  static const String walletKey = 'wallet_data';
  static const String settingsKey = 'app_settings';
  static const String networkKey = 'network_preferences';

  // Timeouts
  static const int connectionTimeout = 30000; // 30 seconds
  static const int receiveTimeout = 30000; // 30 seconds

  // Wallet
  static const int mnemonicStrength = 256; // 24 words
  static const String coinType = 'BTCZ';
  static const int defaultConfirmations = 6;
}
