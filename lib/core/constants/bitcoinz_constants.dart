class BitcoinZConstants {
  static const String NAME = "BitcoinZ";
  static const String SHORTNAME = "BTCZ";
  static const String NET = "mainnet";

  // Network Magic Numbers
  static const int MAINNET_MAGIC = 0x24e92764;
  static const int TESTNET_MAGIC = 0x1a1af9bf;
  static const int REGTEST_MAGIC = 0xaae83f5f;

  // Network Ports
  static const int MAINNET_PORT = 1989;
  static const int TESTNET_PORT = 11989;

  // Base58 Address Prefixes
  static const List<int> P2PKH_VERBYTE = [0x1C, 0xB8]; // t1 addresses
  static const List<int> P2SH_VERBYTE = [0x1C, 0xBD]; // t3 addresses
  static const List<int> SECRET_KEY_PREFIX = [0x80]; // Private key prefix (5, K, or L)

  // Protocol Versions
  static const int BASE_SPROUT_VERSION = 170002;
  static const int OVERWINTER_VERSION = 770006;
  static const int SAPLING_VERSION = 770006;

  // Network Upgrade Heights
  static const int OVERWINTER_ACTIVATION = 328500;
  static const int SAPLING_ACTIVATION = 328500;

  // Consensus Parameters
  static const String POW_LIMIT = "0x0007ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff";
  
  // Genesis Block
  static const String GENESIS_HASH = 'f499ee3d498b4298ac6a64205b8addb7c43197e2a660229be65db8a4534d75c1';
  
  // Other Constants
  static const int REORG_LIMIT = 800;
  static const int TX_COUNT = 171976;
  static const int TX_COUNT_HEIGHT = 81323;
  static const int TX_PER_BLOCK = 3;

  // Equihash Parameters
  static const int EPOCH_1_END = 160010;
  static const int EPOCH_2_START = 160000;
}
